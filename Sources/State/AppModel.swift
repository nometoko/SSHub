import Foundation

@MainActor
final class AppModel: ObservableObject {
    typealias LoadHostsAction = () throws -> [Host]
    typealias SaveHostsAction = ([Host]) throws -> Void
    typealias StorageDirectoryDescriptionAction = () -> String
    typealias ConnectivityCheckAction = (Host) async throws -> String

    @Published var selectedSection: SidebarSection? = .dashboard
    @Published var hosts: [Host] = []
    @Published var jobs: [Job] = Job.sampleData
    @Published var backendStatus: String = "macOS native skeleton ready"
    @Published var notificationSettings = NotificationSettings.sample
    @Published var hostErrorMessage: String?

    private let loadHostsAction: LoadHostsAction
    private let saveHostsAction: SaveHostsAction
    private let storageDirectoryDescriptionAction: StorageDirectoryDescriptionAction
    private let connectivityCheckAction: ConnectivityCheckAction

    init() {
        let hostStore = HostStore()
        let sshService = SSHService()
        loadHostsAction = hostStore.loadHosts
        saveHostsAction = hostStore.saveHosts
        storageDirectoryDescriptionAction = hostStore.storageDirectoryDescription
        connectivityCheckAction = sshService.runConnectivityCheck
        loadHosts()
    }

    init(
        loadHostsAction: @escaping LoadHostsAction,
        saveHostsAction: @escaping SaveHostsAction,
        storageDirectoryDescriptionAction: @escaping StorageDirectoryDescriptionAction,
        connectivityCheckAction: @escaping ConnectivityCheckAction
    ) {
        self.loadHostsAction = loadHostsAction
        self.saveHostsAction = saveHostsAction
        self.storageDirectoryDescriptionAction = storageDirectoryDescriptionAction
        self.connectivityCheckAction = connectivityCheckAction
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
            username: {
                let trimmedUsername = draft.username.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmedUsername.isEmpty ? nil : trimmedUsername
            }(),
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
        guard let index = hosts.firstIndex(where: { $0.id == host.id }) else {
            return
        }

        deleteHosts(at: IndexSet(integer: index))
    }

    func reconnectHost(_ host: Host) {
        refreshHostStatus(for: host.id)
    }

    func loadHosts() {
        do {
            hosts = try loadHostsAction()
            hostErrorMessage = nil
            refreshAllHostStatuses()
        } catch {
            hosts = []
            hostErrorMessage = error.localizedDescription
        }
    }

    func storageDirectoryDescription() -> String {
        storageDirectoryDescriptionAction()
    }

    private func persistHosts() {
        do {
            try saveHostsAction(hosts)
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
            let output = try await connectivityCheckAction(host)
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
