import XCTest
@testable import Macxplorer

final class TransferNamesTests: XCTestCase {
    func testKeepBothUsesCopyThenANumber() {
        XCTAssertEqual(
            TransferNames.keepBothName(for: "Notlar.txt", existing: ["Notlar.txt"], caseSensitive: false),
            "Notlar copy.txt"
        )
        XCTAssertEqual(
            TransferNames.keepBothName(
                for: "Notlar.txt",
                existing: ["Notlar.txt", "Notlar copy.txt"],
                caseSensitive: false
            ),
            "Notlar copy 2.txt"
        )
        XCTAssertEqual(
            TransferNames.keepBothName(
                for: "Notlar.txt",
                existing: ["Notlar.txt", "Notlar copy.txt", "Notlar copy 2.txt"],
                caseSensitive: false
            ),
            "Notlar copy 3.txt"
        )
    }

    func testKeepBothUsesOnlyTheLastExtension() {
        XCTAssertEqual(
            TransferNames.keepBothName(for: "file.tar.gz", existing: ["file.tar.gz"], caseSensitive: false),
            "file.tar copy.gz"
        )
        XCTAssertEqual(
            TransferNames.keepBothName(for: "Projects", existing: ["Projects"], caseSensitive: false),
            "Projects copy"
        )
        XCTAssertEqual(
            TransferNames.keepBothName(for: ".gitignore", existing: [".gitignore"], caseSensitive: false),
            ".gitignore copy"
        )
    }

    func testKeepBothTreatsADifferentCaseAsTaken() {
        XCTAssertEqual(
            TransferNames.keepBothName(
                for: "Notlar.txt",
                existing: ["Notlar.txt", "NOTLAR COPY.TXT"],
                caseSensitive: false
            ),
            "Notlar copy 2.txt"
        )
    }

    func testDecisionAsksUntilAChoiceIsSet() {
        XCTAssertEqual(
            TransferNames.decision(name: "Notlar.txt", existing: [], caseSensitive: false, choice: nil),
            .write("Notlar.txt")
        )
        XCTAssertEqual(
            TransferNames.decision(name: "Notlar.txt", existing: ["Notlar.txt"], caseSensitive: false, choice: nil),
            .ask("Notlar.txt")
        )
    }

    func testStopWritesNothingFurther() {
        XCTAssertEqual(
            TransferNames.decision(name: "Notlar.txt", existing: ["Notlar.txt"], caseSensitive: false, choice: .stop),
            .stop
        )
        XCTAssertEqual(
            TransferNames.decision(name: "free.txt", existing: [], caseSensitive: false, choice: .stop),
            .stop
        )
    }

    func testKeepBothAndReplaceResolveATakenName() {
        XCTAssertEqual(
            TransferNames.decision(
                name: "Notlar.txt",
                existing: ["Notlar.txt", "Notlar copy.txt"],
                caseSensitive: false,
                choice: .keepBoth
            ),
            .write("Notlar copy 2.txt")
        )
        XCTAssertEqual(
            TransferNames.decision(name: "Notlar.txt", existing: ["Notlar.txt"], caseSensitive: false, choice: .replace),
            .replace("Notlar.txt")
        )
        XCTAssertEqual(
            TransferNames.decision(name: "free.txt", existing: ["Notlar.txt"], caseSensitive: false, choice: .replace),
            .write("free.txt")
        )
    }

    func testDestinationInsideTheSourceIsRefused() {
        let source = URL(fileURLWithPath: "/Users/a/Folder", isDirectory: true)
        XCTAssertTrue(
            TransferNames.destinationIsInside(source, destinationDirectory: source)
        )
        XCTAssertTrue(
            TransferNames.destinationIsInside(
                source,
                destinationDirectory: URL(fileURLWithPath: "/Users/a/Folder/Nested", isDirectory: true)
            )
        )
        XCTAssertFalse(
            TransferNames.destinationIsInside(
                source,
                destinationDirectory: URL(fileURLWithPath: "/Users/a/FolderB", isDirectory: true)
            )
        )
    }
}
