import XCTest
@testable import AgentUsageDashboardKit

final class FileLineSequenceTests: XCTestCase {
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
