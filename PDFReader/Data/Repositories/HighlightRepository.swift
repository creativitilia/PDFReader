import SwiftData
import Foundation

/// Handles persistence for Highlight and Note objects.
/// Full implementation comes in the Reader module milestone.
struct HighlightRepository {

    static func add(
        to document: Document,
        pageIndex: Int,
        boundingBoxes: [CGRect],
        color: HighlightColor,
        selectedText: String,
        context: ModelContext
    ) throws -> Highlight {
        let highlight = Highlight(
            documentID: document.id,
            pageIndex: pageIndex,
            boundingBoxes: boundingBoxes,
            color: color,
            selectedText: selectedText
        )
        context.insert(highlight)
        document.highlights.append(highlight)
        try context.save()
        return highlight
    }

    static func delete(_ highlight: Highlight, context: ModelContext) throws {
        context.delete(highlight)
        try context.save()
    }

    static func attachNote(to highlight: Highlight, body: String, context: ModelContext) throws {
        if let existing = highlight.note {
            existing.body = body
            existing.updatedAt = .now
        } else {
            let note = Note(body: body)
            context.insert(note)
            highlight.note = note
        }
        highlight.updatedAt = .now
        try context.save()
    }
}
