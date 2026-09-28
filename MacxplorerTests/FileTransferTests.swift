import XCTest
@testable import Macxplorer

final class FileTransferTests: XCTestCase {
    private var root: URL!
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

    func testCopyLeavesTheSourceInPlace() throws {
        let source = try file("note.txt", bytes: "hello")
        let destination = otherFolder().appendingPathComponent("note.txt")

        let wrote = try FileTransfer.perform(from: source, to: destination, moving: false, replacing: false)

        XCTAssertEqual(try Data(contentsOf: wrote.url), Data("hello".utf8))
        XCTAssertEqual(try Data(contentsOf: source), Data("hello".utf8))
        XCTAssertNil(wrote.movedFrom)
        XCTAssertNil(wrote.displaced)
    }

    func testSameVolumeMoveRemovesTheSource() throws {
        let source = try file("note.txt", bytes: "move")
        let destination = otherFolder().appendingPathComponent("note.txt")

        let wrote = try FileTransfer.perform(from: source, to: destination, moving: true, replacing: false)

        XCTAssertEqual(wrote.movedFrom, source)
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
        XCTAssertEqual(try Data(contentsOf: destination), Data("move".utf8))
        XCTAssertNil(wrote.crossVolumeSource)
    }

    func testCrossVolumeMoveCopiesThenTrashesTheSource() throws {
        let source = try file("note.txt", bytes: "across")
        let destination = otherFolder().appendingPathComponent("note.txt")
        let operations = FileTransfer.Operations.live.forcingSeparateVolumes()

        let wrote = try FileTransfer.perform(
            from: source,
            to: destination,
            moving: true,
            replacing: false,
            operations: operations
        )

        if let trashed = wrote.crossVolumeSource?.trashed {
            trashCopies.append(trashed)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
        XCTAssertEqual(try Data(contentsOf: destination), Data("across".utf8))
        XCTAssertEqual(try Data(contentsOf: wrote.crossVolumeSource!.trashed), Data("across".utf8))
    }

    func testCrossVolumeMoveLeavesTheSourceWhenTheCopyFails() throws {
        let source = try file("note.txt", bytes: "stay")
        let destination = otherFolder().appendingPathComponent("note.txt")
        let calls = CallCount()
        var operations = FileTransfer.Operations.live.forcingSeparateVolumes()
        operations.copy = { _, _ in
            calls.value += 1
            throw CocoaError(.fileWriteUnknown)
        }

        XCTAssertThrowsError(
            try FileTransfer.perform(from: source, to: destination, moving: true, replacing: false, operations: operations)
        )
        XCTAssertEqual(calls.value, 1)
        XCTAssertEqual(try Data(contentsOf: source), Data("stay".utf8))
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
    }

    func testReplaceTrashesTheExistingItemBeforeWriting() throws {
        let folder = otherFolder()
        let existing = folder.appendingPathComponent("note.txt")
        try Data("old".utf8).write(to: existing)
        let source = try file("fresh.txt", bytes: "new")
        let destination = folder.appendingPathComponent("note.txt")

        let wrote = try FileTransfer.perform(from: source, to: destination, moving: false, replacing: true)
        if let trashed = wrote.displaced?.trashed {
            trashCopies.append(trashed)
        }

        XCTAssertEqual(try Data(contentsOf: destination), Data("new".utf8))
        XCTAssertEqual(try Data(contentsOf: source), Data("new".utf8))
        XCTAssertEqual(try Data(contentsOf: wrote.displaced!.trashed), Data("old".utf8))
    }

    func testReplaceWritesNothingWhenTrashFails() throws {
        let folder = otherFolder()
        let existing = folder.appendingPathComponent("note.txt")
        try Data("keep".utf8).write(to: existing)
        let source = try file("fresh.txt", bytes: "new")
        let calls = CallCount()
        var operations = FileTransfer.Operations.live
        operations.trash = { _ in
            throw CocoaError(.fileWriteUnknown)
        }
        operations.copy = { source, destination in
            calls.value += 1
            try FileManager.default.copyItem(at: source, to: destination)
        }

        XCTAssertThrowsError(
            try FileTransfer.perform(
                from: source,
                to: existing,
                moving: false,
                replacing: true,
                operations: operations
            )
        ) { error in
            XCTAssertEqual(error as? FileTransferError, .trashFailed("note.txt"))
        }
        XCTAssertEqual(calls.value, 0)
        XCTAssertEqual(try Data(contentsOf: existing), Data("keep".utf8))
    }

    func testReplaceRestoresTheOccupantWhenTheWriteFails() throws {
        let folder = otherFolder()
        let existing = folder.appendingPathComponent("note.txt")
        try Data("old".utf8).write(to: existing)
        let source = try file("fresh.txt", bytes: "new")
        var operations = FileTransfer.Operations.live
        operations.copy = { _, _ in
            throw CocoaError(.fileWriteUnknown)
        }

        XCTAssertThrowsError(
            try FileTransfer.perform(from: source, to: existing, moving: false, replacing: true, operations: operations)
        ) { error in
            XCTAssertFalse(error is FileTransferError)
        }
        XCTAssertEqual(try Data(contentsOf: existing), Data("old".utf8))
        XCTAssertEqual(try Data(contentsOf: source), Data("new".utf8))
    }

    func testReplaceLeavesTheOccupantInTheTrashWhenPutBackFails() throws {
        let folder = otherFolder()
        let existing = folder.appendingPathComponent("note.txt")
        try Data("old".utf8).write(to: existing)
        let source = try file("fresh.txt", bytes: "new")
        let holding = root.appendingPathComponent("holding", isDirectory: true)
        try FileManager.default.createDirectory(at: holding, withIntermediateDirectories: true)
        var operations = FileTransfer.Operations.live
        operations.trash = { url in
            let trashed = holding.appendingPathComponent(url.lastPathComponent)
            try FileManager.default.moveItem(at: url, to: trashed)
            return trashed
        }
        operations.copy = { _, _ in
            throw CocoaError(.fileWriteUnknown)
        }
        operations.move = { _, _ in
            throw CocoaError(.fileWriteUnknown)
        }

        XCTAssertThrowsError(
            try FileTransfer.perform(from: source, to: existing, moving: false, replacing: true, operations: operations)
        ) { error in
            XCTAssertEqual(error as? FileTransferError, .occupantLeftInTrash("note.txt"))
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: existing.path))
        XCTAssertEqual(try Data(contentsOf: holding.appendingPathComponent("note.txt")), Data("old".utf8))
        XCTAssertEqual(try Data(contentsOf: source), Data("new".utf8))
    }

