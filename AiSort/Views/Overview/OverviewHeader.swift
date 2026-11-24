import SwiftUI

struct OverviewHeader: View {
    let count: Int
    let totalCount: Int
    let favoriteCount: Int
    let totalFavoriteCount: Int
    let rateLimit: RateLimit?
    let filterRules: [String]
    let clearFilters: () -> Void
    let availableEfforts: Set<ReasoningEffort>
    let selectedEffort: ReasoningEffort?
    let toggleEffort: (ReasoningEffort) -> Void
    @Binding var showsChinaOnly: Bool
    @Binding var showsFavoritesOnly: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Text("模型全景")
                    .font(.title2.bold())
                    .foregroundStyle(ink)
                    .lineLimit(1)
                    .fixedSize()
                if filterRules.isEmpty {
                    Spacer(minLength: 0)
                } else {
                    let summary = filterRules.joined(separator: " · ")
                    Text(summary)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ink.opacity(0.9))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .help(summary)
                        .accessibilityLabel("当前筛选，\(summary)")
                }
                HStack(spacing: 4) {
                    clearFiltersButton
                        .opacity(filterRules.isEmpty ? 0 : 1)
                        .disabled(filterRules.isEmpty)
                        .accessibilityHidden(filterRules.isEmpty)
                    Text("\(totalCount) 个模型")
                        .hidden()
                        .overlay(alignment: .trailing) { Text("\(count) 个模型") }
                        .font(.appCaption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(ink.opacity(0.8))
                        .fixedSize()
                        .padding(.horizontal, 4)
                        .padding(.vertical, 5)
                }
                .fixedSize()
            }
            .frame(minHeight: 28)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button {
                        showsChinaOnly.toggle()
                    } label: {
                        Text("只看中国")
                            .filterChip(selected: showsChinaOnly)
                            .lineLimit(1)
                            .fixedSize()
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(showsChinaOnly ? .isSelected : [])

                    let canToggleFavorites = favoriteCount > 0 || showsFavoritesOnly
                    Button {
                        showsFavoritesOnly.toggle()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 11, weight: .semibold))
                            Text("收藏 (\(totalFavoriteCount))")
                                .hidden()
                                .overlay(alignment: .leading) { Text("收藏 (\(favoriteCount))") }
                                .monospacedDigit()
                        }
                        .filterChip(selected: showsFavoritesOnly)
                        .lineLimit(1)
                        .fixedSize()
                    }
                    .buttonStyle(.plain)
                    .disabled(!canToggleFavorites)
                    .accessibilityAddTraits(showsFavoritesOnly ? .isSelected : [])

                    Rectangle()
                        .fill(Color.primary.opacity(0.12))
                        .frame(width: 1, height: 16)
                        .padding(.horizontal, 2)

                    ForEach(ReasoningEffort.allCases) { effort in
                        let isSelected = effort == selectedEffort
                        let isAvailable = availableEfforts.contains(effort)
                        Button {
                            toggleEffort(effort)
                        } label: {
                            Text(effort.rawValue)
                                .filterChip(selected: isSelected)
                                .lineLimit(1)
                                .fixedSize()
                        }
                        .buttonStyle(.plain)
                        .disabled(!isAvailable)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }

                    if let rateLimit, rateLimit.remaining < 10 {
                        Text(rateLimit.limit.map { "额度 \(rateLimit.remaining)/\($0)" } ?? "额度剩余 \(rateLimit.remaining)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.orange)
                            .lineLimit(1)
                            .fixedSize()
                            .padding(.leading, 4)
                            .help("Artificial Analysis 免费额度，\(RefreshPolicy.format(rateLimit.resetAt, now: Date())) 重置")
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private var clearFiltersButton: some View {
        Button(action: clearFilters) {
            Text("清除")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ink)
                .fixedSize()
                .padding(.horizontal, 4)
                .frame(height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("清除全部筛选")
        .accessibilityLabel("清除全部筛选")
    }
}

private struct FilterChipStyle: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled
    let selected: Bool

    func body(content: Content) -> some View {
        content
            .font(.appCaption.weight(.semibold))
            .foregroundStyle(selected ? appBackground : ink.opacity(isEnabled ? 1 : 0.66))
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(selected ? ink : ink.opacity(isEnabled ? 0.07 : 0.035), in: Capsule())
            .overlay(Capsule().strokeBorder(selected ? Color.clear : ink.opacity(isEnabled ? 0.2 : 0.12), lineWidth: 1))
            .contentShape(Capsule())
    }
}

private extension View {
    func filterChip(selected: Bool) -> some View { modifier(FilterChipStyle(selected: selected)) }
}
