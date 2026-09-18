import SwiftUI

/// 书签标签页外形：左上与左下微圆角，右侧直角无缝接入主面板
struct BookmarkTabShape: Shape {
    var cornerRadius: CGFloat = 6

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let r = min(cornerRadius, min(w, h) / 2)

        // 从右上角开始顺时针绘制：右上 -> 左上圆角 -> 左下圆角 -> 右下 -> 闭合
        path.move(to: CGPoint(x: w, y: 0))
        path.addLine(to: CGPoint(x: r, y: 0))
        path.addArc(
            center: CGPoint(x: r, y: r),
            radius: r,
            startAngle: Angle(degrees: -90),
            endAngle: Angle(degrees: 180),
            clockwise: true
        )
        path.addLine(to: CGPoint(x: 0, y: h - r))
        path.addArc(
            center: CGPoint(x: r, y: h - r),
            radius: r,
            startAngle: Angle(degrees: 180),
            endAngle: Angle(degrees: 90),
            clockwise: true
        )
        path.addLine(to: CGPoint(x: w, y: h))
        path.closeSubpath()
        return path
    }
}

/// 书签边框路径：选中态仅绘制上、左、下三条边缘，右侧开口融入主面板
struct BookmarkBorderPath: Shape {
    var cornerRadius: CGFloat = 6
    var openRightSide: Bool = false

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let r = min(cornerRadius, min(w, h) / 2)

        path.move(to: CGPoint(x: w, y: 0))
        path.addLine(to: CGPoint(x: r, y: 0))
        path.addArc(
            center: CGPoint(x: r, y: r),
            radius: r,
            startAngle: Angle(degrees: -90),
            endAngle: Angle(degrees: 180),
            clockwise: true
        )
        path.addLine(to: CGPoint(x: 0, y: h - r))
        path.addArc(
            center: CGPoint(x: r, y: h - r),
            radius: r,
            startAngle: Angle(degrees: 180),
            endAngle: Angle(degrees: 90),
            clockwise: true
        )
        path.addLine(to: CGPoint(x: w, y: h))
        if !openRightSide {
            path.addLine(to: CGPoint(x: w, y: 0))
        }
        return path
    }
}

/// 挂靠在左侧边缘的外凸物理书签栏
struct ProviderBookmarkTabs: View {
    @ObservedObject var model: DashboardModel
    let selectedProvider: Provider
    let onSelect: (Provider) -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            ForEach(model.navigation.visibleProviders, id: \.self) { provider in
                ProviderBookmarkItem(
                    provider: provider,
                    isSelected: provider == selectedProvider,
                    status: model.snapshot(for: provider).status
                ) {
                    onSelect(provider)
                }
            }
        }
        .padding(.top, 10)
        .frame(width: 35, alignment: .trailing)
    }
}

/// 单项外凸物理书签组件
struct ProviderBookmarkItem: View {
    let provider: Provider
    let isSelected: Bool
    let status: ProviderStatus
    let action: () -> Void

    @State private var isHovered = false

    // 交互几何：选中时完全展开（35pt）并压入主面板 1pt；未选中时内敛（28pt），悬停时向左微弹（32pt）
    private var currentWidth: CGFloat {
        if isSelected {
            return 35
        }
        return isHovered ? 32 : 28
    }

    private var currentHeight: CGFloat {
        isSelected ? 38 : 33
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                // 书签底板背景：选中态采用主面板相同底色融为一体；未选中态采用次级深色
                BookmarkTabShape(cornerRadius: 6)
                    .fill(isSelected ? AppTheme.background : AppTheme.elevated.opacity(0.88))

                // 书签边框：选中态右侧开口（打通与主面板的接缝）；未选中态全闭合
                BookmarkBorderPath(cornerRadius: 6, openRightSide: isSelected)
                    .stroke(
                        isSelected ? AppTheme.hairlineBright : (isHovered ? AppTheme.hairlineBright.opacity(0.6) : AppTheme.hairline.opacity(0.5)),
                        lineWidth: 0.75
                    )

                // 居中 Provider 官方图标与微型指示
                HStack(spacing: 0) {
                    Spacer(minLength: 2)

                    ZStack(alignment: .bottomTrailing) {
                        // Provider 官方图标
                        if let icon = BundleImages.providerIcon(for: provider) {
                            Image(nsImage: icon)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 17, height: 17)
                                .opacity(isSelected ? 1.0 : (isHovered ? 0.95 : 0.6))
                        } else {
                            Image(systemName: provider.iconName)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppTheme.primaryText)
                                .opacity(isSelected ? 1.0 : (isHovered ? 0.95 : 0.6))
                        }

                        // 连接状态微型发光绿点（已连接时点亮）
                        if status == .connected {
                            Circle()
                                .fill(AppTheme.success)
                                .frame(width: 4.5, height: 4.5)
                                .shadow(color: AppTheme.success.opacity(0.6), radius: 1.5)
                                .offset(x: 2.5, y: 2)
                        }
                    }
                    .frame(width: 22, height: 22)

                    Spacer(minLength: 5)
                }
            }
            .frame(width: currentWidth, height: currentHeight)
            // 选中项向右延伸 1pt，精确遮盖主面板左边框
            .offset(x: isSelected ? 1 : 0)
            .contentShape(BookmarkTabShape(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.spring(response: 0.22, dampingFraction: 0.75)) {
                isHovered = hovering
            }
        }
        .help(provider.displayName)
    }
}
