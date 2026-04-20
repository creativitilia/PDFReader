import SwiftData
import SwiftUI
import Foundation

/// Sort order for the library grid.
enum LibrarySortOrder: String, CaseIterable, Identifiable {
    case lastOpened = "Last opened"
    case title      = "Title"
    case dateAdded  = "Date added"

    var id: String { rawValue }
}

/// ViewModel for LibraryView.
/// Owns all state and business logic; the View is kept pure UI.
@Observable
final class LibraryViewModel {

    // MARK: - Published state

    var searchText: String = ""
    var sortOrder: LibrarySortOrder = .lastOpened
    var showImporter: Bool = false
    var isGridLayout: Bool = true
    var renamingDocument: Document? = nil
    var renameText: String = ""
    var errorMessage: String? = nil

    // MARK: - Helpers

    /// Returns documents filtered by search and sorted per sortOrder.
    func filteredAndSorted(_ documents: [Document]) -> [Document] {
        let filtered: [Document]
        if searchText.isEmpty {
            filtered = documents
        } else {
            filtered = documents.filter {
                $0.title.localizedCaseInsensitiveContains(searchText)
            }
        }

        return filtered.sorted { a, b in
            switch sortOrder {
            case .lastOpened:
                let dateA = a.lastOpenedAt ?? a.importedAt
                let dateB = b.lastOpenedAt ?? b.importedAt
                return dateA > dateB
            case .title:
                return a.title.localizedCompare(b.title) == .orderedAscending
            case .dateAdded:
                return a.importedAt > b.importedAt
            }
        }
    }

    // MARK: - Actions

    func beginRename(_ document: Document) {
        renamingDocument = document
        renameText = document.title
    }

    func commitRename(context: ModelContext) {
        guard let doc = renamingDocument, !renameText.trimmingCharacters(in: .whitespaces).isEmpty else {
            renamingDocument = nil
            return
        }
        do {
            try DocumentRepository.rename(doc, to: renameText.trimmingCharacters(in: .whitespaces), context: context)
        } catch {
            errorMessage = "Could not rename: \(error.localizedDescription)"
        }
        renamingDocument = nil
    }

    func deleteDocument(_ document: Document, context: ModelContext) {
        do {
            try DocumentRepository.delete(document, context: context)
        } catch {
            errorMessage = "Could not delete: \(error.localizedDescription)"
        }
    }

    func importPDF(from url: URL, context: ModelContext) {
        do {
            try DocumentRepository.importPDF(from: url, context: context)
        } catch {
            errorMessage = "Import failed: \(error.localizedDescription)"
        }
    }
}
