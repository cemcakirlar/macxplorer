import XCTest
@testable import Macxplorer

final class SelectionHoldTests: XCTestCase {
    private let folder = URL(fileURLWithPath: "/Users/ada/Projects", isDirectory: true)
    private let other = URL(fileURLWithPath: "/Users/ada/Desktop", isDirectory: true)

    func testHoldsForTheFolderItWasArmedFor() {
        var hold = SelectionHold()
        hold.arm(for: folder)

        XCTAssertTrue(hold.consume(for: URL(fileURLWithPath: "/Users/ada/Projects/")))
    }

    func testDoesNotHoldForAnotherFolder() {
        var hold = SelectionHold()
        hold.arm(for: folder)

        XCTAssertFalse(hold.consume(for: other))
    }

    func testConsumingAlwaysDisarms() {
        var hold = SelectionHold()
        hold.arm(for: folder)
        _ = hold.consume(for: other)

        XCTAssertFalse(hold.consume(for: folder))
        XCTAssertNil(hold.target)
    }

    func testUnarmedHoldNeverHolds() {
        var hold = SelectionHold()

        XCTAssertFalse(hold.consume(for: folder))
        XCTAssertFalse(hold.consume(for: nil))
    }
}
