import Foundation
import XCTest

final class AppPackagingTests: XCTestCase {
    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Support
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
        XCTAssertTrue(script.contains("AgentUsageDashboard_AgentUsageDashboardKit.bundle"))
        XCTAssertTrue(script.contains("for existing_bundle in"))
    }

    func testPackagingScriptRecreatesAppFromACleanOutputDirectory() throws {
        let scriptURL = repositoryRoot.appendingPathComponent("Scripts/package-app.sh")
        let script = try String(contentsOf: scriptURL, encoding: .utf8)
        let cleanup = try XCTUnwrap(script.range(of: #"rm -rf "$app_path""#))
        let recreation = try XCTUnwrap(
            script.range(of: #"mkdir -p "$build_root" "$app_path/Contents/MacOS""#)
        )

        XCTAssertLessThan(cleanup.lowerBound, recreation.lowerBound)
    }

    func testPackagingScriptRebuildsResourceBundleWithoutStaleFiles() throws {
        let scriptURL = repositoryRoot.appendingPathComponent("Scripts/package-app.sh")
        let script = try String(contentsOf: scriptURL, encoding: .utf8)
        let cleanup = try XCTUnwrap(script.range(of: #"rm -rf "$resource_bundle_path""#))
        let releaseBuild = try XCTUnwrap(script.range(of: "\nswift build -c release\n"))

        XCTAssertLessThan(cleanup.lowerBound, releaseBuild.lowerBound)
    }

    func testPreviewViewsLiveInLibraryTargetInsteadOfExecutableTarget() throws {
        let packageURL = repositoryRoot.appendingPathComponent("Package.swift")
        let package = try String(contentsOf: packageURL, encoding: .utf8)

        XCTAssertTrue(package.contains(".target("))
        XCTAssertTrue(package.contains(".library(name: \"AgentUsageDashboardKit\", type: .dynamic"))
        XCTAssertTrue(package.contains("name: \"AgentUsageDashboardKit\""))
        XCTAssertTrue(package.contains("name: \"AgentUsageDashboardLauncher\""))
        XCTAssertTrue(package.contains("dependencies: [\"AgentUsageDashboardKit\"]"))
    }

    func testLibraryTargetDeclaresItsSourceDirectoriesForXcodePackageRefresh() throws {
        let packageURL = repositoryRoot.appendingPathComponent("Package.swift")
        let package = try String(contentsOf: packageURL, encoding: .utf8)

        XCTAssertTrue(package.contains("sources: ["))
        for directory in ["App", "Core", "Data", "Features", "UI"] {
            XCTAssertTrue(package.contains("\"\(directory)\""), "Package source list should include \(directory)")
        }
    }
}
