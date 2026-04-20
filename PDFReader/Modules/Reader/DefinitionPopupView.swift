import SwiftUI

struct DefinitionPopupView: View {

    let viewModel: DefinitionViewModel
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.primary.opacity(0.2))
                .frame(width: 36, height: 4)
                .padding(.top, 8)
                .padding(.bottom, 4)

            switch viewModel.state {
            case .idle:
                EmptyView()

            case .loading:
                loadingView

            case .loaded(let response):
                loadedView(response: response)

            case .error(let error):
                errorView(error: error)
            }
        }
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .frame(maxWidth: 360)
        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 4)
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Looking up definition…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Error

    private func errorView(error: DictionaryError) -> some View {
        VStack(spacing: 10) {
            Image(systemName: errorIcon(for: error))
                .font(.system(size: 28))
                .foregroundStyle(.secondary)

            Text(error.errorDescription ?? "Something went wrong")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)

            Text(error.suggestion)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
    }

    private func errorIcon(for error: DictionaryError) -> String {
        switch error {
        case .noInternet:                return "wifi.slash"
        case .wordNotFound:              return "text.magnifyingglass"
        case .unsupportedLanguage:       return "character.bubble"
        case .unknown:                   return "exclamationmark.circle"
        }
    }

    // MARK: - Loaded

    private func loadedView(response: DictionaryResponse) -> some View {
        VStack(alignment: .leading, spacing: 0) {

            // Word header
            wordHeader(response: response)

            Divider()

            // Tab picker
            tabPicker(response: response)

            Divider()

            // Tab content
            if viewModel.activeTab == 0 {
                definitionTab(response: response)
            } else {
                synonymsTab(response: response)
            }

            // Footer
            Divider()

            Button(action: onDismiss) {
                Text("Done")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Word header

    private func wordHeader(response: DictionaryResponse) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text(response.word)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                if let phonetic = response.primaryPhonetic {
                    Text(phonetic)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Part of speech pill
            if let pos = response.meanings.first?.partOfSpeech {
                Text(pos)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Tab picker

    private func tabPicker(response: DictionaryResponse) -> some View {
        HStack(spacing: 0) {
            tabButton(title: "Definition", index: 0)

            let hasSynonyms = response.meanings.contains {
                !$0.allSynonyms.isEmpty
            }
            if hasSynonyms {
                tabButton(title: "Synonyms", index: 1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    private func tabButton(title: String, index: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                viewModel.activeTab = index
            }
        } label: {
            VStack(spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(viewModel.activeTab == index ? .medium : .regular)
                    .foregroundStyle(viewModel.activeTab == index ? .blue : .secondary)
                    .padding(.horizontal, 4)

                Rectangle()
                    .fill(viewModel.activeTab == index ? Color.blue : Color.clear)
                    .frame(height: 2)
                    .clipShape(Capsule())
            }
        }
        .buttonStyle(.plain)
        .padding(.trailing, 16)
    }

    // MARK: - Definition tab

    private func definitionTab(response: DictionaryResponse) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(response.meanings.prefix(3).enumerated()), id: \.offset) { _, meaning in
                    meaningBlock(meaning: meaning)
                }
            }
            .padding(16)
        }
        .frame(maxHeight: 220)
    }

    private func meaningBlock(meaning: Meaning) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Part of speech label
            Text(meaning.partOfSpeech)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            if let def = meaning.primaryDefinition {
                // Definition text
                Text(def.definition)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                // Example sentence
                if let example = def.example, !example.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Rectangle()
                            .fill(Color.blue.opacity(0.4))
                            .frame(width: 2)
                            .clipShape(Capsule())

                        Text("\"\(example)\"")
                            .font(.caption)
                            .italic()
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Synonyms tab

    private func synonymsTab(response: DictionaryResponse) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(
                    response.meanings.filter { !$0.allSynonyms.isEmpty }.prefix(3),
                    id: \.partOfSpeech
                ) { meaning in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(meaning.partOfSpeech)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.5)

                        // Chip flow layout
                        FlowLayout(spacing: 6) {
                            ForEach(meaning.allSynonyms, id: \.self) { synonym in
                                Text(synonym)
                                    .font(.subheadline)
                                    .foregroundStyle(.blue)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.blue.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .frame(maxHeight: 220)
    }
}

// MARK: - FlowLayout

/// Simple left-to-right wrapping layout for synonym chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let height = rows.map { row in
            row.map { subviews[$0].sizeThatFits(.unspecified).height }.max() ?? 0
        }.reduce(0) { $0 + $1 + spacing } - spacing

        return CGSize(width: proposal.width ?? 0, height: max(height, 0))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY

        for row in rows {
            var x = bounds.minX
            let rowHeight = row.map {
                subviews[$0].sizeThatFits(.unspecified).height
            }.max() ?? 0

            for index in row {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += rowHeight + spacing
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[Int]] {
        var rows: [[Int]] = [[]]
        var x: CGFloat = 0
        let maxWidth = proposal.width ?? .infinity

        for (i, subview) in subviews.enumerated() {
            let width = subview.sizeThatFits(.unspecified).width
            if x + width > maxWidth, !rows[rows.count - 1].isEmpty {
                rows.append([])
                x = 0
            }
            rows[rows.count - 1].append(i)
            x += width + spacing
        }
        return rows
    }
}
