import XCTest
@testable import Macxplorer

final class DropClaimTests: XCTestCase {
    func testTheSameDragIsClaimedOnce() {
        let claim = DropClaim()

        XCTAssertTrue(claim.claim(dragCount: 7))
        XCTAssertFalse(claim.claim(dragCount: 7))
    }

    func testANewDragIsClaimedRightAway() {
        let claim = DropClaim()
        _ = claim.claim(dragCount: 7)

        XCTAssertTrue(claim.claim(dragCount: 8))
    }
}
