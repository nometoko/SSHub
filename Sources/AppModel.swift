import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published var selectedSection: SidebarSection? = .dashboard
    @Published var hosts: [Host] = []
    @Published var jobs: [Job] = Job.sampleData
    @Published var backendStatus: String = "macOS native skeleton ready"
    @Published var notificationSettings = NotificationSettings.sample
    @Published var hostErrorMessage: String?

    private let hostStore = HostStore()

    init() {
        loadHosts()
    }

    func addHost(from draft: HostDraft) {
        let newHost = draft.makeHost()
        hosts.append(newHost)
        persistHosts()
    }

    func deleteHosts(at offsets: IndexSet) {
        hosts.remove(atOffsets: offsets)
        persistHosts()
    }

    func loadHosts() {
        do {
            hosts = try hostStore.loadHosts()
            hostErrorMessage = nil
        } catch {
            hosts = []
            hostErrorMessage = error.localizedDescription
        }
    }

    func storageDirectoryDescription() -> String {
        hostStore.storageDirectoryDescription()
    }

    private func persistHosts() {
        do {
            try hostStore.saveHosts(hosts)
            hostErrorMessage = nil
        } catch {
            hostErrorMessage = error.localizedDescription
        }
    }
}
