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
    @State private var showAnnotationSidebar = false

    @State private var currentSelection: PDFSelection? = nil
    @State private var menuPosition: CGPoint = CGPoint(x: 200, y: 200)
    @State private var pendingHighlightSelection: PDFSelection? = nil
    @State private var highlightMenuPosition: CGPoint = CGPoint(x: 200, y: 200)
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

            if highlightStore.tappedHighlight != nil {
                highlightPopup
            }

            if pendingHighlightSelection != nil {
                highlightColorPicker
            }

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
        .sheet(isPresented: $showAnnotationSidebar) {
            AnnotationSidebarView(
                document: document,
                onNavigate: { pageIndex in
                    viewModel.goToPage(pageIndex)
                },
                onEditNote: { highlight in
                    noteEditorTarget = highlight
                },
                onDeleteHighlight: { highlight in
                    highlightStore.deleteHighlight(highlight, context: context)
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
                    if currentSelection == nil
                        && !definitionViewModel.isVisible
                        && pendingHighlightSelection == nil {
                        viewModel.toggleChrome()
                    }
                    clearSelection()
                    highlightStore.tappedHighlight = nil
                    definitionViewModel.dismiss()
                    pendingHighlightSelection = nil
                } else {
                    updateMenuPosition(from: point, in: pv)
                }
            },
            onHighlightRequested: { selection in
                pendingHighlightSelection = selection
                // Position the color picker above the selection
                if let pv = pdfView,
                   let page = selection.pages.first {
                    let bounds = selection.bounds(for: page)
                    let topMid = CGPoint(x: bounds.midX, y: bounds.maxY)
                    let inView = pv.convert(topMid, from: page)
                    if let window = pv.window,
                       let scene = window.windowScene {
                        let inWindow = pv.convert(inView, to: window)
                        let statusBarHeight = scene.statusBarManager?.statusBarFrame.height ?? 0
                        highlightMenuPosition = CGPoint(
                            x: inWindow.x,
                            y: inWindow.y - statusBarHeight - 50
                        )
                    }
                }
            },
            onAddNoteRequested: { selection in
                addNote(from: selection)
            },
            onDefineRequested: { text in
                clearSelection()
                definitionViewModel.lookup(
                    word: text.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
        )
        .ignoresSafeArea()
    }

    // MARK: - Highlight color picker

    private var highlightColorPicker: some View {
        HStack(spacing: 0) {
            ForEach(HighlightColor.allCases, id: \.self) { color in
                Button {
                    applyHighlight(color)
                } label: {
                    Circle()
                        .fill(color.color)
                        .frame(width: 26, height: 26)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                        )
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                )
        )
        .shadow(color: .black.opacity(0.10), radius: 12, x: 0, y: 3)
        .position(
            x: min(
                max(highlightMenuPosition.x, 90),
                UIScreen.main.bounds.width - 90
            ),
            y: highlightMenuPosition.y
        )
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
        .animation(AppAnimation.snappy, value: pendingHighlightSelection != nil)
        .zIndex(10)
    }

    // MARK: - Definition overlay

    private var definitionOverlay: some View {
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

    // MARK: - Chrome overlay

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
                onAnnotationsTap: {
                    showAnnotationSidebar = true
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
                onNext: { viewModel.goToNextPage() },
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

    // MARK: - Loading view

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
    }

    private func updateMenuPosition(from point: CGPoint, in pv: PDFView) {
        if let window = pv.window,
           let scene = window.windowScene {
            let inWindow = pv.convert(point, to: window)
            let statusBarHeight = scene.statusBarManager?.statusBarFrame.height ?? 0
            menuPosition = CGPoint(
                x: inWindow.x,
                y: inWindow.y - statusBarHeight - 50
            )
        } else {
            menuPosition = CGPoint(x: point.x, y: point.y - 50)
        }
    }

    private func clearSelection() {
        pdfView?.clearSelection()
        currentSelection = nil
        pendingHighlightSelection = nil
    }

    private func applyHighlight(_ color: HighlightColor) {
        guard let selection = pendingHighlightSelection else { return }
        _ = highlightStore.addHighlight(
            selection: selection,
            color: color,
            context: context
        )
        clearSelection()
    }

    private func addNote(from selection: PDFSelection) {
        let created = highlightStore.addHighlight(
            selection: selection,
            color: .yellow,
            context: context
        )
        clearSelection()
        noteEditorTarget = created.first
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
