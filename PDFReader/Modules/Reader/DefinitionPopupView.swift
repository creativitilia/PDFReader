import SwiftUI

struct DefinitionPopupView: View {

    let viewModel: DefinitionViewModel
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(Color.primary.opacity(0.18))
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 6)

            switch viewModel.state {
            case .idle:
                EmptyView()
            case .loading:
                loadingView
            case .loaded(let response):
                loadedView(response)
            case .error(let error):
                errorView(error)
            }
        }
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.13), radius: 24, x: 0, y: 6)
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 10) {
            ProgressView()
            Text("Looking up…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .padding(.bottom, 16)
    }

    // MARK: - Error

    private func errorView(_ error: DictionaryError) -> some View {
        VStack(spacing: 10) {
            Image(systemName: errorIcon(for: error))
                .font(.system(size: 30))
                .foregroundStyle(.secondary)
            Text(error.errorDescription ?? "Something went wrong")
                .font(.subheadline)
                .fontWeight(.medium)
            Text(error.suggestion)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .padding(.bottom, 8)
    }

    private func errorIcon(for error: DictionaryError) -> String {
        switch error {
        case .noInternet:   return "wifi.slash"
        case .wordNotFound: return "text.magnifyingglass"
        case .unknown:      return "exclamationmark.circle"
        }
    }

    // MARK: - Loaded

    private func loadedView(_ response: DictionaryResponse) -> some View {
        VStack(spacing: 0) {

            // Header
            header(response)

            Divider().padding(.horizontal, 4)

            // Scrollable content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(Array(response.entries.prefix(3).enumerated()), id: \.offset) { i, entry in
                        entryBlock(entry, index: i, total: min(response.entries.count, 3))
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .frame(maxHeight: 320)
        }
    }

    // MARK: - Header

    private func header(_ response: DictionaryResponse) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(response.word)
                    .font(.system(size: 22, weight: .semibold, design: .default))
                    .foregroundStyle(.primary)

                if let phonetic = response.phonetic, !phonetic.isEmpty {
                    Text(phonetic)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    // MARK: - Entry block

    private func entryBlock(_ entry: DictionaryEntry, index: Int, total: Int) -> some View {
        VStack(alignment: .leading, spacing: 14) {

            // Part of speech label
            Text(entry.partOfSpeech)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.blue)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.blue.opacity(0.09))
                .clipShape(Capsule())

            // Definitions
            if !entry.definitions.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(entry.definitions.prefix(3).enumerated()), id: \.offset) { i, def in
                        definitionRow(def, number: i + 1, showNumber: entry.definitions.count > 1)
                    }
                }
            }

            // Synonyms
            if !entry.synonyms.isEmpty {
                synonymsSection(entry.synonyms)
            }

            // Divider between entries (not after last)
            if index < total - 1 {
                Divider()
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - Definition row

    private func definitionRow(_ def: DictionaryDefinition, number: Int, showNumber: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                if showNumber {
                    Text("\(number).")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .frame(width: 16, alignment: .leading)
                }

                Text(def.text)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let example = def.example, !example.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    if showNumber {
                        Spacer().frame(width: 16)
                    }

                    HStack(alignment: .top, spacing: 6) {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.blue.opacity(0.35))
                            .frame(width: 2)
                            .padding(.top, 2)

                        Text(example)
                            .font(.caption)
                            .italic()
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    // MARK: - Synonyms section

    private func synonymsSection(_ synonyms: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Synonyms")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            // Wrapping chip layout
            FlowLayout(spacing: 6) {
                ForEach(synonyms, id: \.self) { word in
                    Text(word)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Color(UIColor.label).opacity(0.75))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }
}

// MARK: - FlowLayout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(for: subviews, width: proposal.width ?? .infinity)
        let height = rows.map { row in
            row.map { subviews[$0].sizeThatFits(.unspecified).height }.max() ?? 0
        }.reduce(0) { $0 + $1 + spacing } - spacing
        return CGSize(width: proposal.width ?? 0, height: max(height, 0))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(for: subviews, width: bounds.width) {
            var x = bounds.minX
            let h = row.map { subviews[$0].sizeThatFits(.unspecified).height }.max() ?? 0
            for i in row {
                let size = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += h + spacing
        }
    }

    private func rows(for subviews: Subviews, width: CGFloat) -> [[Int]] {
        var rows: [[Int]] = [[]]
        var x: CGFloat = 0
        for (i, sv) in subviews.enumerated() {
            let w = sv.sizeThatFits(.unspecified).width
            if x + w > width, !rows[rows.count - 1].isEmpty {
                rows.append([]); x = 0
            }
            rows[rows.count - 1].append(i)
            x += w + spacing
        }
        return rows
    }
}
