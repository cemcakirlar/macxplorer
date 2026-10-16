import AppKit
import XCTest
@testable import Macxplorer

final class FileBrowseSelectionTests: XCTestCase {
    private let a = URL(fileURLWithPath: "/tmp/a")
    private let b = URL(fileURLWithPath: "/tmp/b")
    private let c = URL(fileURLWithPath: "/tmp/c")

    func testPlainClickReplacesSelection() {
        var selection: Set<URL> = [a, b]
        FileBrowseSelection.select(c, flags: [], orderedURLs: [a, b, c], selection: &selection)
        XCTAssertEqual(selection, [c])
    }

    func testCommandClickToggles() {
        var selection: Set<URL> = [a]
        FileBrowseSelection.select(b, flags: .command, orderedURLs: [a, b, c], selection: &selection)
        XCTAssertEqual(selection, [a, b])
        FileBrowseSelection.select(a, flags: .command, orderedURLs: [a, b, c], selection: &selection)
        XCTAssertEqual(selection, [b])
    }

    func testShiftClickSelectsRange() {
        var selection: Set<URL> = [a]
        FileBrowseSelection.select(c, flags: .shift, orderedURLs: [a, b, c], selection: &selection)
        XCTAssertEqual(selection, [a, b, c])
    }

    func testDragURLsUsesSelectionWhenPrimarySelected() {
        let selection: Set<URL> = [a, c]
        XCTAssertEqual(FileBrowseSelection.dragURLs(for: a, selection: selection), [a, c])
        XCTAssertEqual(FileBrowseSelection.dragURLs(for: b, selection: selection), [b])
    }
}
