import XCTest
@testable import AgentUsageDashboardKit

final class FSEventsDirectoryWatcherTests: XCTestCase {
    func testOwnWritesDoNotCauseRefreshFeedback() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let notification = expectation(description: "本进程写入不能触发采集循环")
        notification.isInverted = true
        let watcher = FSEventsDirectoryWatcher(rootURL: root) { notification.fulfill() }
        watcher.start()
        defer { watcher.stop() }
        try Data("shared-memory".utf8).write(to: root.appendingPathComponent("token_stats.db-shm"))
        wait(for: [notification], timeout: 2)
    }

    func testExternalLogWritesStillTriggerRefresh() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let notification = expectation(description: "CLI 写入仍触发刷新")
        notification.assertForOverFulfill = false
        let watcher = FSEventsDirectoryWatcher(rootURL: root) { notification.fulfill() }
        watcher.start()
        defer { watcher.stop() }
        let writer = Process()
        writer.executableURL = URL(fileURLWithPath: "/usr/bin/touch")
        writer.arguments = [root.appendingPathComponent("wire.jsonl").path]
        try writer.run()
        writer.waitUntilExit()
        XCTAssertEqual(writer.terminationStatus, 0)
        wait(for: [notification], timeout: 3)
    }
}
