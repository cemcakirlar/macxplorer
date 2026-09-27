import XCTest
@testable import Macxplorer

final class FolderProbeTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: root)
    }

    func testEmptyAndFilesOnlyHaveNoChildFolder() async {
        let emptyDir = root.appendingPathComponent("empty", isDirectory: true)
        let filesOnly = root.appendingPathComponent("files", isDirectory: true)
        try? FileManager.default.createDirectory(at: emptyDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: filesOnly, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: filesOnly.appendingPathComponent("a.txt").path, contents: Data())

        let empty = await FileSystemService.containsListableFolder(at: emptyDir, showHidden: false)
        let files = await FileSystemService.containsListableFolder(at: filesOnly, showHidden: false)
        XCTAssertEqual(empty, false)
        XCTAssertEqual(files, false)
    }

    func testStopsForASubfolderAndSkipsHidden() async {
        let child = root.appendingPathComponent("Docs", isDirectory: true)
        try? FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)
        let hidden = root.appendingPathComponent(".secret", isDirectory: true)
        try? FileManager.default.createDirectory(at: hidden, withIntermediateDirectories: true)

        let visible = await FileSystemService.containsListableFolder(at: root, showHidden: false)
        XCTAssertEqual(visible, true)

        try? FileManager.default.removeItem(at: child)
        let onlyHidden = await FileSystemService.containsListableFolder(at: root, showHidden: false)
        let withHidden = await FileSystemService.containsListableFolder(at: root, showHidden: true)
        XCTAssertEqual(onlyHidden, false)
        XCTAssertEqual(withHidden, true)
    }

    func testPackageDoesNotCountAsChildFolder() async {
        let app = root.appendingPathComponent("Foo.app", isDirectory: true)
        try? FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)
        let onlyPackage = await FileSystemService.containsListableFolder(at: root, showHidden: false)
        XCTAssertEqual(onlyPackage, false)

        let docs = root.appendingPathComponent("Docs", isDirectory: true)
        try? FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
        let withDocs = await FileSystemService.containsListableFolder(at: root, showHidden: false)
        XCTAssertEqual(withDocs, true)
    }
}
