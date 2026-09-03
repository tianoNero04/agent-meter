import SwiftUI

/// 瑞士风格 Provider 图标方块：硬朗几何微圆角、紧凑发丝边框与纯正深色底衬
struct ProviderIconTile: View {
    let provider: Provider
    let size: CGFloat

    // 采用硬朗工业微圆角
    private var cornerRadius: CGFloat { 6.0 }

    var body: some View {
        ZStack {
            // 深邃暗色纯色底板
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(AppTheme.elevated)

            // Provider 专属图标位图
            if let icon = BundleImages.providerIcon(for: provider) {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 0.78, height: size * 0.78)
            } else {
                Image(systemName: provider.iconName)
                    .font(.system(size: size * 0.44, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
            }

            // 极细外框发丝线
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(AppTheme.hairlineBright, lineWidth: 0.75)
        }
        .frame(width: size, height: size)
    }
}
