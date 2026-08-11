import Foundation

func formatNumber(_ value: Int) -> String { value.formatted(.number.grouping(.automatic)) }

func formatCompactNumber(_ value: Int) -> String {
    switch abs(value) {
    case 1_000_000...: return String(format: "%.1fM", Double(value) / 1_000_000)
    case 1_000...: return String(format: "%.1fK", Double(value) / 1_000)
    default: return formatNumber(value)
    }
}
