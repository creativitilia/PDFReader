import SwiftUI

struct SelectionMenuView: View {

    let selectedText: String
    let onColorSelected: (HighlightColor) -> Void
    let onDefine: (() -> Void)?
    let onDismiss: () -> Void

    /// Cleans the selected text the same way DictionaryService does.
    private var cleanedWord: String {
        selectedText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespaces)
            .joined()
            // Remove all Unicode whitespace variants including non-breaking space \u{00A0}
            .components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.init(charactersIn: "\u{00A0}\u{202F}\u{2009}\u{200B}")))
            .joined()
    }

    /// True when the selection is a single word (no whitespace of any kind).
    private var isSingleWord: Bool {
        guard !cleanedWord.isEmpty else { return false }
        // Check original trimmed text for any whitespace
        let trimmed = selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasSpace = trimmed.unicodeScalars.contains {
            CharacterSet.whitespaces.contains($0) ||
            CharacterSet.newlines.contains($0) ||
            $0 == "\u{00A0}" || // non-breaking space
            $0 == "\u{202F}" || // narrow no-break space
            $0 == "\u{2009}" || // thin space
            $0 == "\u{200B}"    // zero-width space
        }
        return !hasSpace
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(HighlightColor.allCases, id: \.self) { color in
                Button {
                    onColorSelected(color)
                } label: {
                    Circle()
                        .fill(color.color)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 9)
                .padding(.vertical, 10)
            }

            if isSingleWord, let onDefine {
                Divider()
                    .frame(height: 24)
                    .padding(.horizontal, 2)

                Button(action: onDefine) {
                    HStack(spacing: 4) {
                        Image(systemName: "text.book.closed")
                            .font(.system(size: 13))
                        Text("Define")
                            .font(.subheadline)
                    }
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
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

// MARK: - HighlightEditMenuView

struct HighlightEditMenuView: View {

    let highlight: Highlight
    let onColorSelected: (HighlightColor) -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(HighlightColor.allCases, id: \.self) { color in
                    Button {
                        onColorSelected(color)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(color.color)
                                .frame(width: 24, height: 24)
                            if highlight.color == color {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .overlay(
                            Circle()
                                .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
            }

            Divider()

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
