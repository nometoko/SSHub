import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        Form {
            Section("Notifications") {
                TextField("Slack Webhook URL", text: $appModel.notificationSettings.slackWebhookURL)
                Toggle("Notify on job completed", isOn: $appModel.notificationSettings.notifyOnCompleted)
                Toggle("Notify on job failed", isOn: $appModel.notificationSettings.notifyOnFailed)
            }

            Section("Storage") {
                Text(appModel.storageDirectoryDescription())
                    .font(.system(.body, design: .monospaced))
            }
        }
        .formStyle(.grouped)
        .padding(20)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppModel())
}
