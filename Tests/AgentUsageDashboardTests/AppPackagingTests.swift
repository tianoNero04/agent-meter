import Foundation
import XCTest

final class AppPackagingTests: XCTestCase {
    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // AgentUsageDashboardTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // repository root
    }

    func testIconSourceExistsAtExpectedPath() {
        let iconSource = repositoryRoot.appendingPathComponent("assets/image.png")
        XCTAssertTrue(FileManager.default.fileExists(atPath: iconSource.path))
    }

    func testInfoPlistDeclaresAppIconResource() throws {
        let plistURL = repositoryRoot.appendingPathComponent("Resources/Info.plist")
        let data = try Data(contentsOf: plistURL)
        let propertyList = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
        )

        XCTAssertEqual(propertyList["CFBundleIconFile"] as? String, "AppIcon.icns")
    }

    func testPackagingScriptGeneratesAndInstallsAppIcon() throws {
        let scriptURL = repositoryRoot.appendingPathComponent("Scripts/package-app.sh")
        let script = try String(contentsOf: scriptURL, encoding: .utf8)

        XCTAssertTrue(script.contains("iconutil -c icns"))
        XCTAssertTrue(script.contains("AppIcon.icns"))
        XCTAssertTrue(script.contains("Contents/Resources/AppIcon.icns"))
    }
}
