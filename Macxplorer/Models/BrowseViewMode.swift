import Foundation

enum BrowseViewMode: String, CaseIterable, Identifiable, Sendable {
    case details
    case icons
    case columns

    var id: String { rawValue }

    var title: String {
        switch self {
        case .details: return "Details"
        case .icons: return "Icons"
        case .columns: return "Columns"
        }
    }

    var systemImage: String {
        switch self {
        case .details: return "list.bullet"
        case .icons: return "square.grid.2x2"
        case .columns: return "rectangle.split.3x1"
        }
    }

    static func stored(_ raw: String?) -> BrowseViewMode {
        guard let raw, let mode = BrowseViewMode(rawValue: raw) else { return .details }
        return mode
    }
}
