import XCTest
@testable import Macxplorer

final class ProtectedFoldersTests: XCTestCase {
    private let home = URL(fileURLWithPath: "/Users/ada", isDirectory: true)

    private func isProtected(_ path: String) -> Bool {
        ProtectedFolders.contains(URL(fileURLWithPath: path, isDirectory: true), home: home)
    }

    func testHomeAndItsAncestorsAreProtected() {
        XCTAssertTrue(isProtected("/Users/ada"))
        XCTAssertTrue(isProtected("/Users/ada/"))
        XCTAssertTrue(isProtected("/Users"))
        XCTAssertTrue(isProtected("/"))
    }

    func testStandardHomeFoldersAreProtected() {
        XCTAssertTrue(isProtected("/Users/ada/Documents"))
        XCTAssertTrue(isProtected("/Users/ada/Library"))
        XCTAssertFalse(isProtected("/Users/ada/Documents/Notes"))
        XCTAssertFalse(isProtected("/Users/ada/Projects"))
    }

    func testSystemFoldersAreProtectedButTheirContentsAreNot() {
        XCTAssertTrue(isProtected("/System"))
        XCTAssertTrue(isProtected("/Applications"))
        XCTAssertFalse(isProtected("/Applications/Notes.app"))
        XCTAssertFalse(isProtected("/Volumes/Backup"))
    }

    func testEveryFolderDirectlyUnderUsersIsProtected() {
        XCTAssertTrue(isProtected("/Users/adam"))
        XCTAssertTrue(isProtected("/Users/Shared"))
        XCTAssertFalse(isProtected("/Users/Shared/Projects"))
        XCTAssertFalse(isProtected("/Users/adam/Projects"))
    }
}
