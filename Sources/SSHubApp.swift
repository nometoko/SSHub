import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first?.makeKeyAndOrderFront(nil)
    }
}

@main
struct SSHubApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
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
