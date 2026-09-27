import XCTest
@testable import Macxplorer

final class SidebarPathPinTests: XCTestCase {
    func testMissingLinkSkipsUnloadedParents() {
        let home = URL(fileURLWithPath: "/Users/ada", isDirectory: true)
        let secret = URL(fileURLWithPath: "/Users/ada/.secret", isDirectory: true)
        let notes = URL(fileURLWithPath: "/Users/ada/.secret/notes", isDirectory: true)
        let chain = [home, secret, notes]
        let loaded = ["/Users/ada": Set(["/Users/ada/Documents"])]

        let missing = SidebarPathPin.missingLinks(chain: chain, childPathsByParent: loaded)
        XCTAssertEqual(missing.map(\.child), ["/Users/ada/.secret"])
    }

    func testStalePinsDropOffPath() {
        let home = URL(fileURLWithPath: "/Users/ada", isDirectory: true)
        let documents = URL(fileURLWithPath: "/Users/ada/Documents", isDirectory: true)
        let pinned: Set<String> = ["/Users/ada/.secret", "/Users/ada/Documents"]
        let stale = SidebarPathPin.stalePins(pinned: pinned, chain: [home, documents])
        XCTAssertEqual(stale, ["/Users/ada/.secret"])
    }
}
