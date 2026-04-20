import SwiftUI

/// Compact popup shown when tapping an existing highlight.
/// Shows the note if one exists, plus actions.
struct NotePopupView: View {

    let highlight: Highlight
    let onEditNote: () -> Void
    let onChangeColor: (HighlightColor) -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Note section
            if let note = highlight.note, !note.body.isEmpty {
                notePreview(note.body)
                Divider()
            }

            // Color picker row
            colorRow

            Divider()

            // Action buttons
            actionRow
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .frame(width: 260)
        .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 4)
    }

    // MARK: - Note preview

    private func notePreview(_ body: String) -> some View {
        Button(action: onEditNote) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "note.text")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .padding(.top, 1)

                Text(body)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Color row

    private var colorRow: some View {
        HStack(spacing: 0) {
            ForEach(HighlightColor.allCases, id: \.self) { color in
                Button {
                    onChangeColor(color)
                } label: {
                    ZStack {
                        Circle()
                            .fill(color.color)
                            .frame(width: 24, height: 24)

                        if highlight.color == color {
                            Circle()
                                .strokeBorder(Color.primary.opacity(0.5), lineWidth: 2)
                                .frame(width: 24, height: 24)
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Action row

    private var actionRow: some View {
        HStack(spacing: 0) {
            // Note action
            Button(action: onEditNote) {
                HStack(spacing: 5) {
                    Image(systemName: highlight.note == nil ? "plus" : "pencil")
                        .font(.system(size: 12))
                    Text(highlight.note == nil ? "Add note" : "Edit note")
                        .font(.subheadline)
                }
                .foregroundStyle(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)

            Divider()
                .frame(height: 36)

            // Delete action
            Button(action: onDelete) {
                HStack(spacing: 5) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                    Text("Delete")
                        .font(.subheadline)
                }
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
        }
    }
}
