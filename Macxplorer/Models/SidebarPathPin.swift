import Foundation

enum SidebarPathPin {
    /// Parent/child pairs on `chain` whose child is missing from an already loaded parent.
    static func missingLinks(
        chain: [URL],
        childPathsByParent: [String: Set<String>]
    ) -> [(parent: String, child: String)] {
        guard chain.count > 1 else { return [] }
        var missing: [(parent: String, child: String)] = []
        for index in 1..<chain.count {
            let parent = chain[index - 1].directoryKey.path
            let child = chain[index].directoryKey.path
            guard let existing = childPathsByParent[parent] else { continue }
            if existing.contains(child) { continue }
            missing.append((parent, child))
        }
        return missing
    }

    static func stalePins(pinned: Set<String>, chain: [URL]) -> Set<String> {
        let onPath = Set(chain.dropFirst().map(\.directoryKey.path))
        return pinned.subtracting(onPath)
    }
}
