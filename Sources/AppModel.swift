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

    func updateHost(_ host: Host, from draft: HostDraft) {
        guard let index = hosts.firstIndex(where: { $0.id == host.id }) else {
            return
        }

        let updatedHost = Host(
            id: host.id,
            name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
            hostAlias: draft.hostAlias.trimmingCharacters(in: .whitespacesAndNewlines),
            username: draft.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : draft.username.trimmingCharacters(in: .whitespacesAndNewlines),
            port: {
                let trimmedPort = draft.portText.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmedPort.isEmpty ? nil : Int(trimmedPort)
            }(),
            status: .checking,
            statusMessage: "Checking reachability...",
            lastCheckedAt: host.lastCheckedAt
        )

        hosts[index] = updatedHost
        persistHosts()
        refreshHostStatus(for: host.id)
    }

    func deleteHosts(at offsets: IndexSet) {
        hosts.remove(atOffsets: offsets)
        persistHosts()
    }

    func deleteHost(_ host: Host) {
        guard let index = hosts.firstIndex(of: host) else {
            return
        }

        deleteHosts(at: IndexSet(integer: index))
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
            updateHostStatus(id: id, to: .checking, message: "Checking reachability...")
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
                let reachableCount = hosts.filter { $0.status == .reachable }.count
                backendStatus = "Reachability check finished: \(reachableCount)/\(hosts.count) reachable"
                persistHosts()
            }
        }
    }

    private func refreshHostStatus(for hostID: UUID) {
        updateHostStatus(id: hostID, to: .checking, message: "Checking reachability...")
        backendStatus = "Checking host reachability..."

        Task {
            await checkHost(id: hostID)

            await MainActor.run {
                let reachableCount = hosts.filter { $0.status == .reachable }.count
                backendStatus = "Reachability check finished: \(reachableCount)/\(hosts.count) reachable"
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
                updateHostStatus(id: id, to: .reachable, message: output, lastCheckedAt: .now)
            }
        } catch {
            await MainActor.run {
                updateHostStatus(id: id, to: .unreachable, message: error.localizedDescription, lastCheckedAt: .now)
            }
        }
    }

    private func updateHostStatus(id: UUID, to status: HostStatus, message: String? = nil, lastCheckedAt: Date? = nil) {
        guard let index = hosts.firstIndex(where: { $0.id == id }) else {
            return
        }

        let checkedAt = lastCheckedAt ?? hosts[index].lastCheckedAt
        hosts[index] = hosts[index].withStatus(status, message: message, lastCheckedAt: checkedAt)
    }
}
