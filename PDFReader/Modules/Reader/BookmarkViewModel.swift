import SwiftUI
import SwiftData

@Observable
final class BookmarkViewModel {

    // MARK: - State

    var isAddingBookmark: Bool = false
    var newBookmarkName: String = ""
    var errorMessage: String? = nil
    var pendingPageIndex: Int = 0

    var currentPageForAdding: Int {
        pendingPageIndex + 1
    }

    // MARK: - Derived

    func isPageBookmarked(_ pageIndex: Int, in document: Document) -> Bool {
        BookmarkRepository.bookmarkExists(for: document, pageIndex: pageIndex)
    }

    func sortedBookmarks(in document: Document) -> [Bookmark] {
        document.bookmarks.sorted { $0.pageIndex < $1.pageIndex }
    }

    // MARK: - Actions

    /// Prepares the add-bookmark flow with a default name.
    func beginAddBookmark(pageIndex: Int) {
        pendingPageIndex = pageIndex
        newBookmarkName = "Page \(pageIndex + 1)"
        isAddingBookmark = true
    }

    func confirmAddBookmark(
        to document: Document,
        pageIndex: Int,
        context: ModelContext
    ) {
        let name = newBookmarkName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        do {
            _ = try BookmarkRepository.add(
                to: document,
                name: name,
                pageIndex: pageIndex,
                context: context
            )
        } catch {
            errorMessage = "Could not save bookmark."
        }
        isAddingBookmark = false
        newBookmarkName = ""
    }

    func toggleBookmark(
        for document: Document,
        pageIndex: Int,
        context: ModelContext
    ) {
        if BookmarkRepository.bookmarkExists(for: document, pageIndex: pageIndex) {
            // Remove it immediately — no confirmation needed
            do {
                try BookmarkRepository.removeIfExists(
                    for: document,
                    pageIndex: pageIndex,
                    context: context
                )
            } catch {
                errorMessage = "Could not remove bookmark."
            }
        } else {
            beginAddBookmark(pageIndex: pageIndex)
        }
    }

    func deleteBookmark(_ bookmark: Bookmark, context: ModelContext) {
        do {
            try BookmarkRepository.delete(bookmark, context: context)
        } catch {
            errorMessage = "Could not delete bookmark."
        }
    }

    func renameBookmark(_ bookmark: Bookmark, to name: String, context: ModelContext) {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        do {
            try BookmarkRepository.rename(bookmark, to: name, context: context)
        } catch {
            errorMessage = "Could not rename bookmark."
        }
    }
}
