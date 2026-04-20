import SwiftUI
import PDFKit
import SwiftData

@Observable
final class HighlightStore {

    var tappedHighlight: Highlight? = nil

    private var document: Document
    private weak var pdfDocument: PDFDocument?

    init(document: Document) {
        self.document = document
    }

    // MARK: - Loading

    func loadHighlights(into pdfDocument: PDFDocument) {
        self.pdfDocument = pdfDocument
        for highlight in document.highlights {
            render(highlight, in: pdfDocument)
        }
    }

    // MARK: - Creating

    func addHighlight(
        selection: PDFSelection,
        color: HighlightColor,
        context: ModelContext
    ) {
        guard let pdfDocument else { return }

        for page in selection.pages {
            guard let pageIndex = pdfDocument.index(for: page) as Int? else { continue }

            let bounds = selection.bounds(for: page)
            let selectedText = selection.string ?? ""

            let highlight = Highlight(
                documentID: document.id,
                pageIndex: pageIndex,
                boundingBoxes: [bounds],
                color: color,
                selectedText: selectedText
            )

            context.insert(highlight)
            document.highlights.append(highlight)
            render(highlight, in: pdfDocument)
        }

        try? context.save()
    }

    // MARK: - Updating color

    func updateColor(
        of highlight: Highlight,
        to newColor: HighlightColor,
        context: ModelContext
    ) {
        guard let pdfDocument else { return }
        removeAnnotation(for: highlight, in: pdfDocument)
        highlight.colorName = newColor.rawValue
        highlight.updatedAt = .now
        try? context.save()
        render(highlight, in: pdfDocument)
    }

    // MARK: - Notes

    func saveNote(for highlight: Highlight, text: String, context: ModelContext) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            // Empty text — delete the note if one exists
            deleteNote(from: highlight, context: context)
            return
        }

        if let existing = highlight.note {
            existing.body = trimmed
            existing.updatedAt = .now
        } else {
            let note = Note(body: trimmed)
            context.insert(note)
            highlight.note = note
        }

        highlight.updatedAt = .now
        try? context.save()
    }

    func deleteNote(from highlight: Highlight, context: ModelContext) {
        if let note = highlight.note {
            context.delete(note)
            highlight.note = nil
            highlight.updatedAt = .now
            try? context.save()
        }
    }

    // MARK: - Deleting highlight

    func deleteHighlight(_ highlight: Highlight, context: ModelContext) {
        guard let pdfDocument else { return }
        removeAnnotation(for: highlight, in: pdfDocument)
        context.delete(highlight)
        try? context.save()
        tappedHighlight = nil
    }

    // MARK: - Tap detection

    @discardableResult
    func handleTap(at point: CGPoint, on pdfView: PDFView) -> Bool {
        guard
            let page = pdfView.page(for: point, nearest: false),
            let pageIndex = pdfDocument?.index(for: page)
        else {
            tappedHighlight = nil
            return false
        }

        let pagePoint = pdfView.convert(point, to: page)

        let tapped = document.highlights.first { highlight in
            guard highlight.pageIndex == pageIndex else { return false }
            return highlight.boundingBoxes.contains { $0.contains(pagePoint) }
        }

        tappedHighlight = tapped
        return tapped != nil
    }

    // MARK: - Private rendering

    private func render(_ highlight: Highlight, in pdfDocument: PDFDocument) {
        guard let page = pdfDocument.page(at: highlight.pageIndex) else { return }
        for box in highlight.boundingBoxes {
            let annotation = PDFAnnotation(bounds: box, forType: .highlight, withProperties: nil)
            annotation.color = highlight.color.uiColor.withAlphaComponent(0.4)
            annotation.setValue(
                highlight.id.uuidString,
                forAnnotationKey: PDFAnnotationKey(rawValue: "highlightID")
            )
            // Add a note indicator dot if a note exists
            if highlight.note != nil {
                annotation.setValue(true, forAnnotationKey: PDFAnnotationKey(rawValue: "hasNote"))
            }
            page.addAnnotation(annotation)
        }
    }

    private func removeAnnotation(for highlight: Highlight, in pdfDocument: PDFDocument) {
        guard let page = pdfDocument.page(at: highlight.pageIndex) else { return }
        let idString = highlight.id.uuidString
        let toRemove = page.annotations.filter {
            $0.value(forAnnotationKey: PDFAnnotationKey(rawValue: "highlightID")) as? String == idString
        }
        toRemove.forEach { page.removeAnnotation($0) }
    }
}
