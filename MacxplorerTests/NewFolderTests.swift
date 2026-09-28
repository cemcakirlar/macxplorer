import XCTest
@testable import Macxplorer

final class NewFolderTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testCreatesUntitledFolder() throws {
        let created = try NewFolder.create(in: root)
        XCTAssertEqual(created.lastPathComponent, "untitled folder")
        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: created.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
    }

    func testExistingFileKeepsItsBytesAndTheNextNameIsUsed() throws {
        let occupied = root.appendingPathComponent("untitled folder")
        try Data("keep".utf8).write(to: occupied)

        let created = try NewFolder.create(in: root)

        XCTAssertEqual(created.lastPathComponent, "untitled folder 2")
        XCTAssertEqual(try Data(contentsOf: occupied), Data("keep".utf8))
        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: created.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
    }
}
