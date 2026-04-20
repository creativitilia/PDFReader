import SwiftUI

// MARK: - Spacing

enum Spacing {
    static let xs: CGFloat   = 4
    static let sm: CGFloat   = 8
    static let md: CGFloat   = 12
    static let lg: CGFloat   = 16
    static let xl: CGFloat   = 24
    static let xxl: CGFloat  = 32
}

// MARK: - Corner radius

enum Radius {
    static let sm: CGFloat  = 8
    static let md: CGFloat  = 12
    static let lg: CGFloat  = 16
    static let xl: CGFloat  = 20
    static let xxl: CGFloat = 24
}

// MARK: - Animation

enum AppAnimation {
    static let snappy   = Animation.spring(response: 0.3, dampingFraction: 0.7)
    static let smooth   = Animation.easeInOut(duration: 0.2)
    static let bouncy   = Animation.spring(response: 0.4, dampingFraction: 0.6)
}

// MARK: - Color palette

extension Color {

    // Semantic
    static let readerAccent  = Color.blue
    static let pdfBackground = Color(UIColor.systemBackground)
    static let sepiaPaper    = Color(red: 0.98, green: 0.97, blue: 0.94)

    // Surface hierarchy — auto dark mode
    static let surfacePrimary   = Color(UIColor.systemBackground)
    static let surfaceSecondary = Color(UIColor.secondarySystemBackground)
    static let surfaceTertiary  = Color(UIColor.tertiarySystemBackground)
    static let borderSubtle     = Color(UIColor.separator).opacity(0.6)

    // Cover palette — uses UIColor so dark mode adapts automatically
    static let coverPalette: [(bg: Color, accent: Color)] = [
        (Color(UIColor { t in t.userInterfaceStyle == .dark
            ? UIColor(red: 0.13, green: 0.20, blue: 0.32, alpha: 1)
            : UIColor(red: 0.87, green: 0.93, blue: 0.99, alpha: 1) }),
         Color.blue),

        (Color(UIColor { t in t.userInterfaceStyle == .dark
            ? UIColor(red: 0.18, green: 0.13, blue: 0.32, alpha: 1)
            : UIColor(red: 0.92, green: 0.90, blue: 0.99, alpha: 1) }),
         Color.purple),

        (Color(UIColor { t in t.userInterfaceStyle == .dark
            ? UIColor(red: 0.10, green: 0.22, blue: 0.20, alpha: 1)
            : UIColor(red: 0.86, green: 0.96, blue: 0.93, alpha: 1) }),
         Color.teal),

        (Color(UIColor { t in t.userInterfaceStyle == .dark
            ? UIColor(red: 0.26, green: 0.20, blue: 0.10, alpha: 1)
            : UIColor(red: 0.99, green: 0.94, blue: 0.86, alpha: 1) }),
         Color.orange),

        (Color(UIColor { t in t.userInterfaceStyle == .dark
            ? UIColor(red: 0.28, green: 0.13, blue: 0.13, alpha: 1)
            : UIColor(red: 0.99, green: 0.91, blue: 0.90, alpha: 1) }),
         Color.red),
    ]

    static func highlight(_ color: HighlightColor, opacity: Double = 0.35) -> Color {
        Color(color.uiColor).opacity(opacity)
    }
}

// MARK: - Typography

extension Font {
    static let bookTitle  = Font.custom("Georgia", size: 18).weight(.medium)
    static let readerBody = Font.system(size: 16, design: .serif)
}

// MARK: - Date formatting (shared instances — never recreate per render)

enum AppFormatters {
    static let relativeDate: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()
}

extension Date {
    var relativeDescription: String {
        AppFormatters.relativeDate.localizedString(for: self, relativeTo: .now)
    }
}
