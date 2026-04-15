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
    private let sshService = SSHService()

    init() {
        loadHosts()
    }

    func addHost(from draft: HostDraft) {
        let newHost = draft.makeHost().withStatus(.checking)
        hosts.append(newHost)
        persistHosts()
        refreshHostStatus(for: newHost.id)
    }

    func deleteHosts(at offsets: IndexSet) {
        hosts.remove(atOffsets: offsets)
        persistHosts()
    }

    func reconnectHost(_ host: Host) {
        refreshHostStatus(for: host.id)
    }

    func loadHosts() {
        do {
            hosts = try hostStore.loadHosts()
            hostErrorMessage = nil
            refreshAllHostStatuses()
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

    private func refreshAllHostStatuses() {
        guard !hosts.isEmpty else {
            backendStatus = "No hosts registered"
            return
        }

        let ids = hosts.map(\.id)

        for id in ids {
            updateHostStatus(id: id, to: .checking, message: "Checking connection...")
        }

        backendStatus = "Checking \(ids.count) host(s)..."

        Task {
            await withTaskGroup(of: Void.self) { group in
                for id in ids {
                    group.addTask {
                        await self.checkHost(id: id)
                    }
                }
            }

            await MainActor.run {
                let connectedCount = hosts.filter { $0.status == .connected }.count
                backendStatus = "Host check finished: \(connectedCount)/\(hosts.count) connected"
                persistHosts()
            }
        }
    }

    private func refreshHostStatus(for hostID: UUID) {
        updateHostStatus(id: hostID, to: .checking, message: "Checking connection...")
        backendStatus = "Checking host connection..."

        Task {
            await checkHost(id: hostID)

            await MainActor.run {
                let connectedCount = hosts.filter { $0.status == .connected }.count
                backendStatus = "Host check finished: \(connectedCount)/\(hosts.count) connected"
                persistHosts()
            }
        }
    }

    private func checkHost(id: UUID) async {
        guard let host = await MainActor.run(body: { hosts.first(where: { $0.id == id }) }) else {
            return
        }

        do {
            let output = try await sshService.runConnectivityCheck(for: host)
            await MainActor.run {
                updateHostStatus(id: id, to: .connected, message: output)
            }
        } catch {
            await MainActor.run {
                updateHostStatus(id: id, to: .disconnected, message: error.localizedDescription)
            }
        }
    }

    private func updateHostStatus(id: UUID, to status: HostStatus, message: String? = nil) {
        guard let index = hosts.firstIndex(where: { $0.id == id }) else {
            return
        }

        hosts[index] = hosts[index].withStatus(status, message: message)
    }
}
