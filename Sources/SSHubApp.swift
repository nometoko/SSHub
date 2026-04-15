import SwiftUI

@main
struct SSHubApp: App {
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        WindowGroup("SSHub") {
            ContentView()
                .environmentObject(appModel)
                .frame(minWidth: 1100, minHeight: 720)
        }
        .defaultSize(width: 1280, height: 820)

        Settings {
            SettingsView()
                .environmentObject(appModel)
                .frame(width: 520, height: 360)
        }
    }
}
