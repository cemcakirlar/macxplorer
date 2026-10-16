import XCTest
@testable import Macxplorer

final class ColumnPathTests: XCTestCase {
    private let home = URL(fileURLWithPath: "/Users/ada", isDirectory: true)
    private let root = URL(fileURLWithPath: "/", isDirectory: true)
    private let volumes = URL(fileURLWithPath: "/Volumes", isDirectory: true)

    private var roots: [URL] { [home, root, volumes] }

    func testFoldersToHomeIsSingleColumn() {
        XCTAssertEqual(ColumnPath.folders(to: home, roots: roots).map(\.path), ["/Users/ada"])
    }

    func testFoldersWalksFromDeepestRoot() {
        let docs = URL(fileURLWithPath: "/Users/ada/Documents/Projects", isDirectory: true)
        XCTAssertEqual(
            ColumnPath.folders(to: docs, roots: roots).map(\.path),
            ["/Users/ada", "/Users/ada/Documents", "/Users/ada/Documents/Projects"]
        )
    }

    func testFoldersPrefersHomeOverRoot() {
        let docs = URL(fileURLWithPath: "/Users/ada/Documents", isDirectory: true)
        let paths = ColumnPath.folders(to: docs, roots: roots).map(\.path)
        XCTAssertEqual(paths.first, "/Users/ada")
        XCTAssertFalse(paths.contains("/"))
    }

    func testSelectingFolderAppendsAndTrims() {
        let chain = [
            URL(fileURLWithPath: "/Users/ada", isDirectory: true),
            URL(fileURLWithPath: "/Users/ada/Documents", isDirectory: true),
            URL(fileURLWithPath: "/Users/ada/Documents/Old", isDirectory: true),
        ]
        let next = ColumnPath.selectingFolder(
            URL(fileURLWithPath: "/Users/ada/Documents/New", isDirectory: true),
            in: chain,
            at: 1
        )
        XCTAssertEqual(next.map(\.path), ["/Users/ada", "/Users/ada/Documents", "/Users/ada/Documents/New"])
    }

    func testSelectingFileTrimsTrailingColumns() {
        let chain = [
            URL(fileURLWithPath: "/Users/ada", isDirectory: true),
            URL(fileURLWithPath: "/Users/ada/Documents", isDirectory: true),
            URL(fileURLWithPath: "/Users/ada/Documents/Projects", isDirectory: true),
        ]
        XCTAssertEqual(
            ColumnPath.selectingFile(in: chain, at: 1).map(\.path),
            ["/Users/ada", "/Users/ada/Documents"]
        )
    }
}
