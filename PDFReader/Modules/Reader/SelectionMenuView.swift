import SwiftUI

/// Floating menu shown above a PDF text selection.
/// Presents 5 color swatches, plus a dismiss tap target.
struct SelectionMenuView: View {

    let onColorSelected: (HighlightColor) -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(HighlightColor.allCases, id: \.self) { color in
                Button {
                    onColorSelected(color)
                } label: {
                    Circle()
                        .fill(color.color)
                        .frame(width: 26, height: 26)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
                )
        )
    }
}

/// Popover shown when user taps an existing highlight.
/// Allows changing color or deleting.
struct HighlightEditMenuView: View {

    let highlight: Highlight
    let onColorSelected: (HighlightColor) -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Color row
            HStack(spacing: 0) {
                ForEach(HighlightColor.allCases, id: \.self) { color in
                    Button {
                        onColorSelected(color)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(color.color)
                                .frame(width: 26, height: 26)
                            if highlight.color == color {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .overlay(
                            Circle()
                                .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                }
            }

            Divider()

            // Delete row
            Button(role: .destructive, action: onDelete) {
                HStack {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                    Text("Remove highlight")
                        .font(.subheadline)
                }
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
            }
            .buttonStyle(.plain)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
                )
        )
        .frame(width: 220)
    }
}
