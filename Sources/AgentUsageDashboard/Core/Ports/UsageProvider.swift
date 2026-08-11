import Foundation

/// Provider 适配器的统一入口。新增 Provider 时实现该协议并随应用版本发布，
/// 不做运行时动态加载。
protocol UsageProviderAdapter {
    var provider: Provider { get }

    /// 基于上一份快照执行一次刷新。
    /// - Parameters:
    ///   - previous: 上一份快照，用于账号失败时回退窗口、账号和 Token 数据。
    ///   - includeAccount: 是否查询账号级数据；目录监听触发的本地刷新传 `false`。
    func refresh(
        previous: ProviderSnapshot,
        includeAccount: Bool
    ) async -> ProviderSnapshot
}
