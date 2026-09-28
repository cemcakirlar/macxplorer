import XCTest
@testable import Macxplorer

final class TrashTargetsTests: XCTestCase {
    func testDescendantIsDroppedWhenItsAncestorIsSelected() {
        let parent = URL(fileURLWithPath: "/Users/a", isDirectory: true)
        let child = URL(fileURLWithPath: "/Users/a/b", isDirectory: true)
        let neighbor = URL(fileURLWithPath: "/Users/ab", isDirectory: true)
        let roots = TrashTargets.roots(among: [child, parent, neighbor, parent])
        XCTAssertEqual(roots.map(\.path).sorted(), ["/Users/a", "/Users/ab"])
    }

    func testTrashedTreeMovesToTheParentAndNeighborStays() {
        XCTAssertEqual(
            TrashTargets.replacing("/Users/a/Documents", trashed: ["/Users/a"]),
            "/Users"
        )
        XCTAssertEqual(
            TrashTargets.replacing("/Users/a", trashed: ["/Users/a"]),
            "/Users"
        )
        XCTAssertEqual(
            TrashTargets.replacing("/Users/ab", trashed: ["/Users/a"]),
            "/Users/ab"
        )
        XCTAssertFalse(TrashTargets.affects("/Users/ab", trashed: ["/Users/a"]))
        XCTAssertTrue(TrashTargets.affects("/Users/a/Documents/Photos", trashed: ["/Users/a"]))
    }

    func testHistoryDropPullsTheTrashedFolderUpToItsParent() {
        let home = URL(fileURLWithPath: "/Users/ada", isDirectory: true)
        let documents = URL(fileURLWithPath: "/Users/ada/Documents", isDirectory: true)
        let photos = URL(fileURLWithPath: "/Users/ada/Documents/Photos", isDirectory: true)
        var history = NavigationHistory()
        history.recordVisit(from: home, to: documents)
        history.recordVisit(from: documents, to: photos)
        history.drop(trashed: [documents])

        XCTAssertEqual(history.goBack(from: home)?.path, "/Users/ada")
        XCTAssertFalse(history.canGoBack)
    }
}
