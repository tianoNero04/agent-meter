import SwiftUI

/// hero 卡 provider 图标块：图标铺满整个 tile、边缘与框重合，
/// 深色玻璃底 + 顶部玻璃高光描边压在图标上做出质感。所有 provider 共用同一套样式。
struct ProviderIconTile: View {
    let provider: Provider
    let size: CGFloat

    private var cornerRadius: CGFloat { size * 0.20 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(LinearGradient(
                    colors: [
                        Color(red: 12 / 255, green: 20 / 255, blue: 32 / 255),
                        Color(red: 3 / 255, green: 6 / 255, blue: 13 / 255)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ))

            if let icon = BundleImages.providerIcon(for: provider) {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            } else {
                Image(systemName: provider.iconName)
                    .font(.system(size: size * 0.4, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.92))
                    .shadow(color: Color.white.opacity(0.35), radius: 4)
            }

            // 玻璃高光：顶边亮、向下渐隐的描边 + 顶部柔光，压在图标上
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.38), Color.white.opacity(0.06)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.30), Color.clear],
                        startPoint: .top,
                        endPoint: .center
                    ),
                    lineWidth: 1.5
                )
                .blur(radius: 2.5)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
