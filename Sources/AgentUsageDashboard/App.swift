import SwiftUI
import AppKit
import ServiceManagement

@main
struct AgentUsageDashboardApp: App {
    @StateObject private var model: DashboardModel

    init() {
        let model = DashboardModel()
        _model = StateObject(wrappedValue: model)
        NSApplication.shared.setActivationPolicy(.accessory)
        try? SMAppService.mainApp.register()
        model.start()
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverView(model: model)
        } label: {
            Image(systemName: "gauge")
                .symbolRenderingMode(.hierarchical)
        }
        .menuBarExtraStyle(.window)

        Window("详细统计", id: "details") {
            DetailsView(model: model)
        }
        .defaultSize(width: 760, height: 560)
    }
}
