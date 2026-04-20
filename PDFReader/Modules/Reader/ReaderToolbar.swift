import SwiftUI

// MARK: - Top bar

struct ReaderTopBar: View {
    let title: String
    let isCurrentPageBookmarked: Bool
    let onBack: () -> Void
    let onBookmarkTap: () -> Void
    let onSearchTap: () -> Void
    let onMoreTap: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            // Back
            Button(action: onBack) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                    Text("Library")
                        .font(.subheadline)
                }
                .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)

            Spacer()

            // Title
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
                .frame(maxWidth: 160)

            Spacer()

            // Right actions
            HStack(spacing: 18) {
                Button(action: onBookmarkTap) {
                    Image(systemName: isCurrentPageBookmarked ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 16))
                        .foregroundStyle(isCurrentPageBookmarked ? .blue : .primary)
                        .animation(.spring(duration: 0.2), value: isCurrentPageBookmarked)
                }

                Button(action: onSearchTap) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16))
                        .foregroundStyle(.primary)
                }

                Button(action: onMoreTap) {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 16))
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}

// MARK: - Bottom bar

struct ReaderBottomBar: View {
    let currentPage: Int
    let totalPages: Int
    let progress: Double
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onScrub: (Double) -> Void

    var body: some View {
        VStack(spacing: 6) {
            Slider(
                value: Binding(
                    get: { progress },
                    set: { onScrub($0) }
                ),
                in: 0...1
            )
            .tint(.blue)
            .padding(.horizontal, 16)

            HStack {
                Button(action: onPrevious) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .medium))
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .foregroundStyle(currentPage > 1 ? .blue : .secondary)
                .disabled(currentPage <= 1)

                Spacer()

                Text("\(currentPage) / \(totalPages)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                Spacer()

                Button(action: onNext) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .medium))
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .foregroundStyle(currentPage < totalPages ? .blue : .secondary)
                .disabled(currentPage >= totalPages)
            }
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}
