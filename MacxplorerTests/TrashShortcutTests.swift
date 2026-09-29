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
        XCTAssertTrue(TrashShortcut.matches([.command, .function]))
        XCTAssertFalse(TrashShortcut.matches(.function))
        XCTAssertFalse(TrashShortcut.matches([.function, .shift]))
    }

    func testOtherModifiersDoNotTrash() {
        XCTAssertFalse(TrashShortcut.matches([.command, .shift]))
        XCTAssertFalse(TrashShortcut.matches([.command, .option]))
        XCTAssertFalse(TrashShortcut.matches(.shift))
    }
}
