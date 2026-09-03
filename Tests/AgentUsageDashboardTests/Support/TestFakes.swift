import Foundation
@testable import AgentUsageDashboardKit

final class FakeUsageProviderAdapter: UsageProviderAdapter {
    let provider: Provider
    private(set) var includeAccountValues: [Bool] = []
    private(set) var refreshCount = 0
    var delayNanoseconds: UInt64 = 0
    /// 只在 includeAccount 等于该值时施加延迟，用于区分账号/本地两条通道的耗时。
    var delayOnlyForIncludeAccount: Bool?
    var handler: (ProviderSnapshot, Bool) -> ProviderSnapshot

    init(
        provider: Provider,
        handler: @escaping (ProviderSnapshot, Bool) -> ProviderSnapshot = { previous, _ in previous }
    ) {
        self.provider = provider
        self.handler = handler
    }

    func refresh(
        previous: ProviderSnapshot,
        includeAccount: Bool
    ) async -> ProviderSnapshot {
        refreshCount += 1
        includeAccountValues.append(includeAccount)
        let shouldDelay = delayOnlyForIncludeAccount.map { $0 == includeAccount } ?? true
        if delayNanoseconds > 0, shouldDelay {
            try? await Task.sleep(nanoseconds: delayNanoseconds)
        }
        return handler(previous, includeAccount)
    }
}

final class FakeSnapshotRepository: SnapshotRepository {
    var persisted: PersistedDashboard?
    private(set) var savedSnapshots: [(current: DashboardSnapshot, history: [DashboardSnapshot])] = []

    func load() -> PersistedDashboard? { persisted }

    func save(current: DashboardSnapshot, history: [DashboardSnapshot]) {
        savedSnapshots.append((current: current, history: history))
    }
}

final class FakeDirectoryWatcher: DirectoryWatcher {
    private(set) var startCount = 0
    private(set) var stopCount = 0

    func start() { startCount += 1 }
    func stop() { stopCount += 1 }
}

final class FakeProviderSettingsStore: ProviderSettingsStore {
    var preferences: ProviderPreferences
    private(set) var saveCount = 0

    init(preferences: ProviderPreferences = ProviderPreferences()) {
        self.preferences = preferences
    }

    func load() -> ProviderPreferences { preferences }

    func save(_ preferences: ProviderPreferences) {
        self.preferences = preferences
        saveCount += 1
    }
}

/// 一个最小可用的 `codex app-server --stdio` 假实现，依次应答握手和三个账号请求。
func fakeCodexAppServerScript() -> String {
    """
#!/usr/bin/env python3
import json
import select
import sys

def read_request():
    line = sys.stdin.readline()
    if not line:
        sys.exit(1)
    return json.loads(line)

read_request()
print(json.dumps({"id": 0, "result": {}}), flush=True)

initialized = read_request()
if initialized.get("method") != "initialized":
    sys.exit(1)

account = read_request()
if account.get("id") != 1:
    sys.exit(1)
print(json.dumps({"id": 1, "result": {"account": {"planType": "plus"}}}), flush=True)

rate_limits = read_request()
if rate_limits.get("id") != 2:
    sys.exit(1)
if select.select([sys.stdin], [], [], 0)[0]:
    sys.exit(0)
print(json.dumps({"id": 2, "result": {"rateLimitsByLimitId": {"codex": {"primary": {"usedPercent": 31, "windowDurationMins": 10080}}}}}), flush=True)

usage = read_request()
if usage.get("id") != 3:
    sys.exit(1)
print(json.dumps({"id": 3, "result": {"summary": {"lifetimeTokens": 42}}}), flush=True)
"""
}
