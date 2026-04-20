import SwiftUI
import PDFKit

/// A single search result pointing to a page and selection.
struct SearchResult: Identifiable {
    let id = UUID()
    let pageIndex: Int
    let pageLabel: String
    let contextSnippet: String
    let selection: PDFSelection
}

@Observable
final class SearchViewModel {

    // MARK: - State

    var query: String = ""
    var results: [SearchResult] = []
    var isSearching: Bool = false
    var hasSearched: Bool = false

    private var searchTask: Task<Void, Never>?
    private weak var pdfDocument: PDFDocument?

    // MARK: - Setup

    func configure(with pdfDocument: PDFDocument) {
        self.pdfDocument = pdfDocument
    }

    // MARK: - Search

    /// Debounced search — waits 300ms after the last keystroke before firing.
    func onQueryChanged() {
        searchTask?.cancel()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            results = []
            hasSearched = false
            isSearching = false
            return
        }

        isSearching = true

        searchTask = Task {
            // Debounce
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }

            let found = await performSearch(query: trimmed)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                self.results = found
                self.isSearching = false
                self.hasSearched = true
            }
        }
    }

    func clearSearch() {
        searchTask?.cancel()
        query = ""
        results = []
        hasSearched = false
        isSearching = false
    }

    // MARK: - Private

    /// Runs the PDFKit search on a background thread.
    private func performSearch(query: String) async -> [SearchResult] {
        guard let pdfDocument else { return [] }

        return await Task.detached(priority: .userInitiated) {
            var found: [SearchResult] = []

            // PDFDocument.findString returns all matches across all pages
            let selections = pdfDocument.findString(
                query,
                withOptions: [.caseInsensitive, .diacriticInsensitive]
            )

            for selection in selections {
                guard let page = selection.pages.first else { continue }
                guard let pageIndex = pdfDocument.index(for: page) as Int? else { continue }

                let pageLabel = "Page \(pageIndex + 1)"
                let snippet = Self.buildSnippet(for: selection, on: page)

                found.append(SearchResult(
                    pageIndex: pageIndex,
                    pageLabel: pageLabel,
                    contextSnippet: snippet,
                    selection: selection
                ))

                // Cap at 200 results for performance
                if found.count >= 200 { break }
            }

            return found
        }.value
    }

    /// Extracts surrounding text to give the result context.
    private nonisolated static func buildSnippet(for selection: PDFSelection, on page: PDFPage) -> String {
        // Extend the selection by ~60 characters on each side for context
        let extended = selection.copy() as! PDFSelection
        extended.extend(atStart: 60)
        extended.extend(atEnd: 60)

        let raw = extended.string ?? selection.string ?? ""
        // Collapse whitespace and newlines into single spaces
        let cleaned = raw
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return cleaned.isEmpty ? page.label ?? "" : cleaned
    }
}
