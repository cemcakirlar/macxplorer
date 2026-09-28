import XCTest
@testable import Macxplorer

final class UntitledFolderNameTests: XCTestCase {
    func testFirstNameIsUntitledFolder() {
        XCTAssertEqual(UntitledFolderName.next(existing: [], caseSensitive: false), "untitled folder")
    }

    func testTakenNameUsesTheNextNumber() {
        XCTAssertEqual(
            UntitledFolderName.next(existing: ["untitled folder"], caseSensitive: false),
            "untitled folder 2"
        )
        XCTAssertEqual(
            UntitledFolderName.next(
                existing: ["untitled folder", "untitled folder 2"],
                caseSensitive: false
            ),
            "untitled folder 3"
        )
    }

    func testCaseInsensitiveVolumeTreatsDifferentCaseAsTaken() {
        XCTAssertEqual(
            UntitledFolderName.next(existing: ["Untitled Folder"], caseSensitive: false),
            "untitled folder 2"
        )
    }

    func testCaseSensitiveVolumeKeepsTheLowercaseNameFree() {
        XCTAssertEqual(
            UntitledFolderName.next(existing: ["Untitled Folder"], caseSensitive: true),
            "untitled folder"
        )
    }
}
