import XCTest
@testable import Macxplorer

final class FileRenameTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testRenameMovesBytesToTheNewName() throws {
        let file = root.appendingPathComponent("note.txt")
        try Data("hello".utf8).write(to: file)

        let renamed = try FileRename.apply(at: file, to: "letter.txt")

        XCTAssertEqual(try Data(contentsOf: renamed), Data("hello".utf8))
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }

    func testCollisionLeavesBothFilesUntouched() throws {
        let original = root.appendingPathComponent("a.txt")
        let other = root.appendingPathComponent("b.txt")
        try Data("a".utf8).write(to: original)
        try Data("b".utf8).write(to: other)

        XCTAssertThrowsError(try FileRename.apply(at: original, to: "b.txt")) { error in
            XCTAssertEqual(error as? FileRenameError, .nameTaken("b.txt"))
        }
        XCTAssertEqual(try Data(contentsOf: original), Data("a".utf8))
        XCTAssertEqual(try Data(contentsOf: other), Data("b".utf8))
        let names = try FileManager.default.contentsOfDirectory(atPath: root.path)
        XCTAssertEqual(Set(names), ["a.txt", "b.txt"])
    }

    func testCaseOnlyRenameKeepsASingleFile() throws {
        let file = root.appendingPathComponent("Report")
        try Data("body".utf8).write(to: file)

        let renamed = try FileRename.apply(at: file, to: "report")

        XCTAssertEqual(try Data(contentsOf: renamed), Data("body".utf8))
        let names = try FileManager.default.contentsOfDirectory(atPath: root.path)
        XCTAssertEqual(names, ["report"])
    }

    func testRenameSymlinkLeavesTargetInPlace() throws {
        let target = root.appendingPathComponent("target.txt")
        try Data("target".utf8).write(to: target)
        let link = root.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)

        let renamed = try FileRename.apply(at: link, to: "link-renamed")

        XCTAssertEqual(try Data(contentsOf: target), Data("target".utf8))
        XCTAssertFalse(FileManager.default.fileExists(atPath: link.path))
        let destination = try FileManager.default.destinationOfSymbolicLink(atPath: renamed.path)
        XCTAssertTrue(destination.hasSuffix("target.txt"))
    }

    func testRenameFinderAliasLeavesTargetInPlace() throws {
        let folder = root.appendingPathComponent("Docs", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let alias = root.appendingPathComponent("DocsAlias")
        let data = try folder.bookmarkData(
            options: .suitableForBookmarkFile,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        try URL.writeBookmarkData(data, to: alias)

        _ = try FileRename.apply(at: alias, to: "DocsAliasRenamed")

        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: alias.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("DocsAliasRenamed").path))
    }

    func testCaseOnlyRenameLeavesTheOriginalWhenTheMoveFails() throws {
        let file = root.appendingPathComponent("Report")
        try Data("body".utf8).write(to: file)
        let moves = FileRename.Move { _, _ in
            throw CocoaError(.fileWriteUnknown)
        }

        XCTAssertThrowsError(try FileRename.apply(at: file, to: "report", moves: moves))
        XCTAssertEqual(try Data(contentsOf: file), Data("body".utf8))
        let names = try FileManager.default.contentsOfDirectory(atPath: root.path)
        XCTAssertEqual(names, ["Report"])
        XCTAssertFalse(names.contains { $0.hasPrefix(".macxplorer-rename-") })
    }

    func testCaseOnlyRenameChangesTheNameInOneMove() throws {
        let file = root.appendingPathComponent("Report")
        try Data("body".utf8).write(to: file)

        let renamed = try FileRename.apply(at: file, to: "report")

        XCTAssertEqual(renamed.lastPathComponent, "report")
        XCTAssertEqual(try Data(contentsOf: renamed), Data("body".utf8))
        let names = try FileManager.default.contentsOfDirectory(atPath: root.path)
        XCTAssertEqual(names, ["report"])
        XCTAssertFalse(names.contains { $0.hasPrefix(".macxplorer-rename-") })
    }
}
