import XCTest
@testable import Macxplorer

final class FileTrashTests: XCTestCase {
    private var root: URL!
    /// Trash copies created by these tests. Removed only here, never by app code.
    private var trashCopies: [URL] = []

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        for copy in trashCopies {
            try? FileManager.default.removeItem(at: copy)
        }
        try? FileManager.default.removeItem(at: root)
    }

    func testTrashMovesBytesOutOfTheOriginalPath() throws {
        let file = root.appendingPathComponent("note.txt")
        try Data("hello".utf8).write(to: file)

        let trashed = try FileTrash.trash(at: file)
        trashCopies.append(trashed)

        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        XCTAssertEqual(try Data(contentsOf: trashed), Data("hello".utf8))
    }

    func testTrashSymlinkLeavesTheTargetInPlace() throws {
        let target = root.appendingPathComponent("target.txt")
        try Data("target".utf8).write(to: target)
        let link = root.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)

        let trashed = try FileTrash.trash(at: link)
        trashCopies.append(trashed)

        XCTAssertEqual(try Data(contentsOf: target), Data("target".utf8))
        XCTAssertFalse(FileManager.default.fileExists(atPath: link.path))
        let destination = try FileManager.default.destinationOfSymbolicLink(atPath: trashed.path)
        XCTAssertTrue(destination.hasSuffix("target.txt"))
    }

    func testPutBackRestoresTheOriginalBytes() throws {
        let file = root.appendingPathComponent("note.txt")
        try Data("hello".utf8).write(to: file)
        let trashed = try FileTrash.trash(at: file)
        trashCopies.append(trashed)

        try FileTrash.putBack(trashed: trashed, to: file)

        XCTAssertEqual(try Data(contentsOf: file), Data("hello".utf8))
        XCTAssertFalse(FileManager.default.fileExists(atPath: trashed.path))
    }

    func testPutBackLeavesBothFilesWhenTheOriginalNameIsTaken() throws {
        let file = root.appendingPathComponent("note.txt")
        try Data("old".utf8).write(to: file)
        let trashed = try FileTrash.trash(at: file)
        trashCopies.append(trashed)
        try Data("new".utf8).write(to: file)

        XCTAssertThrowsError(try FileTrash.putBack(trashed: trashed, to: file)) { error in
            XCTAssertEqual(error as? FileTrashError, .nameTaken("note.txt"))
        }
        XCTAssertEqual(try Data(contentsOf: file), Data("new".utf8))
        XCTAssertEqual(try Data(contentsOf: trashed), Data("old".utf8))
    }
}
