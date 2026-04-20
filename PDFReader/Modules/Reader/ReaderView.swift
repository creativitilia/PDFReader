import SwiftUI
import PDFKit
import SwiftData

struct ReaderView: View {

    let document: Document

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var viewModel: ReaderViewModel
    @State private var highlightStore: HighlightStore
    @State private var pdfDocument: PDFDocument?
    @State private var pdfView: PDFView?
    @State private var showErrorAlert = false

    // Selection state lives here — not in ViewModel
    @State private var currentSelection: PDFSelection? = nil
    @State private var menuPosition: CGPoint = CGPoint(x: 200, y: 200)

    init(document: Document) {
        self.document = document
        _viewModel = State(initialValue: ReaderViewModel(document: document))
        _highlightStore = State(initialValue: HighlightStore(document: document))
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()

            if let pdf = pdfDocument {
                pdfLayer(pdf: pdf)
            } else {
                loadingView
            }

            if viewModel.isChromeVisible {
                chromeOverlay
            }

            if currentSelection != nil {
                selectionMenu
            }

            if highlightStore.tappedHighlight != nil {
                highlightEditMenu
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
            },
            onSelectionChanged: { selection in
                handleSelectionChanged(selection)
                if selection != nil {
                    highlightStore.tappedHighlight = nil
                }
            },
            onTap: { point, pv in
                if pdfView == nil { pdfView = pv }
                let hitHighlight = highlightStore.handleTap(at: point, on: pv)
                if !hitHighlight {
                    if currentSelection == nil {
                        viewModel.toggleChrome()
                    }
                    clearSelection()
                }
            }
        )
        .ignoresSafeArea()
    }

    // MARK: - Selection menu

    private var selectionMenu: some View {
        SelectionMenuView(
            onColorSelected: { color in
                guard let selection = currentSelection else { return }
                highlightStore.addHighlight(
                    selection: selection,
                    color: color,
                    context: context
                )
                clearSelection()
            },
            onDismiss: {
                clearSelection()
            }
        )
        .position(x: menuPosition.x, y: menuPosition.y)
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
        .animation(.spring(duration: 0.2), value: currentSelection != nil)
        .zIndex(10)
    }

    // MARK: - Highlight edit menu

    private var highlightEditMenu: some View {
        Group {
            if let tapped = highlightStore.tappedHighlight {
                HighlightEditMenuView(
                    highlight: tapped,
                    onColorSelected: { newColor in
                        highlightStore.updateColor(of: tapped, to: newColor, context: context)
                    },
                    onDelete: {
                        highlightStore.deleteHighlight(tapped, context: context)
                    }
                )
                .position(x: menuPosition.x, y: menuPosition.y)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                .animation(.spring(duration: 0.2), value: highlightStore.tappedHighlight != nil)
                .zIndex(10)
            }
        }
    }

    // MARK: - Chrome

    private var chromeOverlay: some View {
        VStack(spacing: 0) {
            ReaderTopBar(
                title: document.title,
                onBack: {
                    viewModel.saveProgress(for: document, context: context)
                    dismiss()
                },
                onSearchTap: { viewModel.isSearchPresented = true },
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

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.4)
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

    private func handleSelectionChanged(_ selection: PDFSelection?) {
        guard let selection, let text = selection.string, !text.isEmpty else {
            currentSelection = nil
            return
        }
        currentSelection = selection

        // Position the menu above the selection
        guard let pv = pdfView,
              let page = selection.pages.first
        else { return }

        let bounds = selection.bounds(for: page)
        let topMid = CGPoint(x: bounds.midX, y: bounds.maxY)
        let inView = pv.convert(topMid, from: page)

        // Convert PDFView coordinates to SwiftUI scene coordinates
        if let window = pv.window,
           let scene = window.windowScene {
            let inWindow = pv.convert(inView, to: window)
            // Account for safe area / status bar
            let statusBarHeight = scene.statusBarManager?.statusBarFrame.height ?? 0
            menuPosition = CGPoint(
                x: inWindow.x,
                y: inWindow.y - statusBarHeight - 50
            )
        } else {
            menuPosition = CGPoint(x: inView.x, y: inView.y - 50)
        }
    }

    private func clearSelection() {
        pdfView?.clearSelection()
        currentSelection = nil
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
                    self.highlightStore.loadHighlights(into: loaded)
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
