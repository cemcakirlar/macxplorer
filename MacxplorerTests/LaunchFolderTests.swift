import XCTest
@testable import Macxplorer

final class LaunchFolderTests: XCTestCase {
    private let home = URL(fileURLWithPath: "/Users/ada", isDirectory: true)

    func testOffIgnoresSavedFolder() {
        let url = LaunchFolder.url(
            reopenLastFolder: false,
            lastPath: "/Users/ada/Documents",
            home: home,
            directoryExists: { _ in true }
        )
        XCTAssertEqual(url.path, "/Users/ada")
    }

    func testOnUsesSavedFolderWhenItExists() {
        let url = LaunchFolder.url(
            reopenLastFolder: true,
            lastPath: "/Users/ada/Documents/",
            home: home,
            directoryExists: { $0 == "/Users/ada/Documents/" }
        )
        XCTAssertEqual(url.path, "/Users/ada/Documents")
    }

    func testOnFallsBackToHomeWhenMissing() {
        let url = LaunchFolder.url(
            reopenLastFolder: true,
            lastPath: "/Users/ada/Missing",
            home: home,
            directoryExists: { _ in false }
        )
        XCTAssertEqual(url.path, "/Users/ada")
    }

    func testOnFallsBackToHomeWhenUnset() {
        let url = LaunchFolder.url(
            reopenLastFolder: true,
            lastPath: nil,
            home: home,
            directoryExists: { _ in true }
        )
        XCTAssertEqual(url.path, "/Users/ada")
    }
}
