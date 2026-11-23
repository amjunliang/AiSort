import SwiftUI

struct OverviewHeader: View {
    let count: Int
    let favoriteCount: Int
    let updatedAt: Date?
    let rateLimit: RateLimit?
    let availableEfforts: [ReasoningEffort]
    let selectedEfforts: Set<ReasoningEffort>
    let toggleEffort: (ReasoningEffort) -> Void
    @Binding var showsChinaOnly: Bool
    @Binding var showsFavoritesOnly: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                Text("模型全景")
                    .font(.title2.bold())
                    .foregroundStyle(ink)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text("\(count) 个模型")
                    .font(.appCaption.weight(.semibold))
                    .foregroundStyle(teal)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(teal.opacity(0.09), in: Capsule())
            }

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
                            let isSelected = selectedEfforts.contains(effort)
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

            HStack(spacing: 8) {
                Text("左上角代表更高智力、更低成本")
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 4)
                if let updatedAt {
                    Text("更新于 \(updatedAt.formatted(.dateTime.month(.twoDigits).day(.twoDigits).hour().minute()))")
                        .lineLimit(1)
                        .fixedSize()
                }
            }
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

}
