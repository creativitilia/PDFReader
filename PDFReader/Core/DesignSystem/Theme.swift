import SwiftUI

// MARK: - App Colors

extension Color {

    /// Semantic accent color for reading-related UI.
    static let readerAccent = Color.blue

    /// Background for the PDF reading surface.
    static let pdfBackground = Color(UIColor.systemBackground)

    /// Sepia reading mode background.
    static let sepiaPaper = Color(red: 0.98, green: 0.97, blue: 0.94)

    /// Converts a HighlightColor to a SwiftUI Color at the given opacity.
    static func highlight(_ color: HighlightColor, opacity: Double = 0.35) -> Color {
        Color(color.uiColor).opacity(opacity)
    }
}

// MARK: - App Typography

extension Font {

    /// Large serif title used in book cover simulations.
    static let bookTitle = Font.custom("Georgia", size: 18).weight(.medium)

    /// Body text in the PDF reader overlay.
    static let readerBody = Font.system(size: 16, design: .serif)
}
