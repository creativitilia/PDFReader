import SwiftUI
import PDFKit
import SwiftData

@Observable
final class ReaderViewModel {

    var currentPageIndex: Int = 0
    var totalPages: Int = 0
    var isChromeVisible: Bool = true
    var isSearchPresented: Bool = false

    private var hideTask: Task<Void, Never>?

    init(document: Document) {
        self.currentPageIndex = document.currentPage
    }

    func loadPDFDocument(from document: Document) -> PDFDocument? {
        let url = document.fileURL
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let pdf = PDFDocument(url: url)
        totalPages = pdf?.pageCount ?? 0
        return pdf
    }

    func goToPage(_ index: Int) {
        currentPageIndex = max(0, min(index, totalPages - 1))
    }

    func goToPreviousPage() { goToPage(currentPageIndex - 1) }
    func goToNextPage()     { goToPage(currentPageIndex + 1) }

    func toggleChrome() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isChromeVisible.toggle()
        }
        if isChromeVisible { scheduleHide() }
    }

    func showChromeTemporarily() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isChromeVisible = true
        }
        scheduleHide()
    }

    private func scheduleHide() {
        hideTask?.cancel()
        hideTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                self.isChromeVisible = false
            }
        }
    }

    func cancelHideTimer() {
        hideTask?.cancel()
    }

    /// Navigates to a search result and highlights the match on the PDFView.
    func navigate(to result: SearchResult, in pdfView: PDFView?) {
        guard let pdfView else { return }
        goToPage(result.pageIndex)
        // Set the selection so PDFKit highlights it in its native blue
        pdfView.setCurrentSelection(result.selection, animate: true)
        // Scroll so the match is visible
        pdfView.go(to: result.selection)
        // Show chrome so the user sees the context
        showChromeTemporarily()
    }

    func saveProgress(for document: Document, context: ModelContext) {
        document.currentPage = currentPageIndex
        document.lastOpenedAt = .now
        try? context.save()
    }
}
