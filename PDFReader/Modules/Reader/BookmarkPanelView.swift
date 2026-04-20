import SwiftUI
import SwiftData

struct BookmarkPanelView: View {

    let document: Document
    let currentPageIndex: Int
    let onNavigate: (Int) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var bookmarkViewModel = BookmarkViewModel()
    @State private var renamingBookmark: Bookmark? = nil
    @State private var renameText: String = ""

    var body: some View {
        NavigationStack {
            Group {
                if bookmarkViewModel.sortedBookmarks(in: document).isEmpty {
                    emptyState
                } else {
                    bookmarkList
                }
            }
            .navigationTitle("Bookmarks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        bookmarkViewModel.toggleBookmark(
                            for: document,
                            pageIndex: currentPageIndex,
                            context: context
                        )
                    } label: {
                        let isBookmarked = bookmarkViewModel.isPageBookmarked(
                            currentPageIndex,
                            in: document
                        )
                        Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                            .foregroundStyle(isBookmarked ? .blue : .primary)
                    }
                }
            }
        }
        // Add bookmark name sheet
        .sheet(isPresented: $bookmarkViewModel.isAddingBookmark) {
            addBookmarkSheet
        }
        // Rename sheet
        .sheet(item: $renamingBookmark) { bookmark in
            renameSheet(for: bookmark)
        }
        .alert("Error", isPresented: Binding(
            get: { bookmarkViewModel.errorMessage != nil },
            set: { if !$0 { bookmarkViewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(bookmarkViewModel.errorMessage ?? "")
        }
    }

    // MARK: - Bookmark list

    private var bookmarkList: some View {
        List {
            ForEach(bookmarkViewModel.sortedBookmarks(in: document)) { bookmark in
                BookmarkRow(
                    bookmark: bookmark,
                    isCurrentPage: bookmark.pageIndex == currentPageIndex
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    onNavigate(bookmark.pageIndex)
                    dismiss()
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        bookmarkViewModel.deleteBookmark(bookmark, context: context)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    Button {
                        renamingBookmark = bookmark
                        renameText = bookmark.name
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bookmark")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)

            Text("No bookmarks yet")
                .font(.title3)
                .fontWeight(.medium)

            Text("Tap the bookmark icon to save your current page.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                bookmarkViewModel.toggleBookmark(
                    for: document,
                    pageIndex: currentPageIndex,
                    context: context
                )
            } label: {
                Label("Bookmark page \(currentPageIndex + 1)", systemImage: "bookmark")
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Add bookmark sheet

    private var addBookmarkSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {

                // Page info card
                HStack(spacing: 14) {
                    Image(systemName: "doc.text")
                        .font(.title2)
                        .foregroundStyle(.blue)
                        .frame(width: 44, height: 44)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(document.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        Text("Page \(bookmarkViewModel.currentPageForAdding)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                // Name field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Bookmark name")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.4)
                        .padding(.horizontal, 20)

                    TextField("Enter a name", text: $bookmarkViewModel.newBookmarkName)
                        .font(.body)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal, 20)
                        .onSubmit {
                            bookmarkViewModel.confirmAddBookmark(
                                to: document,
                                pageIndex: currentPageIndex,
                                context: context
                            )
                        }
                }

                Spacer()
            }
            .navigationTitle("Add Bookmark")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        bookmarkViewModel.isAddingBookmark = false
                    }
                    .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        bookmarkViewModel.confirmAddBookmark(
                            to: document,
                            pageIndex: currentPageIndex,
                            context: context
                        )
                    }
                    .fontWeight(.medium)
                    .disabled(
                        bookmarkViewModel.newBookmarkName
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                            .isEmpty
                    )
                }
            }
        }
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Rename sheet

    private func renameSheet(for bookmark: Bookmark) -> some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                TextField("Bookmark name", text: $renameText)
                    .font(.body)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .onSubmit {
                        bookmarkViewModel.renameBookmark(bookmark, to: renameText, context: context)
                        renamingBookmark = nil
                    }

                Spacer()
            }
            .navigationTitle("Rename Bookmark")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { renamingBookmark = nil }
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        bookmarkViewModel.renameBookmark(bookmark, to: renameText, context: context)
                        renamingBookmark = nil
                    }
                    .fontWeight(.medium)
                    .disabled(
                        renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
            }
        }
        .presentationDetents([.height(200)])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - BookmarkRow

private struct BookmarkRow: View {

    let bookmark: Bookmark
    let isCurrentPage: Bool

    var body: some View {
        HStack(spacing: 14) {

            // Bookmark icon with color indicating current page
            Image(systemName: "bookmark.fill")
                .font(.system(size: 16))
                .foregroundStyle(isCurrentPage ? .blue : .secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(bookmark.name)
                    .font(.body)
                    .fontWeight(isCurrentPage ? .medium : .regular)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text("Page \(bookmark.pageIndex + 1)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Current page indicator
            if isCurrentPage {
                Text("Current")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Capsule())
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}
