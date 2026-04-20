import SwiftData
import Foundation

/// Handles all persistence for Document objects:
/// - PDF file management on disk
/// - SwiftData CRUD operations
///
/// Use this from ViewModels; never call ModelContext directly from Views.
struct DocumentRepository {

    // MARK: - File system

    /// The directory where all PDF files are stored.
    static var pdfDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("PDFs", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// Copies a PDF from a source URL (e.g. document picker result) into the
    /// app's PDF directory with a stable UUID filename. Returns the new Document.
    @discardableResult
    static func importPDF(from sourceURL: URL, context: ModelContext) throws -> Document {
        let fileName = UUID().uuidString + ".pdf"
        let destination = pdfDirectory.appendingPathComponent(fileName)

        // Security-scoped resource for files from document picker
        let accessing = sourceURL.startAccessingSecurityScopedResource()
        defer { if accessing { sourceURL.stopAccessingSecurityScopedResource() } }

        try FileManager.default.copyItem(at: sourceURL, to: destination)

        let attrs = try? FileManager.default.attributesOfItem(atPath: destination.path)
        let fileSize = (attrs?[.size] as? Int64) ?? 0

        // Derive a friendly title from the filename
        let title = sourceURL.deletingPathExtension().lastPathComponent

        let doc = Document(
            title: title,
            fileName: fileName,
            fileSize: fileSize
        )
        context.insert(doc)
        try context.save()
        return doc
    }

    /// Permanently deletes a document and its PDF file from disk.
    static func delete(_ document: Document, context: ModelContext) throws {
        let url = document.fileURL
        context.delete(document)
        try context.save()
        try? FileManager.default.removeItem(at: url)
    }

    /// Renames a document's display title.
    static func rename(_ document: Document, to newTitle: String, context: ModelContext) throws {
        document.title = newTitle
        try context.save()
    }

    /// Updates the last-opened date and current page when a document is opened.
    static func recordOpen(_ document: Document, context: ModelContext) throws {
        document.lastOpenedAt = .now
        try context.save()
    }
}
