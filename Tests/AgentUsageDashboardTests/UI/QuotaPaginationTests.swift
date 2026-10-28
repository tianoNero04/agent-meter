import XCTest
@testable import AgentUsageDashboardKit

final class QuotaPaginationTests: XCTestCase {
    func testPagesKeepEveryQuotaWindowInGroupsOfTwo() {
        let windows = (0..<5).map {
            RateLimitWindow(id: "window-\($0)", usedPercent: 10, windowMinutes: 300, resetsAt: nil)
        }

        let pages = QuotaPagination.pages(for: windows)

        XCTAssertEqual(pages.map(\.count), [2, 2, 1])
        XCTAssertEqual(pages.flatMap { $0 }.map(\.id), (0..<5).map { "window-\($0)" })
    }

    func testPagesReturnEmptyListWithoutInventingPlaceholderPage() {
        XCTAssertTrue(QuotaPagination.pages(for: [RateLimitWindow]()).isEmpty)
    }
}
