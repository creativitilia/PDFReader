import SwiftUI
import PDFKit
import SwiftData

struct ReaderView: View {

    let document: Document

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var viewModel: ReaderViewModel
    @State private var pdfDocument: PDFDocument?
    @State private var showErrorAlert = false

    init(document: Document) {
        self.document = document
        _viewModel = State(initialValue: ReaderViewModel(document: document))
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()

            if let pdf = pdfDocument {
                pdfLayer(pdf: pdf)
            } else {
                loadingView
            }

            if viewModel.isChromeVisible {
                chromeOverlay
            }
        }
        .navigationBarHidden(true)
        .ignoresSafeArea(edges: .bottom)
        .statusBarHidden(!viewModel.isChromeVisible)
        .onAppear {
            loadDocument()
            viewModel.showChromeTemporarily()
        }
        .onDisappear {
            viewModel.cancelHideTimer()
            viewModel.saveProgress(for: document, context: context)
        }
        .alert("Could not open PDF", isPresented: $showErrorAlert) {
            Button("Go back") { dismiss() }
        } message: {
            Text("The file may have been moved or deleted.")
        }
    }

    // MARK: - PDF layer

    private func pdfLayer(pdf: PDFDocument) -> some View {
        PDFKitView(
            document: pdf,
            currentPageIndex: viewModel.currentPageIndex,
            onPageChanged: { index in
                viewModel.currentPageIndex = index
            }
        )
        .ignoresSafeArea()
        .onTapGesture {
            viewModel.toggleChrome()
        }
    }

    // MARK: - Chrome overlay

    private var chromeOverlay: some View {
        VStack(spacing: 0) {
            ReaderTopBar(
                title: document.title,
                onBack: {
                    viewModel.saveProgress(for: document, context: context)
                    dismiss()
                },
                onSearchTap: {
                    viewModel.isSearchPresented = true
                },
                onMoreTap: {}
            )
            .transition(.move(edge: .top).combined(with: .opacity))

            Spacer()

            ReaderBottomBar(
                currentPage: viewModel.currentPageIndex + 1,
                totalPages: max(viewModel.totalPages, 1),
                progress: progressFraction,
                onPrevious: { viewModel.goToPreviousPage() },
                onNext:     { viewModel.goToNextPage() },
                onScrub: { fraction in
                    let target = Int(fraction * Double(max(viewModel.totalPages - 1, 0)))
                    viewModel.goToPage(target)
                }
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.isChromeVisible)
    }

    // MARK: - Loading view

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.4)
            Text("Opening document…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private var progressFraction: Double {
        guard viewModel.totalPages > 1 else { return 0 }
        return Double(viewModel.currentPageIndex) / Double(viewModel.totalPages - 1)
    }

    private func loadDocument() {
        let url = document.fileURL
        Task.detached(priority: .userInitiated) {
            guard FileManager.default.fileExists(atPath: url.path) else {
                await MainActor.run { showErrorAlert = true }
                return
            }
            let loaded = PDFDocument(url: url)
            await MainActor.run {
                if let loaded {
                    self.pdfDocument = loaded
                    self.viewModel.totalPages = loaded.pageCount
                } else {
                    self.showErrorAlert = true
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ReaderView(document: MockData.sampleDocument)
    }
    .modelContainer(MockData.previewContainer)
}
