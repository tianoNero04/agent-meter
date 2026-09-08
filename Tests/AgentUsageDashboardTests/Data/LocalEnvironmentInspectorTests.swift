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

    func testInspectAllToolsReturnsOrderedItems() async throws {
        let tools = await inspector.inspectAllTools()

        // 验证返回的 12 大主流工具数量与预设排序
        let expectedIds = [
            "codex", "kimi", "antigravity", "claude", "cursor", "vscode",
            "grok", "opencode", "openclaw", "hermes", "pi", "ollama"
        ]
        XCTAssertEqual(tools.map(\.id), expectedIds)

        for tool in tools {
            XCTAssertFalse(tool.name.isEmpty)
            XCTAssertFalse(tool.vendor.isEmpty)
            XCTAssertFalse(tool.iconName.isEmpty)
            XCTAssertFalse(tool.statusDescription.isEmpty)
        }

        // 验证 VS Code Copilot 专属名称与厂商映射
        let vscode = try XCTUnwrap(tools.first { $0.id == "vscode" })
        XCTAssertEqual(vscode.name, "VS Code Copilot")
        XCTAssertEqual(vscode.vendor, "GitHub / Microsoft")

        // 验证 Grok Build 属性
        let grok = try XCTUnwrap(tools.first { $0.id == "grok" })
        XCTAssertEqual(grok.name, "Grok Build")
        XCTAssertEqual(grok.vendor, "xAI")
        XCTAssertEqual(grok.iconName, "bolt.fill")

        // 验证 OpenCode 属性
        let opencode = try XCTUnwrap(tools.first { $0.id == "opencode" })
        XCTAssertEqual(opencode.name, "OpenCode")
        XCTAssertEqual(opencode.vendor, "OpenCode AI")
        XCTAssertEqual(opencode.iconName, "curlybraces")

        // 验证 OpenClaw 属性
        let openclaw = try XCTUnwrap(tools.first { $0.id == "openclaw" })
        XCTAssertEqual(openclaw.name, "OpenClaw")
        XCTAssertEqual(openclaw.vendor, "OpenClaw")
        XCTAssertEqual(openclaw.iconName, "wrench.and.screwdriver.fill")

        // 验证 Hermes 属性
        let hermes = try XCTUnwrap(tools.first { $0.id == "hermes" })
        XCTAssertEqual(hermes.name, "Hermes")
        XCTAssertEqual(hermes.vendor, "Nous Research")
        XCTAssertEqual(hermes.iconName, "paperplane.fill")

        // 验证 Pi 属性
        let pi = try XCTUnwrap(tools.first { $0.id == "pi" })
        XCTAssertEqual(pi.name, "Pi")
        XCTAssertEqual(pi.vendor, "Inflection / Pi Agent")
        XCTAssertEqual(pi.iconName, "circle.hexagongrid.fill")
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
