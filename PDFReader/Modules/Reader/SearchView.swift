import SwiftUI
import PDFKit

struct SearchView: View {

    let pdfDocument: PDFDocument
    /// Called when user taps a result — passes the selection to highlight.
    let onResultTap: (SearchResult) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = SearchViewModel()
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                searchBar

                Divider()

                // Content
                Group {
                    if viewModel.isSearching {
                        searchingState
                    } else if viewModel.hasSearched && viewModel.results.isEmpty {
                        emptyState
                    } else if !viewModel.results.isEmpty {
                        resultsList
                    } else {
                        promptState
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear {
            viewModel.configure(with: pdfDocument)
            isSearchFocused = true
        }
        .onDisappear {
            viewModel.clearSearch()
        }
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 15))

            TextField("Search in document", text: $viewModel.query)
                .focused($isSearchFocused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .onChange(of: viewModel.query) {
                    viewModel.onQueryChanged()
                }
                .onSubmit {
                    viewModel.onQueryChanged()
                }

            if !viewModel.query.isEmpty {
                Button {
                    viewModel.clearSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 15))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Results list

    private var resultsList: some View {
        List {
            Section {
                ForEach(viewModel.results) { result in
                    SearchResultRow(
                        result: result,
                        query: viewModel.query
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onResultTap(result)
                        dismiss()
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                }
            } header: {
                Text(resultCountLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(nil)
            }
        }
        .listStyle(.plain)
    }

    private var resultCountLabel: String {
        let count = viewModel.results.count
        if count >= 200 {
            return "200+ results — refine your search"
        }
        return count == 1 ? "1 result" : "\(count) results"
    }

    // MARK: - States

    private var searchingState: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Searching…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("No results for \"\(viewModel.query)\"")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    private var promptState: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("Type to search")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - SearchResultRow

private struct SearchResultRow: View {

    let result: SearchResult
    let query: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            // Page label
            Text(result.pageLabel)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.blue)

            // Snippet with the match highlighted
            highlightedSnippet
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(2)
        }
        .padding(.vertical, 2)
    }

    /// Builds an AttributedString that bolds the matching query text.
    private var highlightedSnippet: Text {
        let snippet = result.contextSnippet
        let lowerSnippet = snippet.lowercased()
        let lowerQuery = query.lowercased()

        guard let range = lowerSnippet.range(of: lowerQuery) else {
            return Text(snippet)
        }

        let before = String(snippet[snippet.startIndex..<range.lowerBound])
        let match  = String(snippet[range])
        let after  = String(snippet[range.upperBound...])

        return Text(before)
            + Text(match).bold().foregroundStyle(.blue)
            + Text(after)
    }
}
