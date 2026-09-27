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

    private func sample(name: String, isDirectory: Bool, isPackage: Bool) -> FileEntry {
        FileEntry(
            url: URL(fileURLWithPath: "/tmp/\(name)", isDirectory: isDirectory),
            name: name,
            isDirectory: isDirectory,
            isPackage: isPackage,
            modified: nil,
            size: nil,
            kind: isDirectory && !isPackage ? "Folder" : "Document"
        )
    }
}
