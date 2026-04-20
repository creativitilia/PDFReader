import SwiftUI

struct SelectionMenuView: View {

    let selectedText: String
    let onColorSelected: (HighlightColor) -> Void
    let onDefine: (() -> Void)?
    let onDismiss: () -> Void

    private var isSingleWord: Bool {
        let trimmed = selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let unicodeSpaces = CharacterSet(charactersIn: "\u{00A0}\u{202F}\u{2009}\u{200B}")
        let allSpaces = CharacterSet.whitespacesAndNewlines.union(unicodeSpaces)
        return !trimmed.unicodeScalars.contains { allSpaces.contains($0) }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Highlight color swatches
            ForEach(HighlightColor.allCases, id: \.self) { color in
                Button {
                    withAnimation(AppAnimation.snappy) { onColorSelected(color) }
                } label: {
                    Circle()
                        .fill(color.color)
                        .frame(width: 22, height: 22)
                        .overlay(
                            Circle().strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                        )
                        .padding(9)
                }
                .buttonStyle(.plain)
            }

            // Define — single words only
            if isSingleWord, let onDefine {
                Rectangle()
                    .fill(Color.primary.opacity(0.12))
                    .frame(width: 0.5, height: 22)

                Button(action: onDefine) {
                    HStack(spacing: 4) {
                        Image(systemName: "character.book.closed")
                            .font(.system(size: 12))
                        Text("Define")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.blue)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm + 1)
                }
                .buttonStyle(.plain)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                )
        )
        .shadow(color: .black.opacity(0.10), radius: 12, x: 0, y: 3)
    }
}
