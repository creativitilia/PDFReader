import SwiftData
import Foundation

struct BookmarkRepository {

    static func add(
        to document: Document,
        name: String,
        pageIndex: Int,
        context: ModelContext
    ) throws -> Bookmark {
        let bookmark = Bookmark(
            documentID: document.id,
            name: name,
            pageIndex: pageIndex
        )
        context.insert(bookmark)
        document.bookmarks.append(bookmark)
        try context.save()
        return bookmark
    }

    static func delete(_ bookmark: Bookmark, context: ModelContext) throws {
        context.delete(bookmark)
        try context.save()
    }

    static func rename(_ bookmark: Bookmark, to newName: String, context: ModelContext) throws {
        bookmark.name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        try context.save()
    }

    /// Returns true if a bookmark already exists on the given page.
    static func bookmarkExists(
        for document: Document,
        pageIndex: Int
    ) -> Bool {
        document.bookmarks.contains { $0.pageIndex == pageIndex }
    }

    /// Removes the bookmark on a given page if one exists.
    static func removeIfExists(
        for document: Document,
        pageIndex: Int,
        context: ModelContext
    ) throws {
        guard let existing = document.bookmarks.first(where: { $0.pageIndex == pageIndex })
        else { return }
        context.delete(existing)
        try context.save()
    }
}
