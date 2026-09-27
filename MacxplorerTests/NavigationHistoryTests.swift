import XCTest
@testable import Macxplorer

final class NavigationHistoryTests: XCTestCase {
    private let home = URL(fileURLWithPath: "/Users/ada", isDirectory: true)
    private let documents = URL(fileURLWithPath: "/Users/ada/Documents", isDirectory: true)
    private let photos = URL(fileURLWithPath: "/Users/ada/Documents/Photos", isDirectory: true)

    func testRecordPushesBackAndClearsForward() {
        var history = NavigationHistory()
        history.recordVisit(from: home, to: documents)
        history.recordVisit(from: documents, to: photos)
        let backTarget = history.goBack(from: photos)
        history.recordVisit(from: backTarget, to: home)
        XCTAssertFalse(history.canGoForward)
        XCTAssertEqual(history.goBack(from: home)?.path, "/Users/ada/Documents")
    }

    func testBackAndForwardRoundTrip() {
        var history = NavigationHistory()
        history.recordVisit(from: home, to: documents)
        history.recordVisit(from: documents, to: photos)

        XCTAssertEqual(history.goBack(from: photos)?.path, "/Users/ada/Documents")
        XCTAssertEqual(history.goBack(from: documents)?.path, "/Users/ada")
        XCTAssertFalse(history.canGoBack)
        XCTAssertEqual(history.goForward(from: home)?.path, "/Users/ada/Documents")
        XCTAssertTrue(history.canGoForward)
    }

    func testSameFolderDoesNotRecord() {
        var history = NavigationHistory()
        history.recordVisit(from: documents, to: URL(fileURLWithPath: "/Users/ada/Documents/", isDirectory: true))
        XCTAssertFalse(history.canGoBack)
    }

    func testParentStopsAtRoot() {
        XCTAssertEqual(FolderNavigation.parent(of: documents)?.path, "/Users/ada")
        XCTAssertNil(FolderNavigation.parent(of: URL(fileURLWithPath: "/", isDirectory: true)))
    }
}
