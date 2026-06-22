import SwiftUI

extension Color {
    // MARK: - Brand Colors

    static let brandPrimary = Color(hex: "#A5E74C")
    static let brandSecondary = Color(hex: "#F5FEE9")

    // MARK: - Core

    static let background = Color(hex: "#F5FEE9")
    static let canvasBackground = Color(hex: "#E8F0DC")
    static let foreground = Color.black

    static let card = Color.white
    static let cardForeground = Color.black

    static let popover = Color(hex: "#FCFEF8")
    static let popoverForeground = Color.black

    // MARK: - Semantic

    static let primary = Color(hex: "#A5E74C")
    static let primaryForeground = Color.black

    static let secondary = Color(hex: "#EEF7DD")
    static let secondaryForeground = Color(hex: "#1E1E1E")

    static let muted = Color(hex: "#F4F7EF")
    static let mutedForeground = Color(hex: "#7A7A7A")

    static let appAccent = Color(hex: "#6D9E2F")
    static let accentForeground = Color.white

    static let destructive = Color(hex: "#E5484D")
    static let destructiveForeground = Color.white

    // MARK: - UI

    static let border = Color(hex: "#E2E8D8")
    static let input = Color(hex: "#F0F5E7")
    static let ring = Color(hex: "#A5E74C")

    // MARK: - Charts

    static let chart1 = Color(hex: "#A5E74C")
    static let chart2 = Color(hex: "#7BC96F")
    static let chart3 = Color(hex: "#D6F5A3")
    static let chart4 = Color(hex: "#5E8E2E")
    static let chart5 = Color(hex: "#A8B29A")

    // MARK: - Sidebar

    static let sidebar = Color(hex: "#FAFDF5")
    static let sidebarForeground = Color.black

    static let sidebarPrimary = Color(hex: "#A5E74C")
    static let sidebarPrimaryForeground = Color.black

    static let sidebarAccent = Color(hex: "#EAF8CF")
    static let sidebarAccentForeground = Color.black

    static let sidebarBorder = Color(hex: "#E2E8D8")
    static let sidebarRing = Color(hex: "#A5E74C")
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)

        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let r, g, b: UInt64

        switch hex.count {
        case 6:
            (r, g, b) = (
                (int >> 16) & 0xff,
                (int >> 8) & 0xff,
                int & 0xff
            )
        default:
            (r, g, b) = (0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}
