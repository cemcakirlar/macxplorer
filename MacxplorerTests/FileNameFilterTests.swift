import XCTest
@testable import Macxplorer

final class FileNameFilterTests: XCTestCase {
    private let docs = FileEntry(
        url: URL(fileURLWithPath: "/tmp/Documents", isDirectory: true),
        name: "Documents",
        isDirectory: true,
        isPackage: false,
        modified: nil,
        size: nil,
        kind: "Folder"
    )
    private let notes = FileEntry(
        url: URL(fileURLWithPath: "/tmp/notes.txt"),
        name: "notes.txt",
        isDirectory: false,
        isPackage: false,
        modified: nil,
        size: 1,
        kind: "Text"
    )
    private let photos = FileEntry(
        url: URL(fileURLWithPath: "/tmp/Photos", isDirectory: true),
        name: "Photos",
        isDirectory: true,
        isPackage: false,
        modified: nil,
        size: nil,
        kind: "Folder"
    )

    private var entries: [FileEntry] { [docs, notes, photos] }

    func testBlankQueryReturnsAll() {
        XCTAssertEqual(FileNameFilter.filtered(entries, query: ""), entries)
        XCTAssertEqual(FileNameFilter.filtered(entries, query: "   "), entries)
    }

    func testContainsMatchIsCaseInsensitive() {
        let result = FileNameFilter.filtered(entries, query: "doc")
        XCTAssertEqual(result.map(\.name), ["Documents"])
    }

    func testContainsFindsSubstring() {
        let result = FileNameFilter.filtered(entries, query: "ote")
        XCTAssertEqual(result.map(\.name), ["notes.txt"])
    }

    func testPrefixMatchAnchored() {
        XCTAssertEqual(FileNameFilter.firstPrefixMatch(in: entries, buffer: "Do")?.name, "Documents")
        XCTAssertNil(FileNameFilter.firstPrefixMatch(in: entries, buffer: "cument"))
        XCTAssertEqual(FileNameFilter.firstPrefixMatch(in: entries, buffer: "notes")?.name, "notes.txt")
    }

    func testPrefixMatchBlankReturnsNil() {
        XCTAssertNil(FileNameFilter.firstPrefixMatch(in: entries, buffer: ""))
        XCTAssertNil(FileNameFilter.firstPrefixMatch(in: entries, buffer: "   "))
    }
}
