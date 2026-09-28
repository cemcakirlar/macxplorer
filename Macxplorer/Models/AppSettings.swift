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
        static let showHiddenInSidebar = "showHiddenInSidebar"
        static let sidebarRootHome = "sidebarRootHome"
        static let sidebarRootRoot = "sidebarRootRoot"
        static let sidebarRootVolumes = "sidebarRootVolumes"
        static let reopenLastFolder = "reopenLastFolder"
        static let lastFolderPath = "lastFolderPath"
        static let terminalAppPath = "terminalAppPath"
        static let showPreview = "showPreview"
        static let previewAutoplay = "previewAutoplay"
        static let favoritePaths = "favoritePaths"
    }

    private let defaults: UserDefaults

    var showHidden: Bool {
        didSet { defaults.set(showHidden, forKey: Key.showHidden) }
    }

    var showHiddenInSidebar: Bool {
        didSet { defaults.set(showHiddenInSidebar, forKey: Key.showHiddenInSidebar) }
    }

    var sidebarRootHome: String {
        didSet { defaults.set(sidebarRootHome, forKey: Key.sidebarRootHome) }
    }

    var sidebarRootRoot: String {
        didSet { defaults.set(sidebarRootRoot, forKey: Key.sidebarRootRoot) }
    }

    var sidebarRootVolumes: String {
        didSet { defaults.set(sidebarRootVolumes, forKey: Key.sidebarRootVolumes) }
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

    var showPreview: Bool {
        didSet { defaults.set(showPreview, forKey: Key.showPreview) }
    }

    var previewAutoplay: Bool {
        didSet { defaults.set(previewAutoplay, forKey: Key.previewAutoplay) }
    }

    var favoritePaths: [String] {
        didSet { defaults.set(favoritePaths, forKey: Key.favoritePaths) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        showHidden = defaults.bool(forKey: Key.showHidden)
        showHiddenInSidebar = defaults.bool(forKey: Key.showHiddenInSidebar)
        sidebarRootHome = defaults.string(forKey: Key.sidebarRootHome) ?? SidebarRootLabel.home
        sidebarRootRoot = defaults.string(forKey: Key.sidebarRootRoot) ?? SidebarRootLabel.root
        sidebarRootVolumes = defaults.string(forKey: Key.sidebarRootVolumes) ?? SidebarRootLabel.volumes
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
        showPreview = defaults.bool(forKey: Key.showPreview)
        previewAutoplay = defaults.bool(forKey: Key.previewAutoplay)
        favoritePaths = defaults.stringArray(forKey: Key.favoritePaths) ?? []
    }

    func rememberFolder(_ url: URL) {
        lastFolderPath = url.directoryKey.path
    }

    func restoreDefaults() {
        showHidden = false
        showHiddenInSidebar = false
        sidebarRootHome = SidebarRootLabel.home
        sidebarRootRoot = SidebarRootLabel.root
        sidebarRootVolumes = SidebarRootLabel.volumes
        reopenLastFolder = true
        terminalAppPath = TerminalApps.defaultPath
        showPreview = false
        previewAutoplay = false
    }
}
