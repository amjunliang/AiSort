import SwiftUI

struct ModelBubble: View {
    let model: AIModel
    let width: CGFloat
    let showsName: Bool
    let pointsUp: Bool
    let tailCenterX: CGFloat
    let showDetail: () -> Void
    let dismiss: () -> Void

    private let tailSize = CGSize(width: 22, height: 11)

    var body: some View {
        VStack(spacing: 0) {
            if pointsUp { tailRow }

            VStack(alignment: .leading, spacing: showsName ? 9 : 0) {
                if showsName {
                    HStack(spacing: 7) {
                        Circle()
                            .fill(creatorColor(model.modelCreator.name))
                            .frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(model.name)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(ink)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(model.modelCreator.name)
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 2)
                        Button(action: showDetail) {
                            Image(systemName: "info.circle")
                                .frame(width: 24, height: 24)
                        }
                        .accessibilityLabel("查看\(model.name)详情")
                        Button(action: dismiss) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .frame(width: 24, height: 24)
                        }
                        .accessibilityLabel("关闭模型信息")
                    }
                }

                HStack(spacing: 10) {
                    compactMetric("智力", number(model.intelligence))
                    compactMetric("成本", dollars(model.cost))
                    compactMetric("速度", number(model.speed, digits: 0))
                    if !showsName {
                        Button(action: dismiss) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .frame(width: 24, height: 24)
                        }
                        .accessibilityLabel("关闭模型信息")
                    }
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .frame(width: width, height: showsName ? 127 : 75)

            if !pointsUp { tailRow }
        }
        .frame(width: width)
        .background {
            BubbleOutline(pointsUp: pointsUp, tailCenterX: tailCenterX, tailSize: tailSize)
                .fill(.white)
                .overlay {
                    BubbleOutline(pointsUp: pointsUp, tailCenterX: tailCenterX, tailSize: tailSize)
                        .stroke(teal.opacity(0.2), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .foregroundStyle(teal)
        .compositingGroup()
        .shadow(color: .black.opacity(0.14), radius: 12, y: 5)
        .accessibilityElement(children: .contain)
    }

    private var tailRow: some View {
        Color.clear.frame(width: width, height: tailSize.height)
    }

    private func compactMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 15, weight: .semibold).monospacedDigit())
                .foregroundStyle(ink)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct BubbleOutline: Shape {
    let pointsUp: Bool
    let tailCenterX: CGFloat
    let tailSize: CGSize

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let top = rect.minY + (pointsUp ? tailSize.height : 0)
        let bottom = rect.maxY - (pointsUp ? 0 : tailSize.height)
        let corner: CGFloat = 12
        let center = rect.minX + tailCenterX
        let halfTail = tailSize.width / 2
        path.move(to: CGPoint(x: rect.minX + corner, y: top))
        if pointsUp {
            path.addLine(to: CGPoint(x: center - halfTail, y: top))
            path.addLine(to: CGPoint(x: center, y: rect.minY))
            path.addLine(to: CGPoint(x: center + halfTail, y: top))
        }
        path.addLine(to: CGPoint(x: rect.maxX - corner, y: top))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: top + corner), control: CGPoint(x: rect.maxX, y: top))
        path.addLine(to: CGPoint(x: rect.maxX, y: bottom - corner))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - corner, y: bottom), control: CGPoint(x: rect.maxX, y: bottom))
        if !pointsUp {
            path.addLine(to: CGPoint(x: center + halfTail, y: bottom))
            path.addLine(to: CGPoint(x: center, y: rect.maxY))
            path.addLine(to: CGPoint(x: center - halfTail, y: bottom))
        }
        path.addLine(to: CGPoint(x: rect.minX + corner, y: bottom))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: bottom - corner), control: CGPoint(x: rect.minX, y: bottom))
        path.addLine(to: CGPoint(x: rect.minX, y: top + corner))
        path.addQuadCurve(to: CGPoint(x: rect.minX + corner, y: top), control: CGPoint(x: rect.minX, y: top))
        path.closeSubpath()
        return path
    }
}

enum BubblePlacement {
    static let padding: CGFloat = 8
    static let gap: CGFloat = 9

    static func place(size: CGSize, at anchor: CGPoint, in container: CGSize, gap: CGFloat = BubblePlacement.gap) -> (frame: CGRect, isBelowAnchor: Bool) {
        let above = aboveHeight(at: anchor, in: container)
        let below = belowHeight(at: anchor, in: container)
        let isBelow: Bool
        if above >= size.height + gap {
            isBelow = false
        } else if below >= size.height + gap {
            isBelow = true
        } else {
            isBelow = below > above
        }
        let desiredY = isBelow ? anchor.y + gap : anchor.y - gap - size.height
        let maxX = max(padding, container.width - size.width - padding)
        let maxY = max(padding, container.height - size.height - padding)
        let x = min(maxX, max(padding, anchor.x - size.width / 2))
        let y = min(maxY, max(padding, desiredY))
        return (CGRect(origin: CGPoint(x: x, y: y), size: size), isBelow)
    }

    private static func aboveHeight(at anchor: CGPoint, in container: CGSize) -> CGFloat {
        anchor.y - padding
    }

    private static func belowHeight(at anchor: CGPoint, in container: CGSize) -> CGFloat {
        container.height - anchor.y - padding
    }
}
