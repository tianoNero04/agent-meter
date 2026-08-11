import XCTest
@testable import AgentUsageDashboardKit

final class SnapshotModelTests: XCTestCase {
    private func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    func testProviderSnapshotRoundTripsThroughCodable() throws {
        let snapshot = ProviderSnapshot(
            provider: .codex,
            status: .connected,
            account: AccountIdentity(planType: "plus", email: nil),
            windows: [RateLimitWindow(id: "codex", usedPercent: 31, windowMinutes: 10080, resetsAt: nil)],
            accountUsage: AccountTokenUsage(lifetimeTokens: 42, peakDailyTokens: nil, dailyBuckets: nil),
            localTokenUsage: TokenUsage(input: 10, cachedInput: 3, output: 5, reasoning: 2),
            localDailyBuckets: [DailyTokenBucket(startDate: Date(timeIntervalSince1970: 1_894_000_000), tokens: 20)],
            localModels: [ModelUsage(model: "gpt-5.1-codex", usage: TokenUsage(input: 10, cachedInput: 3, output: 5, reasoning: 2))],
            source: "app-server + session-jsonl",
            collectedAt: Date(timeIntervalSince1970: 1_894_000_000),
            errorMessage: nil
        )

        let data = try makeEncoder().encode(snapshot)
        let decoded = try makeDecoder().decode(ProviderSnapshot.self, from: data)

        XCTAssertEqual(decoded, snapshot)
    }

    func testProviderSnapshotDecodesLegacyJSONWithoutLocalDailyBuckets() throws {
        let legacy = """
        {
            "provider": "kimiCode",
            "status": "connected",
            "windows": [],
            "localTokenUsage": {"input": 8, "cachedInput": 4, "output": 6, "reasoning": 0},
            "localModels": [],
            "source": "wire-jsonl",
            "collectedAt": "2026-01-01T00:00:00Z"
        }
        """

        let decoded = try makeDecoder().decode(ProviderSnapshot.self, from: Data(legacy.utf8))

        XCTAssertEqual(decoded.provider, .kimiCode)
        XCTAssertEqual(decoded.localDailyBuckets, [])
        XCTAssertNil(decoded.account)
        XCTAssertNil(decoded.errorMessage)
    }

    func testRateLimitLabelInterpolatesUnknownWindowDuration() {
        let window = RateLimitWindow(id: "codex", usedPercent: 10, windowMinutes: 1440, resetsAt: nil)

        XCTAssertEqual(window.label, "1440 分钟")
    }

    func testPersistedDashboardRoundTripsThroughCodable() throws {
        let collectedAt = Date(timeIntervalSince1970: 1_894_000_000)
        let providers: [ProviderSnapshot] = [.codex, .kimiCode].map { provider in
            ProviderSnapshot(
                provider: provider,
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
        }
        let snapshot = DashboardSnapshot(collectedAt: collectedAt, providers: providers)
        let persisted = PersistedDashboard(current: snapshot, history: [snapshot])

        let data = try makeEncoder().encode(persisted)
        let decoded = try makeDecoder().decode(PersistedDashboard.self, from: data)

        XCTAssertEqual(decoded.current, snapshot)
        XCTAssertEqual(decoded.history, [snapshot])
    }
}
