import Foundation

protocol SnapshotRepository {
    func load() -> PersistedDashboard?
    func save(current: DashboardSnapshot, history: [DashboardSnapshot])
}
