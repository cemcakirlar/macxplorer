import XCTest
@testable import Macxplorer

final class TypeAheadBufferTests: XCTestCase {
    func testAppendBuildsBuffer() {
        var buffer = TypeAheadBuffer()
        let t0 = Date(timeIntervalSince1970: 1_000)
        buffer.append("D", now: t0)
        buffer.append("o", now: t0.addingTimeInterval(0.1))
        XCTAssertEqual(buffer.text, "Do")
    }

    func testTimeoutResetsBuffer() {
        var buffer = TypeAheadBuffer()
        let t0 = Date(timeIntervalSince1970: 1_000)
        buffer.append("D", now: t0)
        buffer.append("o", now: t0.addingTimeInterval(1.0))
        XCTAssertEqual(buffer.text, "o")
    }

    func testBackspaceTrims() {
        var buffer = TypeAheadBuffer()
        let t0 = Date(timeIntervalSince1970: 1_000)
        buffer.append("D", now: t0)
        buffer.append("o", now: t0.addingTimeInterval(0.1))
        buffer.backspace(now: t0.addingTimeInterval(0.2))
        XCTAssertEqual(buffer.text, "D")
        buffer.backspace(now: t0.addingTimeInterval(0.3))
        XCTAssertEqual(buffer.text, "")
    }

    func testClearEmpties() {
        var buffer = TypeAheadBuffer()
        buffer.append("a", now: Date(timeIntervalSince1970: 1))
        buffer.clear()
        XCTAssertEqual(buffer.text, "")
    }

    func testIgnoresControlCharacters() {
        var buffer = TypeAheadBuffer()
        let t0 = Date(timeIntervalSince1970: 1_000)
        buffer.append("\n", now: t0)
        buffer.append("\t", now: t0)
        XCTAssertEqual(buffer.text, "")
        buffer.append("a", now: t0)
        XCTAssertEqual(buffer.text, "a")
    }
}
