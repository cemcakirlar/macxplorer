import XCTest
@testable import Macxplorer

final class TerminalDirectoryTests: XCTestCase {
    func testFileOpensParent() {
        let file = URL(fileURLWithPath: "/Users/ada/Notes.txt")
        XCTAssertEqual(
            TerminalDirectory.url(for: file, opensAsFolder: false).path,
            "/Users/ada"
        )
    }

    func testFolderOpensItself() {
        let folder = URL(fileURLWithPath: "/Users/ada/Projects")
        XCTAssertEqual(
            TerminalDirectory.url(for: folder, opensAsFolder: true).path,
            "/Users/ada/Projects"
        )
    }

    func testUniqueDirectoriesStayInPathOrder() {
        let first = URL(fileURLWithPath: "/Users/ada/a.txt")
        let second = URL(fileURLWithPath: "/Users/ada/b.txt")
        let folder = URL(fileURLWithPath: "/Users/ada/Projects")
        let urls = TerminalDirectory.urls(for: [second, first, folder]) { $0 == folder }
        XCTAssertEqual(urls.map(\.path), ["/Users/ada", "/Users/ada/Projects"])
    }
}