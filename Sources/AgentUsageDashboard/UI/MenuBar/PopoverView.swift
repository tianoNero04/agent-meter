import SwiftUI
import AppKit

enum PopoverSection: Hashable {
    case provider(Provider)
}

struct PopoverView: View {
    @ObservedObject var model: DashboardModel
    @Environment(\.openWindow) private var openWindow
    @State private var selectedSection: PopoverSection = .provider(.codex)
    @State private var slideEdge: Edge = .trailing

    var body: some View {
        ZStack {
            SciFiBackdrop()
            VStack(spacing: 0) {
                PopoverTopBar(model: model, selection: $selectedSection, openSettings: openWindow) { provider in
                    selectProvider(provider)
                }
                .padding(.horizontal, 12)
                ProviderPanel(snapshot: model.snapshot(for: selectedProvider), refresh: { model.refresh() }, slideEdge: slideEdge)
                    .padding(.horizontal, 12)
                    .padding(.top, 17)
                    .padding(.bottom, 15.5)
            }
        }
        .frame(width: 390, height: 425)
        .preferredColorScheme(.dark)
        .onAppear {
            restoreSelection()
            normalizeSelection()
            model.refresh()
        }
        .onChange(of: model.navigation.visibleProviders) { _ in normalizeSelection() }
    }

    private func selectProvider(_ provider: Provider) {
        let order = model.navigation.visibleProviders
        let oldIndex = order.firstIndex(of: selectedProvider) ?? 0
        let newIndex = order.firstIndex(of: provider) ?? 0
        slideEdge = newIndex >= oldIndex ? .trailing : .leading
        withAnimation(.easeInOut(duration: 0.25)) {
            selectedSection = .provider(provider)
        }
        model.selectProvider(provider)
    }

    private var selectedProvider: Provider {
        if case let .provider(provider) = normalizedSection { return provider }
        return model.navigation.visibleProviders.first ?? .codex
    }

    private var normalizedSection: PopoverSection {
        guard case let .provider(provider) = selectedSection else { return selectedSection }
        return model.navigation.isEnabled(provider) ? .provider(provider) : .provider(.codex)
    }

    private func normalizeSelection() {
        guard case let .provider(provider) = selectedSection, !model.navigation.isEnabled(provider) else { return }
        selectedSection = .provider(model.navigation.visibleProviders.first ?? .codex)
    }

    private func restoreSelection() {
        guard let provider = model.navigation.selectedProvider, model.navigation.isEnabled(provider) else { return }
        selectedSection = .provider(provider)
    }
}

struct PopoverTopBar: View {
    @ObservedObject var model: DashboardModel
    @Binding var selection: PopoverSection
    let openSettings: OpenWindowAction
    let onSelect: (Provider) -> Void

    var body: some View {
        ZStack {
            if let background = BundleImages.navBarBackground {
                Image(nsImage: background)
                    .resizable()
                    .scaledToFill()
            } else {
                Capsule(style: .continuous)
                    .fill(Color.black.opacity(0.26))
                    .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.20), lineWidth: 1))
            }
            HStack(spacing: 0) {
                PopoverHeader(openSettings: openSettings)
                    .padding(.leading, 14)
                Spacer().frame(width: 16)
                ProviderNavigationBar(model: model, selection: $selection, onSelect: onSelect)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 48.5)
    }
}

struct SciFiBackdrop: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 8 / 255, green: 14 / 255, blue: 24 / 255),
                Color(red: 2 / 255, green: 5 / 255, blue: 12 / 255)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}
