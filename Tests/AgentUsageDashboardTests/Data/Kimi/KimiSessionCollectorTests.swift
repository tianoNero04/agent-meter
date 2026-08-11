import XCTest
@testable import AgentUsageDashboardKit

final class KimiSessionCollectorTests: XCTestCase {
    func testKimiCollectorMapsWireUsageFields() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("kimi-fixture-\(UUID().uuidString)", isDirectory: true)
        let sessions = root.appendingPathComponent(".kimi-code/sessions/example/agents/main", isDirectory: true)
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let file = sessions.appendingPathComponent("wire.jsonl")
        let content = """
        {"modelAlias":"k3","usage":{"inputCacheCreation":2,"inputCacheRead":4,"inputOther":8,"output":6}}
        """
        try content.write(to: file, atomically: true, encoding: .utf8)

        let result = KimiSessionCollector(homeURL: root).collect()

        XCTAssertEqual(result.tokenUsage.input, 10)
        XCTAssertEqual(result.tokenUsage.cachedInput, 4)
        XCTAssertEqual(result.tokenUsage.output, 6)
        XCTAssertEqual(result.models.first?.model, "k3")
    }

    func testKimiCollectorAggregatesTokenUsageIntoSevenDailyBuckets() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("kimi-daily-fixture-\(UUID().uuidString)", isDirectory: true)
        let sessions = root.appendingPathComponent(".kimi-code/sessions/example/agents/main", isDirectory: true)
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let file = sessions.appendingPathComponent("wire.jsonl")
        let content = """
        {"timestamp":"2026-08-04T09:00:00Z","modelAlias":"k3","usage":{"inputOther":10,"output":5}}
        {"timestamp":"2026-08-04T10:00:00Z","modelAlias":"k3","usage":{"inputOther":2,"output":3}}
        {"timestamp":"2026-08-03T09:00:00Z","modelAlias":"k3","usage":{"inputOther":7,"output":1}}
        """
        try content.write(to: file, atomically: true, encoding: .utf8)

        let result = KimiSessionCollector(homeURL: root).collect()

        XCTAssertEqual(result.dailyBuckets.count, 2)
        XCTAssertEqual(result.dailyBuckets.map(\.tokens), [8, 20])
        XCTAssertEqual(result.dailyBuckets.map { Calendar.current.component(.day, from: $0.startDate) }, [3, 4])
    }

    func testKimiCollectorOnlyReparsesChangedFiles() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("kimi-incremental-\(UUID().uuidString)", isDirectory: true)
        let sessionsA = root.appendingPathComponent(".kimi-code/sessions/a/agents/main", isDirectory: true)
        let sessionsB = root.appendingPathComponent(".kimi-code/sessions/b/agents/main", isDirectory: true)
        try FileManager.default.createDirectory(at: sessionsA, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: sessionsB, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let usageLine = #"{"modelAlias":"k3","usage":{"inputOther":10,"output":5}}"#
        let fileA = sessionsA.appendingPathComponent("wire.jsonl")
        let fileB = sessionsB.appendingPathComponent("wire.jsonl")
        try "\(usageLine)\n".write(to: fileA, atomically: true, encoding: .utf8)
        try "\(usageLine)\n".write(to: fileB, atomically: true, encoding: .utf8)

        let collector = KimiSessionCollector(homeURL: root)
        let initial = collector.collect()
        XCTAssertEqual(collector.parsedFileCount, 2)
        XCTAssertEqual(initial.tokenUsage.total, 30)

        let unchanged = collector.collect()
        XCTAssertEqual(collector.parsedFileCount, 2)
        XCTAssertEqual(unchanged.tokenUsage.total, 30)

        try "\(usageLine)\n\(usageLine)\n".write(to: fileB, atomically: true, encoding: .utf8)
        let updated = collector.collect()
        XCTAssertEqual(collector.parsedFileCount, 3)
        XCTAssertEqual(updated.tokenUsage.total, 45)
    }
}
