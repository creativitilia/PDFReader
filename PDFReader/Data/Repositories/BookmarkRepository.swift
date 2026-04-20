import SwiftData
import Foundation

/// Handles persistence for Bookmark objects.
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
        bookmark.name = newName
        try context.save()
    }
}
