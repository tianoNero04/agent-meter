import SwiftUI
import AppKit

public struct AgentUsageDashboardApp: App {
    @StateObject private var model: DashboardModel

    public init() {
        let model = AppDependencies().makeModel()
        _model = StateObject(wrappedValue: model)
        NSApplication.shared.setActivationPolicy(.accessory)
        model.start()
    }

    public var body: some Scene {
        MenuBarExtra {
            PopoverView(model: model)
        } label: {
            if let icon = BundleImages.menuBarIcon {
                Image(nsImage: icon)
            } else {
                Image(systemName: "gauge")
                    .symbolRenderingMode(.hierarchical)
            }
        }
        .menuBarExtraStyle(.window)

        Window("详细统计", id: "details") {
            DetailsView(model: model)
        }
        .defaultSize(width: 760, height: 560)

        Window("", id: "master") {
            MasterDashboardView(model: model)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 780, height: 520)

        Window("", id: "menu") {
            MasterDashboardView(model: model)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 780, height: 520)
    }
}
