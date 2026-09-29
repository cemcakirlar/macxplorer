import Foundation
import Observation

struct ActionAlert: Identifiable {
    enum Kind {
        case acknowledge
        case collision
    }

    let id = UUID()
    var title: String
    var message: String
    var kind: Kind = .acknowledge
}

/// Shows one alert at a time. Later alerts wait their turn instead of replacing the one on screen,
/// so a transfer waiting on a collision answer always resumes.
@MainActor
@Observable
final class AlertPresenter {
    private(set) var current: ActionAlert?
    @ObservationIgnored private var pending: [Entry] = []
    @ObservationIgnored private var active: Entry?

    private struct Entry {
        let alert: ActionAlert
        let resume: ((TransferChoice) -> Void)?
    }

    func show(_ alert: ActionAlert) {
        enqueue(Entry(alert: alert, resume: nil))
    }

    func ask(_ alert: ActionAlert) async -> TransferChoice {
        await withCheckedContinuation { continuation in
            enqueue(Entry(alert: alert, resume: { continuation.resume(returning: $0) }))
        }
    }

    /// Dismissal without a button counts as Stop. An `id` that is not on screen is ignored.
    func finish(_ id: ActionAlert.ID, choice: TransferChoice = .stop) {
        guard let entry = active, entry.alert.id == id else { return }
        active = nil
        current = nil
        entry.resume?(choice)
        // SwiftUI has to see the dismissal before the next alert, or the next one never presents.
        Task { @MainActor in self.advance() }
    }

    private func enqueue(_ entry: Entry) {
        pending.append(entry)
        advance()
    }

    private func advance() {
        guard active == nil, !pending.isEmpty else { return }
        let next = pending.removeFirst()
        active = next
        current = next.alert
    }
}
