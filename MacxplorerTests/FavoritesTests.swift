import XCTest
@testable import Macxplorer

final class FavoritesTests: XCTestCase {
    func testKeyCleansDotsAndTrailingSlash() {
        XCTAssertEqual(Favorites.key(forPath: "/Users/ada/./Documents/../Projects/"), "/Users/ada/Projects")
        XCTAssertEqual(Favorites.key(forPath: "/"), "/")
        XCTAssertEqual(Favorites.key(forPath: "/.."), "/")
    }

    func testKeyKeepsSymlinkPath() throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let target = base.appendingPathComponent("target", isDirectory: true)
        let link = base.appendingPathComponent("link")
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        defer { try? FileManager.default.removeItem(at: base) }

        XCTAssertTrue(Favorites.key(for: link).hasSuffix("/link"))
        XCTAssertTrue(Favorites.opensAsFolder(link))
    }

    func testFilesAndPackagesAreNotFavoritable() throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let file = base.appendingPathComponent("notes.txt")
        let package = base.appendingPathComponent("Tool.app", isDirectory: true)
        try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
        try Data().write(to: file)
        defer { try? FileManager.default.removeItem(at: base) }

        XCTAssertFalse(Favorites.opensAsFolder(file))
        XCTAssertFalse(Favorites.opensAsFolder(package))
        XCTAssertTrue(Favorites.opensAsFolder(base))
    }

    func testMixedSelectionAddsOnlyMissing() {
        let action = Favorites.menuAction(for: ["/a", "/b", "/c"], favorites: ["/b"])
        XCTAssertEqual(action, .add(["/a", "/c"]))
    }

    func testAllFavoritesRemovesAll() {
        let action = Favorites.menuAction(for: ["/a", "/b"], favorites: ["/b", "/x", "/a"])
        XCTAssertEqual(action, .remove(["/a", "/b"]))
    }

    func testNoCandidatesHasNoAction() {
        XCTAssertNil(Favorites.menuAction(for: [], favorites: ["/a"]))
    }

    func testAddAppendsWithoutDuplicates() {
        let result = Favorites.applying(.add(["/b", "/c"]), to: ["/a", "/b"])
        XCTAssertEqual(result, ["/a", "/b", "/c"])
    }

    func testRemoveKeepsOrder() {
        let result = Favorites.applying(.remove(["/b"]), to: ["/a", "/b", "/c"])
        XCTAssertEqual(result, ["/a", "/c"])
    }

    func testMoveDown() {
        let result = Favorites.moving(["/a", "/b", "/c", "/d"], from: [0], to: 3)
        XCTAssertEqual(result, ["/b", "/c", "/a", "/d"])
    }

    func testMoveUp() {
        let result = Favorites.moving(["/a", "/b", "/c", "/d"], from: [3], to: 1)
        XCTAssertEqual(result, ["/a", "/d", "/b", "/c"])
    }

    func testMoveToEnd() {
        let result = Favorites.moving(["/a", "/b", "/c"], from: [0], to: 3)
        XCTAssertEqual(result, ["/b", "/c", "/a"])
    }

    func testMissingPathStaysInList() {
        let missing = "/Volumes/Gone-\(UUID().uuidString)"
        XCTAssertFalse(Favorites.opensAsFolder(URL(fileURLWithPath: missing)))
        let result = Favorites.applying(.add(["/b"]), to: [missing])
        XCTAssertEqual(result, [missing, "/b"])
    }
}
