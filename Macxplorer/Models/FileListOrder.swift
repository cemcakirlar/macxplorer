import Foundation

enum FileSortColumn: Equatable {
    case name
    case modified
    case size
    case kind
}

struct FileSort: Equatable {
    var column: FileSortColumn
    var ascending: Bool

    static let nameAscending = FileSort(column: .name, ascending: true)

    init(column: FileSortColumn, ascending: Bool) {
        self.column = column
        self.ascending = ascending
    }

    init(order: [KeyPathComparator<FileEntry>]) {
        guard let first = order.first else {
            self = .nameAscending
            return
        }
        let ascending = first.order == .forward
        switch first.keyPath {
        case \FileEntry.name:
            self.init(column: .name, ascending: ascending)
        case \FileEntry.modifiedColumn:
            self.init(column: .modified, ascending: ascending)
        case \FileEntry.sizeColumn:
            self.init(column: .size, ascending: ascending)
        case \FileEntry.kind:
            self.init(column: .kind, ascending: ascending)
        default:
            self = .nameAscending
        }
    }
}

enum FileListOrder {
    static func sorted(_ entries: [FileEntry], by sort: FileSort = .nameAscending) -> [FileEntry] {
        entries.sorted { comesBefore($0, $1, sort: sort) }
    }

    private static func comesBefore(_ lhs: FileEntry, _ rhs: FileEntry, sort: FileSort) -> Bool {
        let primary = primaryOrder(lhs, rhs, sort: sort)
        if primary != .orderedSame {
            return primary == .orderedAscending
        }
        return tieBreak(lhs, rhs)
    }

    private static func primaryOrder(_ lhs: FileEntry, _ rhs: FileEntry, sort: FileSort) -> ComparisonResult {
        switch sort.column {
        case .name:
            if lhs.opensAsFolder != rhs.opensAsFolder {
                return lhs.opensAsFolder ? .orderedAscending : .orderedDescending
            }
            return directed(lhs.name.localizedStandardCompare(rhs.name), ascending: sort.ascending)
        case .modified:
            return directedOptional(lhs.modified, rhs.modified, ascending: sort.ascending)
        case .size:
            return directedOptional(lhs.size, rhs.size, ascending: sort.ascending)
        case .kind:
            return directed(lhs.kind.localizedStandardCompare(rhs.kind), ascending: sort.ascending)
        }
    }

    private static func directed(_ result: ComparisonResult, ascending: Bool) -> ComparisonResult {
        if ascending || result == .orderedSame {
            return result
        }
        return result == .orderedAscending ? .orderedDescending : .orderedAscending
    }

    /// Missing values stay at the bottom in both directions.
    private static func directedOptional<T: Comparable>(
        _ lhs: T?,
        _ rhs: T?,
        ascending: Bool
    ) -> ComparisonResult {
        switch (lhs, rhs) {
        case (nil, nil):
            return .orderedSame
        case (nil, _):
            return .orderedDescending
        case (_, nil):
            return .orderedAscending
        case let (left?, right?):
            if left == right { return .orderedSame }
            let natural: ComparisonResult = left < right ? .orderedAscending : .orderedDescending
            return directed(natural, ascending: ascending)
        }
    }

    private static func tieBreak(_ lhs: FileEntry, _ rhs: FileEntry) -> Bool {
        let name = lhs.name.localizedStandardCompare(rhs.name)
        if name != .orderedSame {
            return name == .orderedAscending
        }
        return lhs.url.path.localizedStandardCompare(rhs.url.path) == .orderedAscending
    }
}
