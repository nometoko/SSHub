import SwiftUI

struct JobsScreen: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        ScrollView {
            JobDashboardView(jobs: appModel.jobs)
                .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

#Preview {
    JobsScreen()
        .environmentObject(AppModel())
}
