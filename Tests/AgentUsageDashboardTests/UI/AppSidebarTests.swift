import XCTest
@testable import AgentUsageDashboardKit

final class AppSidebarTests: XCTestCase {
    func testMasterSectionsGroupAssignment() {
        // 验证偏好设置分组
        XCTAssertEqual(MasterSection.general.group, .preferences)
        XCTAssertEqual(MasterSection.providers.group, .preferences)
        XCTAssertEqual(MasterSection.pricing.group, .preferences)
        XCTAssertEqual(MasterSection.alerts.group, .preferences)

        // 验证洞察分析分组
        XCTAssertEqual(MasterSection.overview.group, .insights)
        XCTAssertEqual(MasterSection.models.group, .insights)
        XCTAssertEqual(MasterSection.savings.group, .insights)
    }

    func testMasterSectionMetadata() {
        for section in MasterSection.allCases {
            XCTAssertFalse(section.title.isEmpty, "每个分区都必须具备中文标题")
            XCTAssertFalse(section.iconName.isEmpty, "每个分区都必须具备 SF Symbol 图标")
        }
    }
}
