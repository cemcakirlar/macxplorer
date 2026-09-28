import XCTest
@testable import Macxplorer

final class RenameNameTests: XCTestCase {
    func testUnchangedOrBlankNameCancels() {
        XCTAssertEqual(decide(current: "Notes.txt", proposed: "Notes.txt"), .cancel)
        XCTAssertEqual(decide(current: "Notes.txt", proposed: ""), .cancel)
    }

    func testReservedDotNamesAreRejected() {
        XCTAssertEqual(
            decide(current: "Notes.txt", proposed: "."),
            .rejected(.reservedName("."))
        )
        XCTAssertEqual(
            decide(current: "Notes.txt", proposed: ".."),
            .rejected(.reservedName(".."))
        )
    }

    func testColonAndSlashAreRejected() {
        XCTAssertEqual(
            decide(current: "Notes.txt", proposed: "A/B"),
            .rejected(.invalidCharacters("A/B"))
        )
        XCTAssertEqual(
            decide(current: "Notes.txt", proposed: "A:B"),
            .rejected(.invalidCharacters("A:B"))
        )
    }

    func testNameLongerThan255BytesIsRejected() {
        let limit = String(repeating: "a", count: 255)
        let longer = String(repeating: "a", count: 256)
        XCTAssertEqual(decide(current: "Notes", proposed: limit), .commit(limit))
        XCTAssertEqual(decide(current: "Notes", proposed: longer), .rejected(.tooLong(longer)))

        let accented = String(repeating: "é", count: 128)
        XCTAssertEqual(accented.utf8.count, 256)
        XCTAssertEqual(decide(current: "Notes.txt", proposed: accented), .rejected(.tooLong(accented)))
    }

    func testTakenNameDoesNotCommit() {
        let decision = decide(
            current: "Report",
            proposed: "notes",
            siblings: ["Report", "Notes"]
        )
        XCTAssertEqual(decision, .rejected(.nameTaken("notes")))
        XCTAssertEqual(
            RenameRejection.nameTaken("notes").message,
            "The name “notes” is already taken. Please choose a different name."
        )
    }

    func testCaseOnlyRenameCommitsOnCaseInsensitiveVolume() {
        let decision = decide(
            current: "Report",
            proposed: "report",
            siblings: ["Report"],
            caseSensitive: false
        )
        XCTAssertEqual(decision, .commit("report"))
    }

    func testCaseSensitiveVolumeTreatsDifferentCaseAsAnotherFile() {
        let free = decide(
            current: "Report",
            proposed: "report",
            siblings: ["Report"],
            caseSensitive: true
        )
        let taken = decide(
            current: "Report",
            proposed: "report",
            siblings: ["Report", "report"],
            caseSensitive: true
        )
        XCTAssertEqual(free, .commit("report"))
        XCTAssertEqual(taken, .rejected(.nameTaken("report")))
    }

    func testFileExtensionChangeAsksBeforeCommit() {
        let decision = decide(current: "Notes.txt", proposed: "Notes.jpg")
        XCTAssertEqual(decision, .confirmExtension(from: "txt", to: "jpg"))
        let prompt = RenameExtensionPrompt(from: "txt", to: "jpg")
        XCTAssertEqual(
            prompt.title,
            "Are you sure you want to change the extension from “.txt” to “.jpg”?"
        )
        XCTAssertEqual(prompt.keepButton, "Keep .txt")
        XCTAssertEqual(prompt.useButton, "Use .jpg")

        let confirmed = decide(
            current: "Notes.txt",
            proposed: "Notes.jpg",
            extensionChangeConfirmed: true
        )
        XCTAssertEqual(confirmed, .commit("Notes.jpg"))
    }

    func testKeepExtensionRestoresThePreviousSuffix() {
        XCTAssertEqual(
            RenameName.nameByRestoringExtension("memo.jpg", extension: "txt"),
            "memo.txt"
        )
        XCTAssertEqual(
            RenameName.nameByRestoringExtension("file.tar.jpg", extension: "gz"),
            "file.tar.gz"
        )
    }

