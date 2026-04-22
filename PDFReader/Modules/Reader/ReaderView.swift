import SwiftUI
import PDFKit
import SwiftData

struct ReaderView: View {

    let document: Document

    @Environment(\.dismiss)      private var dismiss
    @Environment(\.modelContext) private var context

    @State private var viewModel:        ReaderViewModel
    @State private var highlightStore:   HighlightStore
    @State private var bookmarkViewModel   = BookmarkViewModel()
    @State private var definitionViewModel = DefinitionViewModel()

    @State private var pdfDocument: PDFDocument?
    @State private var pdfView:     PDFView?

    // UI state
    @State private var showErrorAlert       = false
    @State private var showBookmarkPanel    = false
    @State private var showAnnotationSidebar = false

    // Highlight color picker
    @State private var pendingHighlightSelection: PDFSelection? = nil
    @State private var highlightPickerPosition:   CGPoint       = .zero

    // Tapped highlight popup
    @State private var highlightPopupPosition: CGPoint = .zero

    // Note editor
    @State private var noteEditorTarget: Highlight? = nil

    init(document: Document) {
        self.document   = document
        _viewModel      = State(initialValue: ReaderViewModel(document: document))
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

            // Color picker — appears after tapping "Highlight" in the menu
            if pendingHighlightSelection != nil {
                highlightColorPicker
            }

            // Popup — appears when tapping an existing highlight
            if highlightStore.tappedHighlight != nil {
                tappedHighlightPopup
            }

            // Definition card
            if definitionViewModel.isVisible {
                definitionOverlay
            }
        }
        .navigationBarHidden(true)
        .ignoresSafeArea(edges: .bottom)
        .statusBarHidden(!viewModel.isChromeVisible)
        .sheet(isPresented: $viewModel.isSearchPresented) {
            if let pdf = pdfDocument {
                SearchView(pdfDocument: pdf) { result in
                    viewModel.navigate(to: result, in: pdfView)
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showBookmarkPanel) {
            BookmarkPanelView(
                document: document,
                currentPageIndex: viewModel.currentPageIndex,
                onNavigate: { viewModel.goToPage($0) }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAnnotationSidebar) {
            AnnotationSidebarView(
                document: document,
                onNavigate: { viewModel.goToPage($0) },
                onEditNote: { noteEditorTarget = $0 },
                onDeleteHighlight: { highlightStore.deleteHighlight($0, context: context) }
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
                if selection == nil || (selection?.string ?? "").isEmpty {
                    // Selection cleared — dismiss color picker if open
                    pendingHighlightSelection = nil
                }
                highlightStore.tappedHighlight = nil
                definitionViewModel.dismiss()
            },
            onTap: { point, pv in
                if pdfView == nil { pdfView = pv }

                let hitHighlight = highlightStore.handleTap(at: point, on: pv)

                if hitHighlight {
                    highlightPopupPosition = screenPoint(from: point, in: pv)
                    pendingHighlightSelection = nil
                    definitionViewModel.dismiss()
                } else {
                    highlightStore.tappedHighlight = nil
                    pendingHighlightSelection = nil
                    definitionViewModel.dismiss()
                    viewModel.toggleChrome()
                }
            },
            onHighlightRequested: { selection, screenPt in
                // "Highlight" tapped in menu — show the color picker
                pendingHighlightSelection = selection
                highlightPickerPosition = adjustedPickerPosition(screenPt)
            },
            onAddNoteRequested: { selection in
                addNote(from: selection)
            },
            onDefineRequested: { text in
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
                            Circle().strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
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
        .position(highlightPickerPosition)
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
        .animation(AppAnimation.snappy, value: pendingHighlightSelection != nil)
        .zIndex(15)
    }

    // MARK: - Tapped highlight popup

    private var tappedHighlightPopup: some View {
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
                .position(clampX(highlightPopupPosition, halfWidth: 130))
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
                .animation(.spring(duration: 0.25), value: highlightStore.tappedHighlight != nil)
                .zIndex(15)
            }
        }
    }

    // MARK: - Definition overlay

    private var definitionOverlay: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.01)
                .ignoresSafeArea()
                .onTapGesture { definitionViewModel.dismiss() }

            DefinitionPopupView(
                viewModel: definitionViewModel,
                onDismiss: { definitionViewModel.dismiss() }
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .transition(.opacity)
        .animation(.spring(duration: 0.3), value: definitionViewModel.isVisible)
        .zIndex(20)
    }

    // MARK: - Chrome

    private var chromeOverlay: some View {
        VStack(spacing: 0) {
            ReaderTopBar(
                title: document.title,
                isCurrentPageBookmarked: bookmarkViewModel.isPageBookmarked(
                    viewModel.currentPageIndex, in: document
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
                onSearchTap:      { viewModel.isSearchPresented = true },
                onAnnotationsTap: { showAnnotationSidebar = true },
                onMoreTap:        { showBookmarkPanel = true }
            )
            .transition(.move(edge: .top).combined(with: .opacity))

            Spacer()

            ReaderBottomBar(
                currentPage: viewModel.currentPageIndex + 1,
                totalPages:  max(viewModel.totalPages, 1),
                progress:    progressFraction,
                onPrevious:  { viewModel.goToPreviousPage() },
                onNext:      { viewModel.goToNextPage() },
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
                    Button("Cancel") { bookmarkViewModel.isAddingBookmark = false }
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
                            .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

    /// Converts a PDFView-local point to SwiftUI screen coordinates.
    private func screenPoint(from point: CGPoint, in pv: PDFView) -> CGPoint {
        guard let window = pv.window,
              let scene  = window.windowScene
        else { return point }
        let inWindow = pv.convert(point, to: window)
        let statusBarH = scene.statusBarManager?.statusBarFrame.height ?? 0
        return CGPoint(x: inWindow.x, y: inWindow.y - statusBarH)
    }

    /// Positions the picker above the tap point and clamps it to screen bounds.
    private func adjustedPickerPosition(_ point: CGPoint) -> CGPoint {
        let halfW: CGFloat = 140
        let screenW = UIScreen.main.bounds.width
        let x = min(max(point.x, halfW + 8), screenW - halfW - 8)
        return CGPoint(x: x, y: point.y - 50)
    }

    /// Clamps a position so a popup of given halfWidth stays on screen.
    private func clampX(_ point: CGPoint, halfWidth: CGFloat) -> CGPoint {
        let screenW = UIScreen.main.bounds.width
        let x = min(max(point.x, halfWidth + 8), screenW - halfWidth - 8)
        return CGPoint(x: x, y: point.y)
    }

    private func applyHighlight(_ color: HighlightColor) {
        guard let selection = pendingHighlightSelection else { return }
        _ = highlightStore.addHighlight(selection: selection, color: color, context: context)
        pendingHighlightSelection = nil
    }

    private func addNote(from selection: PDFSelection) {
        let created = highlightStore.addHighlight(
            selection: selection, color: .yellow, context: context
        )
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
