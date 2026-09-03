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
              var decoded = try? decoder.decode(PersistedDashboard.self, from: data) else { return nil }
        // 本地分桶只服务近 7 天曲线：加载时裁掉 30 天外或未来时间的异常桶，
        // 避免异常数据随每次落盘反复参与编码、文件越滚越大。
        let lowerBound = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        let upperBound = Date().addingTimeInterval(24 * 60 * 60)
        func prune(_ snapshot: inout DashboardSnapshot) {
            for index in snapshot.providers.indices {
                snapshot.providers[index].localDailyBuckets = snapshot.providers[index].localDailyBuckets.filter {
                    $0.startDate >= lowerBound && $0.startDate <= upperBound
                }
            }
        }
        prune(&decoded.current)
        for index in decoded.history.indices { prune(&decoded.history[index]) }
        return decoded
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
