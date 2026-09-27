import XCTest
@testable import Macxplorer

final class CopiedPathsTests: XCTestCase {
    func testSinglePath() {
        let url = URL(fileURLWithPath: "/Users/ada/Notes.txt")
        XCTAssertEqual(CopiedPaths.text(for: [url]), "/Users/ada/Notes.txt")
    }

    func testMultiplePathsAreSortedAndJoined() {
        let later = URL(fileURLWithPath: "/Users/ada/b.txt")
        let earlier = URL(fileURLWithPath: "/Users/ada/a.txt")
        XCTAssertEqual(
            CopiedPaths.text(for: [later, earlier]),
            "/Users/ada/a.txt\n/Users/ada/b.txt"
        )
    }

    func testEmptyListIsEmptyString() {
        let urls: [URL] = []
        XCTAssertEqual(CopiedPaths.text(for: urls), "")
    }

    func testNamesFollowPathOrder() {
        let later = URL(fileURLWithPath: "/z/a.txt")
        let earlier = URL(fileURLWithPath: "/a/m.txt")
        XCTAssertEqual(CopiedPaths.names(for: [later, earlier]), "m.txt\na.txt")
    }

    func testNamesOfEmptyListAreEmpty() {
        let urls: [URL] = []
        XCTAssertEqual(CopiedPaths.names(for: urls), "")
    }

    func testAbbreviatedHomePrefix() {
        let home = URL(fileURLWithPath: "/Users/ada")
        let note = URL(fileURLWithPath: "/Users/ada/Notes.txt")
        XCTAssertEqual(CopiedPaths.abbreviatedText(for: [note], home: home), "~/Notes.txt")
    }

    func testAbbreviatedHomeItself() {
        let home = URL(fileURLWithPath: "/Users/ada")
        XCTAssertEqual(CopiedPaths.abbreviatedText(for: [home], home: home), "~")
    }

    func testAbbreviatedLeavesOtherRoots() {
        let home = URL(fileURLWithPath: "/Users/ada")
        let sibling = URL(fileURLWithPath: "/Users/ada2/Notes.txt")
        let tmp = URL(fileURLWithPath: "/tmp/Notes.txt")
        XCTAssertEqual(
            CopiedPaths.abbreviatedText(for: [sibling, tmp], home: home),
            "/Users/ada2/Notes.txt\n/tmp/Notes.txt"
        )
    }

    func testRootHomeDoesNotAbbreviate() {
        let home = URL(fileURLWithPath: "/")
        let note = URL(fileURLWithPath: "/Users/ada/Notes.txt")
        XCTAssertEqual(CopiedPaths.abbreviatedText(for: [note], home: home), "/Users/ada/Notes.txt")
    }

    func testAbbreviatedKeepsCopyPathOrder() {
        let home = URL(fileURLWithPath: "/Users/ada")
        let homeFile = URL(fileURLWithPath: "/Users/ada/b.txt")
        let other = URL(fileURLWithPath: "/tmp/a.txt")
        XCTAssertEqual(
            CopiedPaths.abbreviatedText(for: [other, homeFile], home: home),
            "~/b.txt\n/tmp/a.txt"
        )
    }
}
