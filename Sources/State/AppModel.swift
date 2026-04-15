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
    @Published var jobErrorMessage: String?

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
        let blockedHostNames = offsets.compactMap { index -> String? in
            guard hosts.indices.contains(index) else {
                return nil
            }

            let host = hosts[index]
            return hasRunningJob(for: host.id) ? host.name : nil
        }

        if !blockedHostNames.isEmpty {
            if blockedHostNames.count == 1, let hostName = blockedHostNames.first {
                hostErrorMessage = "Stop running jobs on \(hostName) before removing this host."
            } else {
                hostErrorMessage = "Stop running jobs on the selected hosts before removing them."
            }
            return
        }

        hostErrorMessage = nil
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

    func addJob(from draft: JobDraft) {
        guard
            let hostID = draft.hostID,
            let host = hosts.first(where: { $0.id == hostID })
        else {
            jobErrorMessage = "Select an existing host before launching the job."
            return
        }

        jobErrorMessage = nil

        let trimmedWorkingDirectory = draft.workingDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
        let job = Job(
            id: UUID(),
            name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
            hostID: host.id,
            hostName: host.name,
            status: .running,
            progressSummary: "Launching...",
            startedAt: .now,
            command: draft.command.trimmingCharacters(in: .whitespacesAndNewlines),
            workingDirectory: trimmedWorkingDirectory.isEmpty ? nil : trimmedWorkingDirectory,
            pid: Int.random(in: 10_000...99_999)
        )

        jobs.insert(job, at: 0)
    }

    func updateJob(_ job: Job, from draft: JobDraft) {
        guard let index = jobs.firstIndex(where: { $0.id == job.id }) else {
            return
        }

        guard
            let hostID = draft.hostID,
            let host = hosts.first(where: { $0.id == hostID })
        else {
            jobErrorMessage = "Select an existing host before saving the job."
            return
        }

        jobErrorMessage = nil

        let currentJob = jobs[index]
        let trimmedWorkingDirectory = draft.workingDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
        jobs[index] = Job(
            id: currentJob.id,
            name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
            hostID: host.id,
            hostName: host.name,
            status: currentJob.status,
            progressSummary: currentJob.progressSummary,
            startedAt: currentJob.startedAt,
            command: draft.command.trimmingCharacters(in: .whitespacesAndNewlines),
            workingDirectory: trimmedWorkingDirectory.isEmpty ? nil : trimmedWorkingDirectory,
            pid: currentJob.pid
        )
    }

    func deleteJob(_ job: Job) {
        guard let index = jobs.firstIndex(where: { $0.id == job.id }) else {
            return
        }

        jobs.remove(at: index)
    }

    func stopJob(_ job: Job) {
        setJobStatus(
            jobID: job.id,
            status: .stopped,
            progressSummary: "Stopped by user"
        )
    }

    func restartJob(_ job: Job) {
        setJobStatus(
            jobID: job.id,
            status: .running,
            progressSummary: "Restart requested"
        )
    }

    func completeJob(_ job: Job) {
        setJobStatus(
            jobID: job.id,
            status: .completed,
            progressSummary: "Completed successfully"
        )
    }

    func failJob(_ job: Job) {
        setJobStatus(
            jobID: job.id,
            status: .failed,
            progressSummary: "Failure detected"
        )
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

    private func setJobStatus(jobID: UUID, status: JobStatus, progressSummary: String) {
        guard let index = jobs.firstIndex(where: { $0.id == jobID }) else {
            return
        }

        let job = jobs[index]
        jobs[index] = Job(
            id: job.id,
            name: job.name,
            hostID: job.hostID,
            hostName: job.hostName,
            status: status,
            progressSummary: progressSummary,
            startedAt: job.startedAt,
            command: job.command,
            workingDirectory: job.workingDirectory,
            pid: job.pid
        )
    }

    private func hasRunningJob(for hostID: UUID) -> Bool {
        jobs.contains(where: { $0.hostID == hostID && $0.status == .running })
    }
}
