import XCTest
@testable import AgentUsageDashboardKit

final class LocalEnvironmentInspectorTests: XCTestCase {
    private let inspector = LocalEnvironmentInspector()

    func testFormatVersionExtractsNormalizedVersion() {
        XCTAssertEqual(inspector.formatVersion("codex-cli 0.142.5"), "v0.142.5")
        XCTAssertEqual(inspector.formatVersion("0.41.0"), "v0.41.0")
        XCTAssertEqual(inspector.formatVersion("1.1.26\n"), "v1.1.26")
        XCTAssertEqual(inspector.formatVersion("2.1.195 (Claude Code)"), "v2.1.195")
        XCTAssertEqual(inspector.formatVersion("v3.9.16"), "v3.9.16")
    }

    func testCompactPathReplacesHomeDirectoryWithTilde() {
        let home = NSHomeDirectory()
        let fullPath = "\(home)/.local/bin/agy"
        let compacted = inspector.compactPath(fullPath)
        XCTAssertEqual(compacted, "~/.local/bin/agy")

        let systemPath = "/Applications/Cursor.app"
        XCTAssertEqual(inspector.compactPath(systemPath), systemPath)
    }

    func testSortToolsUsesStableKnownOrderWithoutScanningRealEnvironment() {
        let codex = LocalToolEnvironment(
            id: "codex", name: "Codex", vendor: "OpenAI", iconName: "terminal",
            isInstalled: false, version: nil, locationPath: nil, statusDescription: "未检测到"
        )
        let kimi = LocalToolEnvironment(
            id: "kimi", name: "Kimi", vendor: "Moonshot AI", iconName: "sparkles",
            isInstalled: false, version: nil, locationPath: nil, statusDescription: "未检测到"
        )

        let tools = LocalEnvironmentInspector.sortTools([kimi, codex])

        XCTAssertEqual(tools.map(\.id), ["codex", "kimi"])
    }

    // 验证网络诊断端点字典完整覆盖所有 12 大工具链
    func testNetworkDiagnosticsKnownEndpointsCoverage() {
        let expectedIds = [
            "codex", "kimi", "antigravity", "claude", "cursor", "vscode",
            "grok", "opencode", "openclaw", "hermes", "pi", "ollama"
        ]
        for id in expectedIds {
            let ep = NetworkDiagnosticsService.knownEndpoints[id]
            XCTAssertNotNil(ep, "端点中应包含 \(id)")
            XCTAssertFalse(ep?.name.isEmpty ?? true)
            XCTAssertTrue(ep?.url.scheme == "https" || ep?.url.scheme == "http")
        }
    }

    // 验证能够正确从模拟的插件 package.json 中解析版本号
    func testReadExtensionVersionParsesPackageJSON() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("copilot_test_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let packageJSON = """
        {
            "name": "copilot",
            "version": "1.250.0"
        }
        """
        let fileURL = tempDir.appendingPathComponent("package.json")
        try packageJSON.write(to: fileURL, atomically: true, encoding: .utf8)

        let parsedVersion = inspector.readExtensionVersion(directoryURL: tempDir)
        XCTAssertEqual(parsedVersion, "1.250.0")
    }
}
