import XCTest
@testable import Macxplorer

final class SidebarRootLabelTests: XCTestCase {
    func testBlankFallsBack() {
        XCTAssertEqual(SidebarRootLabel.resolved("  ", fallback: SidebarRootLabel.home), "Home")
        XCTAssertEqual(SidebarRootLabel.resolved("Disk", fallback: SidebarRootLabel.root), "Disk")
    }
}
