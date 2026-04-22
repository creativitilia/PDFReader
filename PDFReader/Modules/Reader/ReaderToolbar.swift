import SwiftUI

// MARK: - Top bar

struct ReaderTopBar: View {
    let title: String
    let isCurrentPageBookmarked: Bool
    let onBack: () -> Void
    let onBookmarkTap: () -> Void
    let onSearchTap: () -> Void
    let onAnnotationsTap: () -> Void
    let onMoreTap: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Back
            Button(action: onBack) {
                HStack(spacing: 3) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Library")
                        .font(.subheadline)
                }
                .foregroundStyle(.blue)
                .padding(.vertical, Spacing.sm)
                .padding(.trailing, Spacing.sm)
            }
            .buttonStyle(.plain)

            Spacer(minLength: Spacing.sm)

            // Title
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 200)

            Spacer(minLength: Spacing.sm)

            // Right actions
            HStack(spacing: Spacing.lg) {
                ToolbarIconButton(
                    icon: isCurrentPageBookmarked ? "bookmark.fill" : "bookmark",
                    tint: isCurrentPageBookmarked ? .blue : .primary,
                    action: onBookmarkTap
                )
                .symbolEffect(.bounce, value: isCurrentPageBookmarked)

                ToolbarIconButton(icon: "magnifyingglass", action: onSearchTap)
                ToolbarIconButton(icon: "text.alignleft", action: onAnnotationsTap)
                ToolbarIconButton(icon: "ellipsis.circle", action: onMoreTap)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm + 2)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) { Divider() }
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
        VStack(spacing: 4) {
            HStack(spacing: Spacing.sm) {
                Text("1")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(UIColor.tertiaryLabel))
                    .monospacedDigit()

                Slider(
                    value: Binding(get: { progress }, set: { onScrub($0) }),
                    in: 0...1
                )
                .tint(.blue)

                Text("\(totalPages)")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(UIColor.tertiaryLabel))
                    .monospacedDigit()
            }
            .padding(.horizontal, Spacing.lg)

            HStack {
                Button(action: onPrevious) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 44, height: 36)
                        .contentShape(Rectangle())
                }
                .foregroundStyle(currentPage > 1 ? Color.blue : Color(UIColor.tertiaryLabel))
                .disabled(currentPage <= 1)

                Spacer()

                Text("\(currentPage) of \(totalPages)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                Spacer()

                Button(action: onNext) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 44, height: 36)
                        .contentShape(Rectangle())
                }
                .foregroundStyle(currentPage < totalPages ? Color.blue : Color(UIColor.tertiaryLabel))
                .disabled(currentPage >= totalPages)
            }
            .padding(.horizontal, Spacing.sm)
        }
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.xs)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Divider() }
    }
}

// MARK: - ToolbarIconButton

private struct ToolbarIconButton: View {
    let icon: String
    var tint: Color = .primary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
