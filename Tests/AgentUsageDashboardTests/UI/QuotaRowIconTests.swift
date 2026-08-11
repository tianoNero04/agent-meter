import XCTest
@testable import AgentUsageDashboardKit

final class QuotaRowIconTests: XCTestCase {
    func testFiveHourWindowUsesClockSpec() {
        let spec = QuotaRowIconSpec(windowMinutes: 300)

        XCTAssertEqual(spec.kind, .clock)
        XCTAssertEqual(spec.backgroundScale, 0.5, accuracy: 0.001)
        XCTAssertEqual(spec.ringSize, 35, accuracy: 0.001)
        XCTAssertEqual(spec.ringBorderWidth, 0.5, accuracy: 0.001)
        XCTAssertEqual(spec.ringBorderOpacity, 0.28, accuracy: 0.001)
        XCTAssertEqual(spec.ringShadowRadius, 8, accuracy: 0.001)
        XCTAssertEqual(spec.clockSize, 16, accuracy: 0.001)
        XCTAssertEqual(spec.clockStrokeWidth, 1.5, accuracy: 0.001)
        XCTAssertEqual(spec.glyphVerticalOffset, 1, accuracy: 0.001)
    }

    func testRingUsesNeutralBlueGrayReferencePalette() {
        let spec = QuotaRowIconSpec(windowMinutes: 300)

        XCTAssertEqual(spec.ringGradientStart, QuotaRowIconRGB(red: 42, green: 52, blue: 64))
        XCTAssertEqual(spec.ringGradientEnd, QuotaRowIconRGB(red: 15, green: 23, blue: 31))
        XCTAssertEqual(spec.ringBorderColor, QuotaRowIconRGB(red: 139, green: 153, blue: 170))
        XCTAssertEqual(spec.ringShadowColor, QuotaRowIconRGB(red: 89, green: 112, blue: 138))
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
