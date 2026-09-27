import XCTest
@testable import Macxplorer

final class ListingVisibilityTests: XCTestCase {
    func testUnreadableFolderIsOmitted() {
        XCTAssertFalse(FileSystemService.shouldList(opensAsFolder: true, isReadable: false))
    }

    func testReadableFolderAndFilesStay() {
        XCTAssertTrue(FileSystemService.shouldList(opensAsFolder: true, isReadable: true))
        XCTAssertTrue(FileSystemService.shouldList(opensAsFolder: false, isReadable: false))
        XCTAssertTrue(FileSystemService.shouldList(opensAsFolder: true, isReadable: nil))
    }
}
