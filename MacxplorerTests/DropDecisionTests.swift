import XCTest
@testable import Macxplorer

final class DropDecisionTests: XCTestCase {
    func testSameDiskMovesAndAnotherDiskCopies() {
        let source = URL(fileURLWithPath: "/Volumes/A/note.txt")
        let folder = DropTargetKind.folder(URL(fileURLWithPath: "/Volumes/A/Dest", isDirectory: true))
        XCTAssertEqual(
            DropDecision.item(source: source, target: folder, sameVolume: true, optionPressed: false),
            .move
        )
        XCTAssertEqual(
            DropDecision.item(source: source, target: folder, sameVolume: false, optionPressed: false),
            .copy
        )
    }

    func testOptionAlwaysCopies() {
        let source = URL(fileURLWithPath: "/Volumes/A/note.txt")
        let folder = DropTargetKind.folder(URL(fileURLWithPath: "/Volumes/A/Dest", isDirectory: true))
        XCTAssertEqual(
            DropDecision.item(source: source, target: folder, sameVolume: true, optionPressed: true),
            .copy
        )
        XCTAssertEqual(
            DropDecision.item(source: source, target: folder, sameVolume: false, optionPressed: true),
            .copy
        )
    }

    func testFileRowAndMissingFavoriteWriteNothing() {
        let source = URL(fileURLWithPath: "/Volumes/A/note.txt")
        XCTAssertEqual(
            DropDecision.item(source: source, target: .file, sameVolume: true, optionPressed: false),
            .refuse
        )
        XCTAssertEqual(
            DropDecision.item(source: source, target: .missing, sameVolume: true, optionPressed: true),
            .refuse
        )
    }

    func testDropOntoItselfOrItsChildWritesNothing() {
        let source = URL(fileURLWithPath: "/Users/a/Folder", isDirectory: true)
        XCTAssertEqual(
            DropDecision.item(
                source: source,
                target: .folder(source),
                sameVolume: true,
                optionPressed: false
            ),
            .refuse
        )
        XCTAssertEqual(
            DropDecision.item(
                source: source,
                target: .folder(URL(fileURLWithPath: "/Users/a/Folder/Nested", isDirectory: true)),
                sameVolume: true,
                optionPressed: true
            ),
            .refuse
        )
    }

    func testNeighborPrefixStillMoves() {
        let source = URL(fileURLWithPath: "/Users/a/Folder", isDirectory: true)
        XCTAssertEqual(
            DropDecision.item(
                source: source,
                target: .folder(URL(fileURLWithPath: "/Users/a/FolderB", isDirectory: true)),
                sameVolume: true,
                optionPressed: false
            ),
            .move
        )
    }

    func testCursorMatchesTheDiskAndTheOptionKey() {
        let folder = DropTargetKind.folder(URL(fileURLWithPath: "/Volumes/A/Dest", isDirectory: true))
        XCTAssertEqual(DropDecision.cursor(target: folder, optionPressed: false, sameVolume: true), .move)
        XCTAssertEqual(DropDecision.cursor(target: folder, optionPressed: false, sameVolume: false), .copy)
        XCTAssertEqual(DropDecision.cursor(target: folder, optionPressed: true, sameVolume: true), .copy)
        XCTAssertEqual(DropDecision.cursor(target: .file, optionPressed: false, sameVolume: true), .forbidden)
        XCTAssertEqual(DropDecision.cursor(target: .missing, optionPressed: false, sameVolume: true), .forbidden)
        XCTAssertEqual(DropDecision.cursor(target: folder, optionPressed: false, sameVolume: nil), .copy)
    }
}
