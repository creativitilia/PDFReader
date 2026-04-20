import SwiftUI
import PDFKit
import SwiftData

struct ReaderView: View {

    let document: Document

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var viewModel: ReaderViewModel
    @State private var highlightStore: HighlightStore
    @State private var bookmarkViewModel = BookmarkViewModel()
    @State private var definitionViewModel = DefinitionViewModel()
    @State private var pdfDocument: PDFDocument?
    @State private var pdfView: PDFView?
    @State private var showErrorAlert = false
    @State private var showBookmarkPanel = false

    @State private var currentSelection: PDFSelection? = nil
    @State private var selectedText: String = ""
    @State private var menuPosition: CGPoint = CGPoint(x: 200, y: 200)
    @State private var noteEditorTarget: Highlight? = nil

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

            // Selection menu (shown when text selected)
            if currentSelection != nil {
                selectionMenu
            }

            // Highlight tap popup
            if highlightStore.tappedHighlight != nil {
                highlightPopup
            }

            // Definition popup (shown as bottom sheet overlay)
            if definitionViewModel.isVisible {
                definitionOverlay
            }
        }
        .navigationBarHidden(true)
        .ignoresSafeArea(edges: .bottom)
        .statusBarHidden(!viewModel.isChromeVisible)
        .sheet(isPresented: $viewModel.isSearchPresented) {
            if let pdf = pdfDocument {
                SearchView(
                    pdfDocument: pdf,
                    onResultTap: { result in
                        viewModel.navigate(to: result, in: pdfView)
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showBookmarkPanel) {
            BookmarkPanelView(
                document: document,
                currentPageIndex: viewModel.currentPageIndex,
                onNavigate: { pageIndex in
                    viewModel.goToPage(pageIndex)
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $noteEditorTarget) { highlight in
            NoteEditorView(
                highlight: highlight,
                onSave: { text in
                    highlightStore.saveNote(for: highlight, text: text, context: context)
                    if let pdf = pdfDocument {
                        highlightStore.loadHighlights(into: pdf)
                    }
                },
                onDelete: {
                    highlightStore.deleteNote(from: highlight, context: context)
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $bookmarkViewModel.isAddingBookmark) {
            addBookmarkSheet
        }
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
                    definitionViewModel.dismiss()
                }
            },
            onTap: { point, pv in
                if pdfView == nil { pdfView = pv }

                let hitHighlight = highlightStore.handleTap(at: point, on: pv)

                if !hitHighlight {
                    if currentSelection == nil && !definitionViewModel.isVisible {
                        viewModel.toggleChrome()
                    }
                    clearSelection()
                    highlightStore.tappedHighlight = nil
                    definitionViewModel.dismiss()
                } else {
                    updateMenuPosition(from: point, in: pv)
                }
            }
        )
        .ignoresSafeArea()
    }

    // MARK: - Selection menu

    private var selectionMenu: some View {
        SelectionMenuView(
            selectedText: selectedText,
            onColorSelected: { color in
                guard let selection = currentSelection else { return }
                highlightStore.addHighlight(
                    selection: selection,
                    color: color,
                    context: context
                )
                clearSelection()
            },
            onDefine: {
                let word = selectedText
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                clearSelection()
                definitionViewModel.lookup(word: word)
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

    // MARK: - Definition overlay

    private var definitionOverlay: some View {
        // Dimmed background tap to dismiss
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.01)
                .ignoresSafeArea()
                .onTapGesture {
                    definitionViewModel.dismiss()
                }

            VStack {
                Spacer()
                DefinitionPopupView(
                    viewModel: definitionViewModel,
                    onDismiss: { definitionViewModel.dismiss() }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
        }
        .transition(.opacity)
        .animation(.spring(duration: 0.3), value: definitionViewModel.isVisible)
        .zIndex(20)
    }

    // MARK: - Highlight popup

    private var highlightPopup: some View {
        Group {
            if let tapped = highlightStore.tappedHighlight {
                NotePopupView(
                    highlight: tapped,
                    onEditNote: {
                        noteEditorTarget = tapped
                        highlightStore.tappedHighlight = nil
                    },
                    onChangeColor: { newColor in
                        highlightStore.updateColor(of: tapped, to: newColor, context: context)
                    },
                    onDelete: {
                        highlightStore.deleteHighlight(tapped, context: context)
                    }
                )
                .position(x: clampedMenuX, y: menuPosition.y)
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
                .animation(.spring(duration: 0.25), value: highlightStore.tappedHighlight != nil)
                .zIndex(10)
            }
        }
    }

    private var clampedMenuX: CGFloat {
        let halfWidth: CGFloat = 130
        let screenWidth = UIScreen.main.bounds.width
        return min(max(menuPosition.x, halfWidth + 8), screenWidth - halfWidth - 8)
    }

    // MARK: - Chrome

    private var chromeOverlay: some View {
        VStack(spacing: 0) {
            ReaderTopBar(
                title: document.title,
                isCurrentPageBookmarked: bookmarkViewModel.isPageBookmarked(
                    viewModel.currentPageIndex,
                    in: document
                ),
                onBack: {
                    viewModel.saveProgress(for: document, context: context)
                    dismiss()
                },
                onBookmarkTap: {
                    bookmarkViewModel.toggleBookmark(
                        for: document,
                        pageIndex: viewModel.currentPageIndex,
                        context: context
                    )
                },
                onSearchTap: {
                    viewModel.isSearchPresented = true
                },
                onMoreTap: {
                    showBookmarkPanel = true
                }
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

    // MARK: - Add bookmark sheet

    private var addBookmarkSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 14) {
                    Image(systemName: "bookmark.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                        .frame(width: 44, height: 44)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(document.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        Text("Page \(bookmarkViewModel.pendingPageIndex + 1)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Bookmark name")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.4)
                        .padding(.horizontal, 20)

                    TextField("Enter a name", text: $bookmarkViewModel.newBookmarkName)
                        .font(.body)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal, 20)
                        .onSubmit {
                            bookmarkViewModel.confirmAddBookmark(
                                to: document,
                                pageIndex: bookmarkViewModel.pendingPageIndex,
                                context: context
                            )
                        }
                }

                Spacer()
            }
            .navigationTitle("Add Bookmark")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        bookmarkViewModel.isAddingBookmark = false
                    }
                    .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        bookmarkViewModel.confirmAddBookmark(
                            to: document,
                            pageIndex: bookmarkViewModel.pendingPageIndex,
                            context: context
                        )
                    }
                    .fontWeight(.medium)
                    .disabled(
                        bookmarkViewModel.newBookmarkName
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                            .isEmpty
                    )
                }
            }
        }
        .presentationDetents([.height(260)])
        .presentationDragIndicator(.visible)
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
            selectedText = ""
            return
        }
        currentSelection = selection
        selectedText = text

        guard let pv = pdfView,
              let page = selection.pages.first
        else { return }

        let bounds = selection.bounds(for: page)
        let topMid = CGPoint(x: bounds.midX, y: bounds.maxY)
        let inView = pv.convert(topMid, from: page)
        updateMenuPosition(from: inView, in: pv)
    }

    private func updateMenuPosition(from point: CGPoint, in pv: PDFView) {
        if let window = pv.window,
           let scene = window.windowScene {
            let inWindow = pv.convert(point, to: window)
            let statusBarHeight = scene.statusBarManager?.statusBarFrame.height ?? 0
            menuPosition = CGPoint(x: inWindow.x, y: inWindow.y - statusBarHeight - 50)
        } else {
            menuPosition = CGPoint(x: point.x, y: point.y - 50)
        }
    }

    private func clearSelection() {
        pdfView?.clearSelection()
        currentSelection = nil
        selectedText = ""
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
