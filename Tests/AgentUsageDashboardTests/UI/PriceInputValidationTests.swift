import XCTest
@testable import AgentUsageDashboardKit

final class PriceInputValidationTests: XCTestCase {
    func testAcceptsFiniteNonNegativePrice() {
        XCTAssertEqual(PriceInputValidation.parse("0.25"), 0.25)
        XCTAssertEqual(PriceInputValidation.parse("0"), 0)
    }

    func testRejectsNegativeNonNumericAndNonFinitePrice() {
        XCTAssertNil(PriceInputValidation.parse("-0.01"))
        XCTAssertNil(PriceInputValidation.parse("abc"))
        XCTAssertNil(PriceInputValidation.parse("nan"))
        XCTAssertNil(PriceInputValidation.parse("inf"))
    }
}
