import XCTest
@testable import AgentUsageDashboardKit

final class JSONSnapshotRepositoryTests: XCTestCase {
    private func makeRepository() throws -> (JSONSnapshotRepository, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("snapshot-repository-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (JSONSnapshotRepository(fileURL: directory.appendingPathComponent("snapshots.json")), directory)
    }

    /// ISO8601 落盘精度到秒，测试统一使用整秒时间保证可比较。
    private func makeSnapshot(at collectedAt: Date) -> DashboardSnapshot {
        DashboardSnapshot(collectedAt: collectedAt, providers: [
            ProviderSnapshot(
                provider: .codex,
                status: .connected,
                account: nil,
                windows: [],
                accountUsage: nil,
                localTokenUsage: .zero,
                localModels: [],
                source: "session-jsonl",
                collectedAt: collectedAt,
                errorMessage: nil
            )
        ])
    }

    func testSaveTrimsHistoryToRecentThirtyDaysAndRoundTrips() throws {
        let (repository, directory) = try makeRepository()
        defer { try? FileManager.default.removeItem(at: directory) }

        let now = Date(timeIntervalSince1970: Date().timeIntervalSince1970.rounded(.down))
        let recent = makeSnapshot(at: now.addingTimeInterval(-3600))
        let stale = makeSnapshot(at: now.addingTimeInterval(-40 * 24 * 60 * 60))
        let current = makeSnapshot(at: now)

        repository.save(current: current, history: [stale, recent, current])

        let loaded = repository.load()
        XCTAssertEqual(loaded?.current, current)
        XCTAssertEqual(loaded?.history, [recent, current])
    }

    func testSaveWritesSnapshotFileAtomically() throws {
        let (repository, directory) = try makeRepository()
        defer { try? FileManager.default.removeItem(at: directory) }

        let current = makeSnapshot(at: Date(timeIntervalSince1970: Date().timeIntervalSince1970.rounded(.down)))
        repository.save(current: current, history: [current])

        let fileURL = directory.appendingPathComponent("snapshots.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        XCTAssertEqual(repository.load()?.current, current)
    }

    func testLoadReturnsNilWhenSnapshotFileIsMissing() throws {
        let (repository, directory) = try makeRepository()
        defer { try? FileManager.default.removeItem(at: directory) }

        XCTAssertNil(repository.load())
    }
}
