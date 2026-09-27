import XCTest
@testable import Macxplorer

final class PathBarFitTests: XCTestCase {
    func testShortPathStaysWhole() {
        let hidden = PathBarFit.hiddenPrefixCount(
            crumbWidths: [40, 40, 40],
            gap: 10,
            limit: 200,
            ellipsisWidth: 20
        )
        XCTAssertEqual(hidden, 0)
    }

    func testDeepPathKeepsTheTail() {
        let hidden = PathBarFit.hiddenPrefixCount(
            crumbWidths: [40, 40, 40, 40],
            gap: 10,
            limit: 100,
            ellipsisWidth: 20
        )
        XCTAssertEqual(hidden, 3)
    }

    func testSingleCrumbIsNeverHidden() {
        let hidden = PathBarFit.hiddenPrefixCount(
            crumbWidths: [400],
            gap: 10,
            limit: 50,
            ellipsisWidth: 20
        )
        XCTAssertEqual(hidden, 0)
    }
}