    func testFolderAndSingleDotNamesDoNotAskAboutExtensions() {
        XCTAssertEqual(
            decide(current: "Folder", proposed: "Folder.txt", isFolder: true),
            .commit("Folder.txt")
        )
        XCTAssertEqual(decide(current: ".gitignore", proposed: ".gitconfig"), .commit(".gitconfig"))
    }

    func testSelectionKeepsTheLastExtensionUnselected() {
        XCTAssertEqual(RenameName.selectedPrefix(in: "file.tar.gz", isFolder: false), "file.tar")
        XCTAssertEqual(RenameName.selectedPrefix(in: "Project", isFolder: true), "Project")
        XCTAssertEqual(RenameName.selectedPrefix(in: ".gitignore", isFolder: false), ".gitignore")
    }

    func testFilteringRemovesColonAndSlash() {
        XCTAssertEqual(RenameName.filtering("Plans/Q3:final"), "PlansQ3final")
    }

    func testPathRewriteUpdatesTheFolderAndDescendantsOnly() {
        XCTAssertEqual(
            RenamedPath.rewriting("/Users/ada/Documents", from: "/Users/ada/Documents", to: "/Users/ada/Docs"),
            "/Users/ada/Docs"
        )
        XCTAssertEqual(
            RenamedPath.rewriting("/Users/ada/Documents/Photos", from: "/Users/ada/Documents/", to: "/Users/ada/Docs"),
            "/Users/ada/Docs/Photos"
        )
        XCTAssertEqual(
            RenamedPath.rewriting("/Users/ab", from: "/Users/a", to: "/Users/b"),
            "/Users/ab"
        )
    }

    func testFavoritesRewriteDropsACollapsedDuplicate() {
        let rewritten = Favorites.rewriting(
            ["/Users/ada/Documents", "/Users/ada/Documents/Photos", "/Users/ab"],
            from: "/Users/ada/Documents",
            to: "/Users/ada/Docs"
        )
        XCTAssertEqual(
            rewritten,
            ["/Users/ada/Docs", "/Users/ada/Docs/Photos", "/Users/ab"]
        )
        let collapsed = Favorites.rewriting(
            ["/Users/ada/Documents", "/Users/ada/Docs"],
            from: "/Users/ada/Documents",
            to: "/Users/ada/Docs"
        )
        XCTAssertEqual(collapsed, ["/Users/ada/Docs"])
    }

    func testHistoryRewriteMovesBackAndForwardStacks() {
        let home = URL(fileURLWithPath: "/Users/ada", isDirectory: true)
        let documents = URL(fileURLWithPath: "/Users/ada/Documents", isDirectory: true)
        let photos = URL(fileURLWithPath: "/Users/ada/Documents/Photos", isDirectory: true)
        let docs = URL(fileURLWithPath: "/Users/ada/Docs", isDirectory: true)
        var history = NavigationHistory()
        history.recordVisit(from: home, to: documents)
        history.recordVisit(from: documents, to: photos)
        history.rewrite(from: documents, to: docs)

        let photosNow = URL(fileURLWithPath: "/Users/ada/Docs/Photos", isDirectory: true)
        XCTAssertEqual(history.goBack(from: photosNow)?.path, "/Users/ada/Docs")
        XCTAssertEqual(history.goBack(from: docs)?.path, "/Users/ada")
    }

    private func decide(
        current: String,
        proposed: String,
        isFolder: Bool = false,
        siblings: [String] = [],
        caseSensitive: Bool = false,
        extensionChangeConfirmed: Bool = false
    ) -> RenameDecision {
        RenameName.decision(
            currentName: current,
            proposedName: proposed,
            isFolder: isFolder,
            siblingNames: siblings,
            caseSensitive: caseSensitive,
            extensionChangeConfirmed: extensionChangeConfirmed
        )
    }
}
