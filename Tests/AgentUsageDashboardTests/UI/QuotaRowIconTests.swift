import XCTest
@testable import AgentUsageDashboardKit

final class QuotaRowIconTests: XCTestCase {
    func testFiveHourWindowUsesClockSpec() {
        let spec = QuotaRowIconSpec(windowMinutes: 300)

        XCTAssertEqual(spec.kind, .clock)
        XCTAssertEqual(spec.backgroundScale, 0.5, accuracy: 0.001)
        XCTAssertEqual(spec.ringSize, 35, accuracy: 0.001)
        XCTAssertEqual(spec.ringBorderWidth, 0.5, accuracy: 0.001)
        XCTAssertEqual(spec.clockSize, 16, accuracy: 0.001)
        XCTAssertEqual(spec.clockStrokeWidth, 1.5, accuracy: 0.001)
        XCTAssertEqual(spec.glyphVerticalOffset, 1, accuracy: 0.001)
    }

    func testWeeklyWindowUsesCalendarSpec() {
        let spec = QuotaRowIconSpec(windowMinutes: 10080)

        XCTAssertEqual(spec.kind, .calendar)
        XCTAssertEqual(spec.ringSize, 35, accuracy: 0.001)
        XCTAssertEqual(spec.calendarSize, 29, accuracy: 0.001)
        XCTAssertEqual(spec.calendarPointSize, 16, accuracy: 0.001)
        XCTAssertEqual(spec.calendarOpacity, 0.88, accuracy: 0.001)
        XCTAssertEqual(spec.glyphVerticalOffset, 1, accuracy: 0.001)
    }

    func testOtherWindowDoesNotPretendToBeFiveHoursOrWeekly() {
        let spec = QuotaRowIconSpec(windowMinutes: 60)

        XCTAssertEqual(spec.kind, .generic)
    }
}
