import XCTest
@testable import Macxplorer

final class FileSystemSortTests: XCTestCase {
    func testFoldersSortBeforeFilesThenByName() {
        let entries = [
            sample(name: "mmm.txt", isDirectory: false, isPackage: false),
            sample(name: "zzz", isDirectory: true, isPackage: false),
            sample(name: "AAA.app", isDirectory: true, isPackage: true),
            sample(name: "alpha", isDirectory: true, isPackage: false),
        ]

        let sorted = FileSystemService.sortedForDisplay(entries)

        XCTAssertEqual(sorted.map(\.name), ["alpha", "zzz", "AAA.app", "mmm.txt"])
    }

    func testNameDescendingKeepsFoldersFirst() {
        let sorted = FileListOrder.sorted(
            [
                sample(name: "alpha", isDirectory: true, isPackage: false),
                sample(name: "zzz", isDirectory: true, isPackage: false),
                sample(name: "mmm.txt", isDirectory: false, isPackage: false),
                sample(name: "aaa.txt", isDirectory: false, isPackage: false),
            ],
            by: FileSort(column: .name, ascending: false)
        )
        XCTAssertEqual(sorted.map(\.name), ["zzz", "alpha", "mmm.txt", "aaa.txt"])
    }

    func testSizePutsMissingLastInBothDirections() {
        let entries = [
            sample(name: "folder", isDirectory: true, isPackage: false, size: nil),
            sample(name: "big", isDirectory: false, isPackage: false, size: 50),
            sample(name: "small", isDirectory: false, isPackage: false, size: 2),
        ]
        let ascending = FileListOrder.sorted(entries, by: FileSort(column: .size, ascending: true))
        let descending = FileListOrder.sorted(entries, by: FileSort(column: .size, ascending: false))
        XCTAssertEqual(ascending.map(\.name), ["small", "big", "folder"])
        XCTAssertEqual(descending.map(\.name), ["big", "small", "folder"])
    }

    func testDateSortsChronologically() {
        let older = Date(timeIntervalSince1970: 10)
        let newer = Date(timeIntervalSince1970: 20)
        let entries = [
            sample(name: "new", isDirectory: false, isPackage: false, modified: newer),
            sample(name: "old", isDirectory: false, isPackage: false, modified: older),
            sample(name: "none", isDirectory: false, isPackage: false, modified: nil),
        ]
        let sorted = FileListOrder.sorted(entries, by: FileSort(column: .modified, ascending: true))
        XCTAssertEqual(sorted.map(\.name), ["old", "new", "none"])
    }

    private func sample(
        name: String,
        isDirectory: Bool,
        isPackage: Bool,
        modified: Date? = nil,
        size: Int64? = nil
    ) -> FileEntry {
        FileEntry(
            url: URL(fileURLWithPath: "/tmp/\(name)", isDirectory: isDirectory),
            name: name,
            isDirectory: isDirectory,
            isPackage: isPackage,
            modified: modified,
            size: size,
            kind: isDirectory && !isPackage ? "Folder" : "Document"
        )
    }
}
