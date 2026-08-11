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
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? decoder.decode(PersistedDashboard.self, from: data)
    }

    func save(current: DashboardSnapshot, history: [DashboardSnapshot]) {
        let cutoff = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        let recent = history
            .filter { $0.collectedAt >= cutoff }
            .sorted { $0.collectedAt < $1.collectedAt }
        let persisted = PersistedDashboard(current: current, history: recent)
        guard let data = try? encoder.encode(persisted) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
