import SwiftUI

/// Grid card shown in the library 2-column layout.
struct DocumentCard: View {

    let document: Document

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Cover area
            coverView
                .frame(height: 120)
                .clipped()

            // Metadata
            VStack(alignment: .leading, spacing: 3) {
                Text(document.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                Text(subtitleText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color(.separator), lineWidth: 0.5)
        )
    }

    // MARK: - Cover

    private var coverView: some View {
        ZStack(alignment: .topTrailing) {
            // Placeholder cover with accent color derived from title
            coverColor
                .overlay(coverLines)

            // Page count badge
            if document.totalPages > 0 {
                Text("\(document.totalPages) pp")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .padding(6)
            }
        }
    }

    /// Decorative line art that simulates a page of text.
    private var coverLines: some View {
        VStack(alignment: .leading, spacing: 5) {
            RoundedRectangle(cornerRadius: 2)
                .frame(width: coverLineWidth(fraction: 0.75), height: 7)
                .opacity(0.45)
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .frame(width: coverLineWidth(fraction: lineFractions[i % lineFractions.count]), height: 4)
                    .opacity(0.35)
            }
        }
        .foregroundStyle(coverAccentColor)
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
    }

    // Fixed fractions so lines look natural without randomness (deterministic per card)
    private let lineFractions: [Double] = [0.9, 0.6, 0.85, 0.5]

    private func coverLineWidth(fraction: Double) -> CGFloat {
        // Approximation — actual width depends on card width at runtime
        CGFloat(fraction * 110)
    }

    // MARK: - Color helpers

    private var coverColor: Color {
        // Pick a consistent color from the title's hash
        let colors: [Color] = [
            Color(red: 0.90, green: 0.94, blue: 0.98),   // blue-50
            Color(red: 0.93, green: 0.93, blue: 0.99),   // purple-50
            Color(red: 0.88, green: 0.96, blue: 0.93),   // teal-50
            Color(red: 0.98, green: 0.93, blue: 0.85),   // amber-50
            Color(red: 0.98, green: 0.92, blue: 0.91),   // coral-50
        ]
        let index = abs(document.title.hashValue) % colors.count
        return colors[index]
    }

    private var coverAccentColor: Color {
        let colors: [Color] = [.blue, .purple, .teal, .orange, .red]
        let index = abs(document.title.hashValue) % colors.count
        return colors[index]
    }

    // MARK: - Subtitle

    private var subtitleText: String {
        if let opened = document.lastOpenedAt {
            return "Opened \(opened.relativeDescription)"
        }
        return "Added \(document.importedAt.relativeDescription)"
    }
}

// MARK: - DocumentListRow

/// Compact row used in list layout mode.
struct DocumentListRow: View {

    let document: Document

    var body: some View {
        HStack(spacing: 12) {
            // Small thumbnail placeholder
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(.secondarySystemBackground))
                .frame(width: 44, height: 56)
                .overlay(
                    Image(systemName: "doc.text.fill")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(document.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(2)

                Text(document.totalPages > 0 ? "\(document.totalPages) pages" : "Unknown length")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let opened = document.lastOpenedAt {
                    Text("Opened \(opened.relativeDescription)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Date helper

private extension Date {
    var relativeDescription: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: .now)
    }
}
