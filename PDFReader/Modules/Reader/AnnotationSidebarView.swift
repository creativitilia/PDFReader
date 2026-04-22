import SwiftUI
import SwiftData

struct AnnotationSidebarView: View {

    let document: Document
    let onNavigate: (Int) -> Void
    let onEditNote: (Highlight) -> Void
    let onDeleteHighlight: (Highlight) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: SidebarTab = .highlights

    enum SidebarTab {
        case highlights, notes
    }

    // Sorted highlights — most recent first
    private var sortedHighlights: [Highlight] {
        document.highlights.sorted { $0.pageIndex < $1.pageIndex }
    }

    // Only highlights that have a note
    private var highlightsWithNotes: [Highlight] {
        sortedHighlights.filter { $0.note != nil && !(($0.note?.body ?? "").isEmpty) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // Tab picker
                tabPicker

                Divider()

                // Content
                Group {
                    switch selectedTab {
                    case .highlights:
                        highlightsList
                    case .notes:
                        notesList
                    }
                }
            }
            .navigationTitle("Annotations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Tab picker

    private var tabPicker: some View {
        HStack(spacing: 0) {
            tabButton("Highlights", tab: .highlights, count: sortedHighlights.count)
            tabButton("Notes", tab: .notes, count: highlightsWithNotes.count)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.xs)
    }

    private func tabButton(_ label: String, tab: SidebarTab, count: Int) -> some View {
        Button {
            withAnimation(AppAnimation.smooth) { selectedTab = tab }
        } label: {
            VStack(spacing: 6) {
                HStack(spacing: 5) {
                    Text(label)
                        .font(.subheadline)
                        .fontWeight(selectedTab == tab ? .semibold : .regular)
                        .foregroundStyle(selectedTab == tab ? .primary : .secondary)

                    if count > 0 {
                        Text("\(count)")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(selectedTab == tab ? .blue : .secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(selectedTab == tab
                                    ? Color.blue.opacity(0.12)
                                    : Color.primary.opacity(0.07))
                            )
                    }
                }

                Rectangle()
                    .fill(selectedTab == tab ? Color.blue : Color.clear)
                    .frame(height: 2)
                    .clipShape(Capsule())
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Highlights list

    private var highlightsList: some View {
        Group {
            if sortedHighlights.isEmpty {
                emptyState(
                    icon: "highlighter",
                    title: "No highlights yet",
                    message: "Select text while reading and tap a color to highlight it."
                )
            } else {
                List {
                    ForEach(sortedHighlights) { highlight in
                        HighlightSidebarRow(
                            highlight: highlight,
                            onNavigate: {
                                onNavigate(highlight.pageIndex)
                                dismiss()
                            },
                            onEditNote: {
                                onEditNote(highlight)
                                dismiss()
                            }
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                onDeleteHighlight(highlight)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .listRowInsets(EdgeInsets(
                            top: Spacing.sm,
                            leading: Spacing.lg,
                            bottom: Spacing.sm,
                            trailing: Spacing.lg
                        ))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Notes list

    private var notesList: some View {
        Group {
            if highlightsWithNotes.isEmpty {
                emptyState(
                    icon: "note.text",
                    title: "No notes yet",
                    message: "Tap a highlight and choose \"Add note\" to attach a note."
                )
            } else {
                List {
                    ForEach(highlightsWithNotes) { highlight in
                        NoteSidebarRow(
                            highlight: highlight,
                            onTap: {
                                onEditNote(highlight)
                                dismiss()
                            }
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                onDeleteHighlight(highlight)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .listRowInsets(EdgeInsets(
                            top: Spacing.sm,
                            leading: Spacing.lg,
                            bottom: Spacing.sm,
                            trailing: Spacing.lg
                        ))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Empty state

    private func emptyState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(.quaternary)
                .padding(.bottom, Spacing.xs)

            Text(title)
                .font(.headline)
                .fontWeight(.semibold)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - HighlightSidebarRow

private struct HighlightSidebarRow: View {

    let highlight: Highlight
    let onNavigate: () -> Void
    let onEditNote: () -> Void

    var body: some View {
        Button(action: onNavigate) {
            HStack(alignment: .top, spacing: Spacing.md) {

                // Color accent bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(highlight.color.color)
                    .frame(width: 3)
                    .frame(minHeight: 40)

                VStack(alignment: .leading, spacing: 5) {
                    // Selected text
                    Text(highlight.selectedText.isEmpty ? "Highlighted text" : highlight.selectedText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    // Note preview (if exists)
                    if let note = highlight.note, !note.body.isEmpty {
                        Text(note.body)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .italic()
                            .lineLimit(1)
                    }

                    // Meta row
                    HStack(spacing: Spacing.sm) {
                        Text("Page \(highlight.pageIndex + 1)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if highlight.note == nil {
                            Text("·")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            Text("no note")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                Spacer()

                // Page badge
                Text("p.\(highlight.pageIndex + 1)")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .padding(.top, 2)
            }
            .padding(.vertical, Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - NoteSidebarRow

private struct NoteSidebarRow: View {

    let highlight: Highlight
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {

                // Note body
                if let note = highlight.note {
                    Text(note.body)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Quoted highlight beneath the note
                HStack(alignment: .top, spacing: 6) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(highlight.color.color.opacity(0.8))
                        .frame(width: 2)

                    Text(highlight.selectedText.isEmpty ? "Highlighted text" : highlight.selectedText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .italic()
                }

                Text("Page \(highlight.pageIndex + 1)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(Spacing.md)
            .background(Color.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md)
                    .strokeBorder(Color.borderSubtle, lineWidth: 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
