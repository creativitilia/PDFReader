import SwiftUI

struct DocumentCard: View {

    let document: Document
    @State private var isPressed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            coverView
                .frame(height: 130)
                .clipped()

            infoView
        }
        .background(Color.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md)
                .strokeBorder(Color.borderSubtle, lineWidth: 0.5)
        )
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(AppAnimation.snappy, value: isPressed)
        .onLongPressGesture(
            minimumDuration: 0.01,
            pressing: { pressing in isPressed = pressing },
            perform: {}
        )
    }

    // MARK: - Cover

    private var coverView: some View {
        let palette = Color.coverPalette[abs(document.title.hashValue) % Color.coverPalette.count]

        return GeometryReader { geo in
            ZStack(alignment: .topTrailing) {
                palette.bg

                // Decorative lines
                VStack(alignment: .leading, spacing: 5) {
                    RoundedRectangle(cornerRadius: 2)
                        .frame(width: geo.size.width * 0.68, height: 7)
                        .opacity(0.5)
                    ForEach(Array(lineFractions.enumerated()), id: \.offset) { _, f in
                        RoundedRectangle(cornerRadius: 2)
                            .frame(width: geo.size.width * f, height: 4)
                            .opacity(0.35)
                    }
                }
                .foregroundStyle(palette.accent)
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

                // Page count badge
                if document.totalPages > 0 {
                    Text("\(document.totalPages) pp")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .padding(8)
                }
            }
        }
    }

    private let lineFractions: [Double] = [0.85, 0.55, 0.78, 0.45]

    // MARK: - Info

    private var infoView: some View {
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
        .padding(.horizontal, Spacing.sm + 2)
        .padding(.vertical, Spacing.sm)
    }

    private var subtitleText: String {
        if let opened = document.lastOpenedAt {
            return "Opened \(opened.relativeDescription)"
        }
        return "Added \(document.importedAt.relativeDescription)"
    }
}

// MARK: - DocumentListRow

struct DocumentListRow: View {

    let document: Document

    var body: some View {
        HStack(spacing: Spacing.md) {
            listThumbnail
            infoStack
            Spacer()
            progressIndicator
        }
        .padding(.vertical, Spacing.xs)
    }

    private var listThumbnail: some View {
        let palette = Color.coverPalette[abs(document.title.hashValue) % Color.coverPalette.count]
        return RoundedRectangle(cornerRadius: Radius.sm)
            .fill(palette.bg)
            .frame(width: 44, height: 56)
            .overlay(
                Image(systemName: "doc.text.fill")
                    .foregroundStyle(palette.accent.opacity(0.7))
                    .font(.title3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.sm)
                    .strokeBorder(Color.borderSubtle, lineWidth: 0.5)
            )
    }

    private var infoStack: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(document.title)
                .font(.body)
                .fontWeight(.medium)
                .lineLimit(2)

            Text(document.totalPages > 0 ? "\(document.totalPages) pages" : "—")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let opened = document.lastOpenedAt {
                Text("Opened \(opened.relativeDescription)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var progressIndicator: some View {
        Group {
            if document.totalPages > 0 && document.currentPage > 0 {
                VStack(spacing: 3) {
                    CircularProgress(fraction: document.progressFraction)
                        .frame(width: 28, height: 28)
                    Text("\(Int(document.progressFraction * 100))%")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
    }
}

// MARK: - CircularProgress

private struct CircularProgress: View {
    let fraction: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: 3)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(Color.readerAccent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}