    func testReplaceRefusesToTrashTheSourceItself() throws {
        let source = try file("note.txt", bytes: "keep")

        XCTAssertThrowsError(
            try FileTransfer.perform(from: source, to: source, moving: false, replacing: true)
        ) { error in
            XCTAssertEqual(error as? FileTransferError, .sameItem("note.txt"))
        }
        XCTAssertEqual(try Data(contentsOf: source), Data("keep".utf8))
    }

    func testCopyDoesNotOverwriteATakenName() throws {
        let folder = otherFolder()
        let existing = folder.appendingPathComponent("note.txt")
        try Data("keep".utf8).write(to: existing)
        let source = try file("other.txt", bytes: "new")

        XCTAssertThrowsError(
            try FileTransfer.perform(from: source, to: existing, moving: false, replacing: false)
        ) { error in
            XCTAssertEqual(error as? FileTransferError, .nameTaken("note.txt"))
        }
        XCTAssertEqual(try Data(contentsOf: existing), Data("keep".utf8))
        XCTAssertEqual(try Data(contentsOf: source), Data("new".utf8))
    }

    private func file(_ name: String, bytes: String) throws -> URL {
        let url = root.appendingPathComponent(name)
        try Data(bytes.utf8).write(to: url)
        return url
    }

    private func otherFolder() -> URL {
        let folder = root.appendingPathComponent("dest", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }
}

private extension FileTransfer.Operations {
    func forcingSeparateVolumes() -> FileTransfer.Operations {
        var copy = self
        copy.sameVolume = { _, _ in false }
        return copy
    }
}

private final class CallCount: @unchecked Sendable {
    var value = 0
}
