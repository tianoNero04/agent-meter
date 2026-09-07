import SwiftUI

/// 现代暗黑风格日夜模式切换图标按钮（复刻 ReactBits 导航栏主题切换交互）
struct ThemeToggleButton: View {
    @State private var isHovered = false
    @State private var showHint = false

    var body: some View {
        HStack(spacing: 6) {
            // 点击时的轻量提示气泡（避免侵入式弹窗）
            if showHint {
                Text("日间模式适配中")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(red: 251/255, green: 113/255, blue: 133/255))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(red: 24/255, green: 24/255, blue: 27/255))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color(red: 39/255, green: 39/255, blue: 42/255), lineWidth: 1)
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }

            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                    showHint = true
                }
                // 1.8 秒后自动淡出提示
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showHint = false
                    }
                }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isHovered ? Color(red: 39/255, green: 39/255, blue: 42/255) : Color(red: 18/255, green: 18/255, blue: 20/255))
                        .frame(width: 28, height: 28)
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(isHovered ? Color.white.opacity(0.2) : Color(red: 39/255, green: 39/255, blue: 42/255), lineWidth: 1)
                        )

                    // 沉浸式夜间模式月亮图标
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(isHovered ? .white : Color(red: 161/255, green: 161/255, blue: 170/255))
                }
            }
            .buttonStyle(.plain)
            .onHover { isHovered = $0 }
            .help("日夜模式切换（当前为夜间深色模式，日间模式敬请期待）")
        }
    }
}
