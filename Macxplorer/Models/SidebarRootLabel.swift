import Foundation

enum SidebarRootLabel {
    static let home = "Home"
    static let root = "Root"
    static let volumes = "Volumes"

    static func resolved(_ stored: String, fallback: String) -> String {
        let trimmed = stored.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}
