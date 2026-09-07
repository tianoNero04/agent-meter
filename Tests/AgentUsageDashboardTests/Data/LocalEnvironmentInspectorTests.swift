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

    func testInspectAllToolsReturnsOrderedItems() async {
        let tools = await inspector.inspectAllTools()

        // 验证返回的工具数量与预设顺序
        let expectedIds = ["codex", "kimi", "antigravity", "claude", "cursor", "vscode", "ollama"]
        XCTAssertEqual(tools.map(\.id), expectedIds)

        for tool in tools {
            XCTAssertFalse(tool.name.isEmpty)
            XCTAssertFalse(tool.vendor.isEmpty)
            XCTAssertFalse(tool.iconName.isEmpty)
            XCTAssertFalse(tool.statusDescription.isEmpty)

            if tool.isInstalled {
                XCTAssertNotNil(tool.locationPath)
            }
        }
    }
}
