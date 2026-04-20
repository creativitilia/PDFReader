import SwiftUI

/// Full sheet for writing or editing a note attached to a highlight.
struct NoteEditorView: View {

    let highlight: Highlight
    let onSave: (String) -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @FocusState private var isFocused: Bool

    init(highlight: Highlight, onSave: @escaping (String) -> Void, onDelete: @escaping () -> Void) {
        self.highlight = highlight
        self.onSave = onSave
        self.onDelete = onDelete
        _text = State(initialValue: highlight.note?.body ?? "")
    }

    private var hasChanges: Bool {
        text != (highlight.note?.body ?? "")
    }

    private var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {

                // Quoted highlight text
                quotedTextView

                Divider()

                // Note text editor
                ZStack(alignment: .topLeading) {
                    if isEmpty {
                        Text("Write a note…")
                            .foregroundStyle(.tertiary)
                            .font(.body)
                            .padding(.horizontal, 16)
                            .padding(.top, 14)
                            .allowsHitTesting(false)
                    }

                    TextEditor(text: $text)
                        .font(.body)
                        .focused($isFocused)
                        .padding(.horizontal, 12)
                        .padding(.top, 10)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color(UIColor.systemBackground))
            .navigationTitle("Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.secondary)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave(text.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    .fontWeight(.medium)
                    .disabled(!hasChanges && !isEmpty)
                }

                ToolbarItem(placement: .bottomBar) {
                    if highlight.note != nil {
                        Button(role: .destructive) {
                            onDelete()
                            dismiss()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "trash")
                                    .font(.system(size: 13))
                                Text("Delete note")
                                    .font(.subheadline)
                            }
                            .foregroundStyle(.red)
                        }
                    }
                }
            }
        }
        .onAppear {
            // Small delay so the sheet finishes animating before keyboard appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isFocused = true
            }
        }
    }

    // MARK: - Quoted text

    private var quotedTextView: some View {
        HStack(alignment: .top, spacing: 0) {
            // Colored left bar matching highlight color
            Rectangle()
                .fill(highlight.color.color)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 4) {
                Text("Highlighted text")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Text(highlight.selectedText.isEmpty ? "No text captured" : highlight.selectedText)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Spacer()
        }
        .background(Color(UIColor.secondarySystemBackground))
    }
}
