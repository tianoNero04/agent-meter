import SwiftUI

struct ProviderIconTile: View {
    let provider: Provider
    let size: CGFloat
    var cornerRadius: CGFloat = AppTheme.geometricRadius

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(AppTheme.elevated)
            if let icon = BundleImages.providerIcon(for: provider) {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            } else {
                Image(systemName: provider.iconName)
                    .font(.system(size: size * 0.48, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
            }
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 0.75)
        }
        .frame(width: size, height: size)
    }
}
