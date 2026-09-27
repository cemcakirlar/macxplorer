import AppKit
import Foundation
import Observation

struct TerminalChoice: Identifiable, Hashable, Sendable {
    let name: String
    let path: String

    var id: String { path }
}

enum TerminalApps {
    static let defaultPath = "/System/Applications/Utilities/Terminal.app"

    private static let known: [(name: String, bundleID: String, fallback: String?)] = [
        ("Terminal", "com.apple.Terminal", defaultPath),
        ("iTerm", "com.googlecode.iterm2", nil),
        ("Ghostty", "com.mitchellh.ghostty", nil),
        ("Warp", "dev.warp.Warp-Stable", nil),
    ]

    @MainActor
    static func installed() -> [TerminalChoice] {
        known.compactMap { item in
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: item.bundleID) {
                return TerminalChoice(name: item.name, path: url.standardizedFileURL.path)
            }
            guard let fallback = item.fallback else { return nil }
            return TerminalChoice(name: item.name, path: fallback)
        }
    }
}

@MainActor
@Observable
final class AppSettings {
    static let shared = AppSettings()

    private enum Key {
        static let showHidden = "showHidden"
        static let reopenLastFolder = "reopenLastFolder"
        static let lastFolderPath = "lastFolderPath"
        static let terminalAppPath = "terminalAppPath"
    }

    private let defaults: UserDefaults

    var showHidden: Bool {
        didSet { defaults.set(showHidden, forKey: Key.showHidden) }
    }

    var reopenLastFolder: Bool {
        didSet { defaults.set(reopenLastFolder, forKey: Key.reopenLastFolder) }
    }

    var lastFolderPath: String? {
        didSet {
            if let lastFolderPath {
                defaults.set(lastFolderPath, forKey: Key.lastFolderPath)
            } else {
                defaults.removeObject(forKey: Key.lastFolderPath)
            }
        }
    }

    var terminalAppPath: String {
        didSet { defaults.set(terminalAppPath, forKey: Key.terminalAppPath) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        showHidden = defaults.bool(forKey: Key.showHidden)
        if defaults.object(forKey: Key.reopenLastFolder) == nil {
            reopenLastFolder = true
        } else {
            reopenLastFolder = defaults.bool(forKey: Key.reopenLastFolder)
        }
        lastFolderPath = defaults.string(forKey: Key.lastFolderPath)
        let storedTerminal = defaults.string(forKey: Key.terminalAppPath)
        if let storedTerminal, !storedTerminal.isEmpty {
            terminalAppPath = storedTerminal
        } else {
            terminalAppPath = TerminalApps.defaultPath
        }
    }

    func rememberFolder(_ url: URL) {
        lastFolderPath = url.directoryKey.path
    }

    func restoreDefaults() {
        showHidden = false
        reopenLastFolder = true
        terminalAppPath = TerminalApps.defaultPath
    }
}
