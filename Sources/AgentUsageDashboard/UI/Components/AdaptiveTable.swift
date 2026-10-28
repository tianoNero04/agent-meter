import SwiftUI

/// 窄窗口保留可读列宽，横向滚动显示完整表格。
struct AdaptiveTable<Content: View>: View {
    let minimumWidth: CGFloat
    let content: Content

    init(minimumWidth: CGFloat, @ViewBuilder content: () -> Content) {
        self.minimumWidth = minimumWidth
        self.content = content()
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            content.frame(minWidth: minimumWidth)
            VStack(alignment: .leading, spacing: 8) {
                Label("横向滚动查看完整表格", systemImage: "arrow.left.and.right")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.secondaryText)
                    .padding(.horizontal, 12)
                ScrollView(.horizontal) { content.frame(width: minimumWidth) }
            }
        }
    }
}
