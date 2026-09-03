import XCTest
@testable import AgentUsageDashboardKit

final class JSONSupportTests: XCTestCase {
    func testUnixSecondsTimestampParsesAsIs() {
        let date = JSONSupport.dateFromUnixSeconds(1_782_960_576)
        XCTAssertEqual(date?.timeIntervalSince1970 ?? 0, 1_782_960_576, accuracy: 0.001)
    }

    func testMillisecondTimestampIsNormalizedToSeconds() {
        let date = JSONSupport.dateFromUnixSeconds(1_782_960_576_236)
        XCTAssertEqual(date?.timeIntervalSince1970 ?? 0, 1_782_960_576.236, accuracy: 0.001)
    }

    func testMicroAndNanosecondTimestampsAreNormalized() {
        XCTAssertEqual(JSONSupport.dateFromUnixSeconds(1_782_960_576_236_000)?.timeIntervalSince1970 ?? 0, 1_782_960_576.236, accuracy: 0.001)
        XCTAssertEqual(JSONSupport.dateFromUnixSeconds(1.782960576236e18)?.timeIntervalSince1970 ?? 0, 1_782_960_576.236, accuracy: 0.01)
    }

    func testEventDateReadsMillisecondCreatedAt() {
        let date = JSONSupport.eventDate(["created_at": 1_782_960_576_236])
        XCTAssertEqual(date?.timeIntervalSince1970 ?? 0, 1_782_960_576.236, accuracy: 0.001)
    }
}
