import SwiftUI

struct OverviewTab: View {
    @ObservedObject var model: DashboardModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("账号额度与 Token 趋势").font(.title2.weight(.semibold))
                ForEach(snapshots, id: \.provider) { snapshot in ProviderTrendCard(snapshot: snapshot) }
            }
        }
    }
    private var snapshots: [ProviderSnapshot] { model.navigation.visibleProviders.map { model.snapshot(for: $0) } }
}
