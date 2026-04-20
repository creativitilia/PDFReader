import SwiftData
import Foundation

/// Represents an imported PDF file in the user's library.
@Model
final class Document {

    // MARK: - Stored properties

    var id: UUID
    /// The display name shown in the library (user-editable).
    var title: String
    /// Stable UUID-based filename on disk, e.g. "550e8400-e29b.pdf".
    var fileName: String
    var importedAt: Date
    var lastOpenedAt: Date?
    /// Zero-based index of the page the user last read.
    var currentPage: Int
    var totalPages: Int
    var fileSize: Int64

    // MARK: - Relationships

    @Relationship(deleteRule: .cascade) var highlights: [Highlight]
    @Relationship(deleteRule: .cascade) var bookmarks: [Bookmark]

    // MARK: - Init

    init(
        id: UUID = UUID(),
        title: String,
        fileName: String,
        importedAt: Date = .now,
        lastOpenedAt: Date? = nil,
        currentPage: Int = 0,
        totalPages: Int = 0,
        fileSize: Int64 = 0
    ) {
        self.id = id
        self.title = title
        self.fileName = fileName
        self.importedAt = importedAt
        self.lastOpenedAt = lastOpenedAt
        self.currentPage = currentPage
        self.totalPages = totalPages
        self.fileSize = fileSize
        self.highlights = []
        self.bookmarks = []
    }

    // MARK: - Computed helpers

    /// The URL of the PDF file on disk.
    var fileURL: URL {
        DocumentRepository.pdfDirectory.appendingPathComponent(fileName)
    }

    /// Human-readable reading progress string, e.g. "22 / 312".
    var progressDescription: String {
        guard totalPages > 0 else { return "—" }
        return "\(currentPage + 1) / \(totalPages)"
    }

    /// Reading progress as a 0–1 fraction.
    var progressFraction: Double {
        guard totalPages > 1 else { return 0 }
        return Double(currentPage) / Double(totalPages - 1)
    }
}


