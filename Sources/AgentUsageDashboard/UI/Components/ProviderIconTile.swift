import SwiftUI

/// 粗野主义 Provider 图标方块：纯正克莱因蓝底板、1.25pt 纯黑外框与 1.5pt 硬阴影
struct ProviderIconTile: View {
    let provider: Provider
    let size: CGFloat

    // 粗野主义紧凑微圆角
    private var cornerRadius: CGFloat { 4.0 }

    var body: some View {
        ZStack {
            // 纯正克莱因蓝高饱和底板
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(AppTheme.kleinBlue)

            // Provider 专属图标位图（在克莱因蓝底上醒目反白）
            if let icon = BundleImages.providerIcon(for: provider) {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 0.78, height: size * 0.78)
            } else {
                Image(systemName: provider.iconName)
                    .font(.system(size: size * 0.44, weight: .bold))
                    .foregroundStyle(Color.white)
            }

            // 粗野主义 1.25pt 纯黑外框
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1.25)
        }
        .frame(width: size, height: size)
        .shadow(color: Color.black.opacity(0.85), radius: 0, x: 1.5, y: 1.5)
    }
}
