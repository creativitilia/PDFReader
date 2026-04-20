import SwiftData
import Foundation
import CoreGraphics

enum MockData {

    static var previewContainer: ModelContainer = {
        let schema = Schema([Document.self, Highlight.self, Note.self, Bookmark.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        insertSampleDocuments(into: container.mainContext)
        return container
    }()

    static var sampleDocument: Document {
        let schema = Schema([Document.self, Highlight.self, Note.self, Bookmark.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        let doc = Document(
            title: "Sample PDF",
            fileName: "sample.pdf",
            totalPages: 50
        )
        container.mainContext.insert(doc)
        return doc
    }

    private static func insertSampleDocuments(into context: ModelContext) {
        let samples: [(title: String, pages: Int, daysAgo: Double)] = [
            ("Thinking, Fast and Slow", 312, 0.1),
            ("Deep Work", 214, 1.0),
            ("The Pragmatic Programmer", 580, 3.0),
            ("Atomic Habits", 428, 7.0),
            ("Zero to One", 195, 14.0),
            ("The Design of Everyday Things", 368, 30.0),
        ]

        for sample in samples {
            let doc = Document(
                title: sample.title,
                fileName: UUID().uuidString + ".pdf",
                importedAt: Date().addingTimeInterval(-sample.daysAgo * 86400 * 2),
                lastOpenedAt: Date().addingTimeInterval(-sample.daysAgo * 86400),
                currentPage: Int.random(in: 0..<max(1, sample.pages - 1)),
                totalPages: sample.pages,
                fileSize: Int64.random(in: 1_000_000...10_000_000)
            )

            let b1 = Bookmark(documentID: doc.id, name: "Chapter 1", pageIndex: 1)
            let b2 = Bookmark(documentID: doc.id, name: "Key insight", pageIndex: Int.random(in: 10..<50))
            context.insert(b1)
            context.insert(b2)
            doc.bookmarks.append(contentsOf: [b1, b2])

            let hl = Highlight(
                documentID: doc.id,
                pageIndex: 22,
                boundingBoxes: [CGRect(x: 50, y: 100, width: 300, height: 20)],
                color: .yellow,
                selectedText: "A sample highlighted passage from \(sample.title)."
            )
            let note = Note(body: "This connects to the main thesis in chapter 3.")
            context.insert(note)
            hl.note = note
            context.insert(hl)
            doc.highlights.append(hl)

            context.insert(doc)
        }

        try? context.save()
    }
}
