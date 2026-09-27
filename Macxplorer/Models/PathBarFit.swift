import CoreGraphics

enum PathBarFit {
    /// How many leading crumbs to hide so the tail fits in `limit`.
    /// The last crumb always stays visible.
    static func hiddenPrefixCount(
        crumbWidths: [CGFloat],
        gap: CGFloat,
        limit: CGFloat,
        ellipsisWidth: CGFloat
    ) -> Int {
        let count = crumbWidths.count
        guard count > 1 else { return 0 }
        if width(from: 0, crumbWidths: crumbWidths, gap: gap, ellipsisWidth: ellipsisWidth) <= limit {
            return 0
        }
        var hidden = 1
        while hidden < count - 1,
              width(from: hidden, crumbWidths: crumbWidths, gap: gap, ellipsisWidth: ellipsisWidth) > limit {
            hidden += 1
        }
        return hidden
    }

    private static func width(
        from index: Int,
        crumbWidths: [CGFloat],
        gap: CGFloat,
        ellipsisWidth: CGFloat
    ) -> CGFloat {
        let crumbs = crumbWidths[index...].reduce(0, +)
        let separators = CGFloat(max(0, crumbWidths.count - index - 1)) * gap
        let lead = index > 0 ? ellipsisWidth + gap : 0
        return crumbs + separators + lead
    }
}
