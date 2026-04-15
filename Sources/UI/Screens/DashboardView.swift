import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HeroView(statusText: appModel.backendStatus)

                HStack(alignment: .top, spacing: 20) {
                    HostListView(hosts: appModel.hosts)
                        .environmentObject(appModel)
                    JobDashboardView(jobs: appModel.jobs, hosts: appModel.hosts, sessions: appModel.sessions)
                }
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

#Preview {
    DashboardView()
        .environmentObject(AppModel())
}
