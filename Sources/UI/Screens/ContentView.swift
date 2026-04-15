import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedSection: $appModel.selectedSection)
        } detail: {
            DetailContainerView()
                .environmentObject(appModel)
        }
        .navigationSplitViewStyle(.balanced)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppModel())
}

private struct DetailContainerView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        let selectedSection = appModel.selectedSection ?? .dashboard

        switch selectedSection {
        case .dashboard:
            DashboardView()
        case .hosts:
            HostsScreen()
        case .jobs:
            JobsScreen()
        case .settings:
            SettingsView()
        }
    }
}
