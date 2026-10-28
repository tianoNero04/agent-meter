import Foundation

struct JSONSnapshotRepository: SnapshotRepository {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default) {
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        let directory = applicationSupport.appendingPathComponent("AgentUsageDashboard", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        self.init(fileURL: directory.appendingPathComponent("snapshots.json"))
    }

    init(fileURL: URL) {
        self.fileURL = fileURL

        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func load() -> PersistedDashboard? {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? decoder.decode(PersistedDashboard.self, from: data) else { return nil }
        return pruned(decoded)
    }

    func save(current: DashboardSnapshot, history: [DashboardSnapshot]) {
        let persisted = pruned(PersistedDashboard(current: current, history: history))
        guard let data = try? encoder.encode(persisted) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private func pruned(_ persisted: PersistedDashboard) -> PersistedDashboard {
        let now = Date()
        let lowerBound = now.addingTimeInterval(-30 * 24 * 60 * 60)
        let upperBound = now.addingTimeInterval(24 * 60 * 60)
        func prune(_ snapshot: inout DashboardSnapshot) {
            for index in snapshot.providers.indices {
                snapshot.providers[index].localDailyBuckets = snapshot.providers[index].localDailyBuckets.filter {
                    $0.startDate >= lowerBound && $0.startDate <= upperBound
                }
            }
        }

        var result = persisted
        result.history = result.history
            .filter { $0.collectedAt >= lowerBound }
            .sorted { $0.collectedAt < $1.collectedAt }
        prune(&result.current)
        for index in result.history.indices { prune(&result.history[index]) }
        return result
    }
}
