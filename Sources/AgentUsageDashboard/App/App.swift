import SwiftUI
import AppKit
import ServiceManagement

public struct AgentUsageDashboardApp: App {
    @StateObject private var model: DashboardModel

    public init() {
        let model = AppDependencies().makeModel()
        _model = StateObject(wrappedValue: model)
        NSApplication.shared.setActivationPolicy(.accessory)
        try? SMAppService.mainApp.register()
        model.start()
    }

    public var body: some Scene {
        MenuBarExtra {
            PopoverView(model: model)
        } label: {
            // 优先使用 App 的自适应 Logo 作为菜单栏常驻图标，缺失时回退到系统仪表盘图标
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

        Window("设置", id: "settings") {
            SettingsPlaceholderView()
        }
        .defaultSize(width: 460, height: 280)
    }
}
