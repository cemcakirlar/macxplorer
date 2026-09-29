import SwiftUI
import XCTest
@testable import Macxplorer

final class TrashShortcutTests: XCTestCase {
    func testPlainDeleteDoesNotTrash() {
        XCTAssertFalse(TrashShortcut.matches([]))
    }

    func testCommandDeleteTrashes() {
        XCTAssertTrue(TrashShortcut.matches(.command))
    }

    func testCapsLockDoesNotChangeTheAnswer() {
        XCTAssertTrue(TrashShortcut.matches([.command, .capsLock]))
        XCTAssertFalse(TrashShortcut.matches(.capsLock))
    }

    func testDeleteKeysReportTheFunctionFlag() {
        XCTAssertEqual(TrashShortcut.functionKey.rawValue, 64)
        XCTAssertTrue(TrashShortcut.matches(EventModifiers(rawValue: 80)), "Command-Delete as logged")
        XCTAssertFalse(TrashShortcut.matches(EventModifiers(rawValue: 64)), "plain Delete as logged")
        XCTAssertFalse(TrashShortcut.matches([TrashShortcut.functionKey, .shift]))
    }

    func testOtherModifiersDoNotTrash() {
        XCTAssertFalse(TrashShortcut.matches([.command, .shift]))
        XCTAssertFalse(TrashShortcut.matches([.command, .option]))
        XCTAssertFalse(TrashShortcut.matches(.shift))
    }
}
