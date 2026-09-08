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

        // 验证返回的工具数量与预设顺序
        let expectedIds = ["codex", "kimi", "antigravity", "claude", "cursor", "vscode", "ollama"]
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
