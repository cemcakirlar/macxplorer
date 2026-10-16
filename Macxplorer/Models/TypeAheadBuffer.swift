import Foundation

struct TypeAheadBuffer: Equatable {
    static let defaultTimeout: TimeInterval = 0.8

    private(set) var text = ""
    private var lastKeyAt: Date?

    mutating func clear() {
        text = ""
        lastKeyAt = nil
    }

    /// Appends a printable character, resetting the buffer when the timeout elapsed.
    mutating func append(
        _ character: Character,
        now: Date = .now,
        timeout: TimeInterval = defaultTimeout
    ) {
        guard character.isLetter || character.isNumber || character.isPunctuation || character == " " else {
            return
        }
        resetIfTimedOut(now: now, timeout: timeout)
        text.append(character)
        lastKeyAt = now
    }

    /// Removes the last character. Clears when empty.
    mutating func backspace(now: Date = .now, timeout: TimeInterval = defaultTimeout) {
        resetIfTimedOut(now: now, timeout: timeout)
        guard !text.isEmpty else { return }
        text.removeLast()
        lastKeyAt = text.isEmpty ? nil : now
    }

    private mutating func resetIfTimedOut(now: Date, timeout: TimeInterval) {
        guard let lastKeyAt, now.timeIntervalSince(lastKeyAt) >= timeout else { return }
        text = ""
        self.lastKeyAt = nil
    }
}
