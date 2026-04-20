import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct LibraryView: View {

    // MARK: - Environment & state

    @Environment(\.modelContext) private var context
    @Query private var allDocuments: [Document]

    @State private var viewModel = LibraryViewModel()
    @State private var selectedDocument: Document? = nil

    private let gridColumns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
    ]

    // MARK: - Body

    var body: some View {
        Group {
            let documents = viewModel.filteredAndSorted(allDocuments)
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
            }
        }
        .alert("Rename", isPresented: Binding(
            get: { viewModel.renamingDocument != nil },
            set: { if !$0 { viewModel.renamingDocument = nil } }
        )) {
            TextField("Document title", text: $viewModel.renameText)
            Button("Save") { viewModel.commitRename(context: context) }
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
    }

    // MARK: - Subviews

    private func gridView(_ documents: [Document]) -> some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 16) {
                ForEach(documents) { doc in
                    DocumentCard(document: doc)
                        .onTapGesture {
                            selectedDocument = doc
                        }
                        .contextMenu { contextMenu(for: doc) }
                }
            }
            .padding(16)
        }
        .navigationDestination(isPresented: Binding(
            get: { selectedDocument != nil },
            set: { if !$0 { selectedDocument = nil } }
        )) {
            if let doc = selectedDocument {
                ReaderView(document: doc)
            }
        }
    }

    private func listView(_ documents: [Document]) -> some View {
        List(documents) { doc in
            DocumentListRow(document: doc)
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedDocument = doc
                }
                .contextMenu { contextMenu(for: doc) }
        }
        .listStyle(.plain)
        .navigationDestination(isPresented: Binding(
            get: { selectedDocument != nil },
            set: { if !$0 { selectedDocument = nil } }
        )) {
            if let doc = selectedDocument {
                ReaderView(document: doc)
            }
        }
    }

    @ViewBuilder
    private func contextMenu(for doc: Document) -> some View {
        Button("Rename") { viewModel.beginRename(doc) }
        Divider()
        Button("Delete", role: .destructive) {
            viewModel.deleteDocument(doc, context: context)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("No documents yet")
                .font(.title3)
                .fontWeight(.medium)
            Text("Tap the import button above to add your first PDF.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(action: { viewModel.showImporter = true }) {
                Label("Import PDF", systemImage: "plus")
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(40)
    }

    // MARK: - Toolbar

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
                    withAnimation { viewModel.isGridLayout.toggle() }
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
}

// MARK: - Preview

#Preview("With mock data") {
    NavigationStack {
        LibraryView()
    }
    .modelContainer(MockData.previewContainer)
}

#Preview("Empty state") {
    NavigationStack {
        LibraryView()
    }
    .modelContainer(AppContainer.shared.modelContainer)
}
