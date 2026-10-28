import XCTest
import Darwin
@testable import AgentUsageDashboardKit

final class FileLineSequenceTests: XCTestCase {
    func testStreamingManyChunksDoesNotRetainAllReadBuffers() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        FileManager.default.createFile(atPath: url.path, contents: nil)
        defer { try? FileManager.default.removeItem(at: url) }
        let writer = try FileHandle(forWritingTo: url)
        var line = Data(repeating: 0x78, count: 64 * 1024 - 1)
        line.append(0x0A)
        for _ in 0..<1024 { try writer.write(contentsOf: line) }
        try writer.close()

        try autoreleasepool {
            let before = try residentBytes()
            let iterator = FileLineSequence(url: url).makeIterator()
            var lines = 0
            while iterator.nextData() != nil { lines += 1 }
            XCTAssertEqual(lines, 1024)
            XCTAssertLessThan(try residentBytes(), before + 32 * 1024 * 1024,
                              "64 MB 的流式扫描不能滞留全部 Foundation 读取缓冲")
        }
    }

    private func residentBytes() throws -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { throw NSError(domain: "MachTaskInfo", code: Int(result)) }
        return info.resident_size
    }

    func testLargeLineDoesNotRequireQuadraticScanning() throws {
        let content = String(repeating: "x", count: 8 * 1024 * 1024) + "\nend\n"
        let url = try writeTempFile(content)
        defer { try? FileManager.default.removeItem(at: url) }
        let start = Date()
        let iterator = FileLineSequence(url: url, chunkSize: 256).makeIterator()
        XCTAssertEqual(iterator.nextData()?.count, 8 * 1024 * 1024)
        XCTAssertEqual(iterator.next(), "end")
        XCTAssertNil(iterator.next())
        XCTAssertLessThan(Date().timeIntervalSince(start), 1.5,
                          "超长行应线性扫描，而不是每次读取都重新扫描整个前缀")
    }

    private func writeTempFile(_ content: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("line-sequence-\(UUID().uuidString)")
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func testReadsAllLinesAcrossChunkBoundaries() throws {
        // 构造大量行，保证跨越多个 64 字节的小 chunk，验证索引不会错位。
        let line = String(repeating: "x", count: 50)
        let content = (0..<200).map { "\($0)-\(line)" }.joined(separator: "\n") + "\n"
        let url = try writeTempFile(content)
        defer { try? FileManager.default.removeItem(at: url) }

        let lines = FileLineSequence(url: url, chunkSize: 64).makeIterator()
        for index in 0..<200 {
            XCTAssertEqual(lines.next(), "\(index)-\(line)")
        }
        XCTAssertNil(lines.next())
    }

    func testReadLimitExcludesBytesAppendedAfterSnapshot() throws {
        let url = try writeTempFile("old\nnew\n")
        defer { try? FileManager.default.removeItem(at: url) }
        let iterator = FileLineSequence(url: url, chunkSize: 2, startOffset: 4, readLimit: 4).makeIterator()
        let handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("later\n".utf8))
        try handle.close()
        XCTAssertEqual(iterator.next(), "new")
        XCTAssertNil(iterator.next())
        XCTAssertEqual(iterator.bytesRead, 4)
        XCTAssertTrue(iterator.lastLineTerminated)
    }

    func testUnterminatedTailIsIdentifiedForSafeResume() throws {
        let url = try writeTempFile("a\npartial")
        defer { try? FileManager.default.removeItem(at: url) }
        let iterator = FileLineSequence(url: url, chunkSize: 2).makeIterator()
        XCTAssertEqual(iterator.next(), "a")
        XCTAssertEqual(iterator.next(), "partial")
        XCTAssertFalse(iterator.lastLineTerminated)
        XCTAssertNil(iterator.next())
    }

    func testStripsCarriageReturnAndHandlesMissingTrailingNewline() throws {
        let url = try writeTempFile("a\r\nb\r\nc")
        defer { try? FileManager.default.removeItem(at: url) }

        let lines = FileLineSequence(url: url, chunkSize: 2).map { $0 }
        XCTAssertEqual(lines, ["a", "b", "c"])
    }

    func testUnreadableFileYieldsNoLines() {
        let url = URL(fileURLWithPath: "/nonexistent/path.jsonl")
        XCTAssertEqual(FileLineSequence(url: url).map { $0 }, [])
    }
}
