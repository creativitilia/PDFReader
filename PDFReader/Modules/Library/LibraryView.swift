import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct LibraryView: View {

    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    @State private var viewModel = LibraryViewModel()
    @State private var allDocuments: [Document] = []
    @State private var hasAppeared = false

    private let gridColumns = [
        GridItem(.adaptive(minimum: 155, maximum: 210), spacing: Spacing.lg)
    ]

    var body: some View {
        let documents = viewModel.filteredAndSorted(allDocuments)
        Group {
            if documents.isEmpty {
                emptyState
            } else if viewModel.isGridLayout {
                gridView(documents)
            } else {
                listView(documents)
            }
        }
        .navigationTitle("Library")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $viewModel.searchText, prompt: "Search documents")
        .toolbar { toolbarItems }
        .fileImporter(
            isPresented: $viewModel.showImporter,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                viewModel.importPDF(from: url, context: context)
                reloadDocuments()
            }
        }
        .alert("Rename", isPresented: Binding(
            get: { viewModel.renamingDocument != nil },
            set: { if !$0 { viewModel.renamingDocument = nil } }
        )) {
            TextField("Document title", text: $viewModel.renameText)
            Button("Save") {
                viewModel.commitRename(context: context)
                reloadDocuments()
            }
            Button("Cancel", role: .cancel) { viewModel.renamingDocument = nil }
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onAppear {
            reloadDocuments()
            withAnimation(AppAnimation.smooth.delay(0.05)) {
                hasAppeared = true
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                reloadDocuments()
            }
        }
    }

    private func gridView(_ documents: [Document]) -> some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: Spacing.lg) {
                ForEach(Array(documents.enumerated()), id: \.element.id) { index, doc in
                    NavigationLink(destination: ReaderView(document: doc)) {
                        DocumentCard(document: doc)
                            .opacity(hasAppeared ? 1 : 0)
                            .offset(y: hasAppeared ? 0 : 12)
                            .animation(
                                AppAnimation.smooth.delay(Double(index) * 0.04),
                                value: hasAppeared
                            )
                    }
                    .buttonStyle(.plain)
                    .contextMenu { contextMenu(for: doc) }
                }
            }
            .padding(Spacing.lg)
        }
    }

    private func listView(_ documents: [Document]) -> some View {
        List(documents) { doc in
            NavigationLink(destination: ReaderView(document: doc)) {
                DocumentListRow(document: doc)
            }
            .contextMenu { contextMenu(for: doc) }
        }
        .listStyle(.plain)
    }

    @ViewBuilder
    private func contextMenu(for doc: Document) -> some View {
        Button("Rename") { viewModel.beginRename(doc) }
        Divider()
        Button("Delete", role: .destructive) {
            viewModel.deleteDocument(doc, context: context)
            reloadDocuments()
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "books.vertical")
                .font(.system(size: 52))
                .foregroundStyle(.quaternary)
                .padding(.bottom, Spacing.sm)

            VStack(spacing: Spacing.xs) {
                Text("Your library is empty")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("Import a PDF to get started.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: { viewModel.showImporter = true }) {
                Label("Import PDF", systemImage: "plus")
                    .fontWeight(.medium)
                    .padding(.horizontal, Spacing.xl)
                    .padding(.vertical, Spacing.sm + 2)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, Spacing.xs)
        }
        .padding(Spacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: { viewModel.showImporter = true }) {
                Image(systemName: "plus")
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Picker("Sort by", selection: $viewModel.sortOrder) {
                    ForEach(LibrarySortOrder.allCases) { order in
                        Text(order.rawValue).tag(order)
                    }
                }
                Divider()
                Button {
                    withAnimation(AppAnimation.smooth) {
                        viewModel.isGridLayout.toggle()
                    }
                } label: {
                    Label(
                        viewModel.isGridLayout ? "List view" : "Grid view",
                        systemImage: viewModel.isGridLayout ? "list.bullet" : "square.grid.2x2"
                    )
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    private func reloadDocuments() {
        let descriptor = FetchDescriptor<Document>(
            sortBy: [
                SortDescriptor(\Document.lastOpenedAt, order: .reverse),
                SortDescriptor(\Document.importedAt, order: .reverse),
                SortDescriptor(\Document.title, order: .forward)
            ]
        )

        do {
            allDocuments = try context.fetch(descriptor)
        } catch {
            viewModel.errorMessage = "Could not load your library."
        }
    }
}

#Preview("With mock data") {
    NavigationStack { LibraryView() }
        .modelContainer(MockData.previewContainer)
}

#Preview("Empty state") {
    NavigationStack { LibraryView() }
        .modelContainer(AppContainer.shared.modelContainer)
}
