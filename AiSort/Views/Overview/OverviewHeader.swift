import SwiftUI

struct OverviewHeader: View {
    let count: Int
    let favoriteCount: Int
    let rateLimit: RateLimit?
    let filterRules: [String]
    let clearFilters: () -> Void
    let availableEfforts: [ReasoningEffort]
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
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
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
                    Text("\(count) 个模型")
                        .font(.appCaption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(teal)
                        .fixedSize()
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(teal.opacity(0.09), in: Capsule())
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
                            .font(.appCaption.weight(.semibold))
                            .foregroundStyle(showsChinaOnly ? .white : teal)
                            .lineLimit(1)
                            .fixedSize()
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(showsChinaOnly ? tealFill : teal.opacity(0.09), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(showsChinaOnly ? .isSelected : [])

                    if favoriteCount > 0 || showsFavoritesOnly {
                        Button {
                            showsFavoritesOnly.toggle()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 11, weight: .semibold))
                                Text("收藏 (\(favoriteCount))")
                            }
                            .font(.appCaption.weight(.semibold))
                            .foregroundStyle(showsFavoritesOnly ? .white : teal)
                            .lineLimit(1)
                            .fixedSize()
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(showsFavoritesOnly ? tealFill : teal.opacity(0.09), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(showsFavoritesOnly ? .isSelected : [])
                    }

                    if !availableEfforts.isEmpty {
                        Rectangle()
                            .fill(Color.primary.opacity(0.12))
                            .frame(width: 1, height: 16)
                            .padding(.horizontal, 2)

                        ForEach(availableEfforts) { effort in
                            let isSelected = effort == selectedEffort
                            Button {
                                toggleEffort(effort)
                            } label: {
                                Text(effort.rawValue)
                                    .font(.appCaption.weight(.semibold))
                                    .foregroundStyle(isSelected ? .white : teal)
                                    .lineLimit(1)
                                    .fixedSize()
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(isSelected ? tealFill : teal.opacity(0.09), in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(isSelected ? .isSelected : [])
                        }
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
                .foregroundStyle(teal)
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
