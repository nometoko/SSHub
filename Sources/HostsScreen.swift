import SwiftUI

struct HostsScreen: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        ScrollView {
            HostListView(
                hosts: appModel.hosts,
                layout: .full
            )
                .environmentObject(appModel)
                .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

#Preview {
    HostsScreen()
        .environmentObject(AppModel())
}
