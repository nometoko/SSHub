import Foundation
import XCTest
@testable import SSHub

// swiftlint:disable type_body_length file_length function_body_length
final class AppModelTests: XCTestCase {
    func testLoadHostsWithNoHostsSetsNoHostsBackendStatus() async {
        let model = await MainActor.run {
            AppModel(
                loadHostsAction: { [] },
                saveHostsAction: { _ in },
                storageDirectoryDescriptionAction: { "/tmp/SSHub" },
                connectivityCheckAction: { _ in "Reachability check OK" }
            )
        }

        let state = await MainActor.run {
            (model.hosts, model.backendStatus, model.hostErrorMessage)
        }

        XCTAssertTrue(state.0.isEmpty)
        XCTAssertEqual(state.1, "No hosts registered")
        XCTAssertNil(state.2)
    }

    func testAddHostPersistsAndRefreshesReachableStatus() async throws {
        let recorder = SaveRecorder()
        let checker = ConnectivityCheckRecorder(result: .success("ok"))
        let model = await MainActor.run {
            AppModel(
                loadHostsAction: { [] },
                saveHostsAction: recorder.save(hosts:),
                storageDirectoryDescriptionAction: { "/tmp/SSHub" },
                connectivityCheckAction: { host in
                    try await checker.run(host: host)
                }
            )
        }

        var draft = HostDraft()
        draft.name = " gpu-01 "
        draft.hostAlias = " login-node "
        draft.username = " iwamoto "
        draft.portText = " 2222 "

        let draftToAdd = draft

        await MainActor.run {
            model.addHost(from: draftToAdd)
        }

        try await waitUntil {
            let host = await MainActor.run { model.hosts.first }
            return host?.status == .reachable
        }

        let state = await MainActor.run {
            (
                model.hosts,
                model.backendStatus,
                model.hostErrorMessage,
                model.storageDirectoryDescription()
            )
        }

        XCTAssertEqual(state.0.count, 1)
        XCTAssertEqual(state.0[0].name, "gpu-01")
        XCTAssertEqual(state.0[0].hostAlias, "login-node")
        XCTAssertEqual(state.0[0].username, "iwamoto")
        XCTAssertEqual(state.0[0].port, 2222)
        XCTAssertEqual(state.0[0].status, HostStatus.reachable)
        XCTAssertEqual(state.0[0].statusMessage, "ok")
        XCTAssertEqual(state.1, "Reachability check finished: 1/1 reachable")
        XCTAssertNil(state.2)
        XCTAssertEqual(state.3, "/tmp/SSHub")
        let checkedHostAliases = await checker.checkedHostAliases()
        XCTAssertEqual(checkedHostAliases, ["login-node"])

        let savedSnapshots = recorder.snapshots()
        XCTAssertGreaterThanOrEqual(savedSnapshots.count, 2)
        XCTAssertEqual(savedSnapshots.last?.first?.status, HostStatus.reachable)
    }

    func testUpdateHostKeepsIdentifierAndAppliesTrimmedOverrides() async throws {
        let recorder = SaveRecorder()
        let checker = ConnectivityCheckRecorder(result: .success("Reachability check OK"))
        let hostID = UUID()
        let initialHost = Host(
            id: hostID,
            name: "gpu-01",
            hostAlias: "gpu-01",
            username: "old-user",
            port: 2200,
            status: .unknown,
            statusMessage: nil,
            lastCheckedAt: nil
        )
        let model = await MainActor.run {
            AppModel(
                loadHostsAction: { [] },
                saveHostsAction: recorder.save(hosts:),
                storageDirectoryDescriptionAction: { "/tmp/SSHub" },
                connectivityCheckAction: { host in
                    try await checker.run(host: host)
                }
            )
        }

        await MainActor.run {
            model.hosts = [initialHost]
        }

        var draft = HostDraft()
        draft.name = " gpu-02 "
        draft.hostAlias = " login-02 "
        draft.username = "   "
        draft.portText = " 2202 "

        let updateDraft = draft

        await MainActor.run {
            model.updateHost(initialHost, from: updateDraft)
        }

        try await waitUntil {
            let host = await MainActor.run { model.hosts.first }
            return host?.status == .reachable
        }

        let updatedHost = await MainActor.run { model.hosts.first }

        XCTAssertEqual(updatedHost?.id, hostID)
        XCTAssertEqual(updatedHost?.name, "gpu-02")
        XCTAssertEqual(updatedHost?.hostAlias, "login-02")
        XCTAssertNil(updatedHost?.username)
        XCTAssertEqual(updatedHost?.port, 2202)
        XCTAssertEqual(updatedHost?.status, HostStatus.reachable)
        XCTAssertEqual(updatedHost?.statusMessage, "Reachability check OK")

        let savedSnapshots = recorder.snapshots()
        XCTAssertEqual(savedSnapshots.last?.first?.id, hostID)
    }

    func testReconnectHostMarksHostUnreachableWhenCheckFails() async throws {
        let checker = ConnectivityCheckRecorder(
            result: .failure(SSHServiceError.connectivityCheckFailed("Permission denied"))
        )
        let model = await MainActor.run {
            AppModel(
                loadHostsAction: { [] },
                saveHostsAction: { _ in },
                storageDirectoryDescriptionAction: { "/tmp/SSHub" },
                connectivityCheckAction: { host in
                    try await checker.run(host: host)
                }
            )
        }
        let host = Host(
            id: UUID(),
            name: "gpu-01",
            hostAlias: "gpu-01",
            username: nil,
            port: nil,
            status: .unknown,
            statusMessage: nil,
            lastCheckedAt: nil
        )

        await MainActor.run {
            model.hosts = [host]
            model.reconnectHost(host)
        }

        try await waitUntil {
            let refreshedHost = await MainActor.run { model.hosts.first }
            return refreshedHost?.status == .unreachable
        }

        let refreshedHost = await MainActor.run { model.hosts.first }
        let backendStatus = await MainActor.run { model.backendStatus }

        XCTAssertEqual(refreshedHost?.status, HostStatus.unreachable)
        XCTAssertEqual(refreshedHost?.statusMessage, "Permission denied")
        XCTAssertNotNil(refreshedHost?.lastCheckedAt)
        XCTAssertEqual(backendStatus, "Reachability check finished: 0/1 reachable")
    }

    func testDeleteHostMatchesByIdentifier() async {
        let hostID = UUID()
        let model = await MainActor.run {
            AppModel(
                loadHostsAction: { [] },
                saveHostsAction: { _ in },
                storageDirectoryDescriptionAction: { "/tmp/SSHub" },
                connectivityCheckAction: { _ in "ok" }
            )
        }
        let primaryHost = Host(
            id: hostID,
            name: "gpu-01",
            hostAlias: "gpu-01",
            username: nil,
            port: nil,
            status: .reachable,
            statusMessage: "Reachability check OK",
            lastCheckedAt: Date()
        )
        let secondaryHost = Host(
            id: UUID(),
            name: "gpu-02",
            hostAlias: "gpu-02",
            username: nil,
            port: nil,
            status: .unknown,
            statusMessage: nil,
            lastCheckedAt: nil
        )
        let staleCopy = Host(
            id: hostID,
            name: "gpu-01",
            hostAlias: "gpu-01",
            username: "different",
            port: 2222,
            status: .unreachable,
            statusMessage: "Timed out",
            lastCheckedAt: nil
        )

        await MainActor.run {
            model.hosts = [primaryHost, secondaryHost]
            model.jobs = [
                Job(
                    id: UUID(),
                    name: "train-resnet50",
                    hostID: primaryHost.id,
                    hostName: primaryHost.name,
                    status: .failed,
                    progressSummary: "Launching...",
                    startedAt: Date(timeIntervalSince1970: 100),
                    command: "python train.py",
                    workingDirectory: nil,
                    pid: 12345
                )
            ]
            model.deleteHost(staleCopy)
        }

        let state = await MainActor.run { (model.hosts, model.jobs) }

        let remainingHosts = state.0
        XCTAssertEqual(remainingHosts, [secondaryHost])
        XCTAssertEqual(state.1.first?.hostID, primaryHost.id)
        XCTAssertEqual(state.1.first?.hostName, primaryHost.name)
    }

    func testLoadHostsFailureSurfacesError() async {
        let model = await MainActor.run {
            AppModel(
                loadHostsAction: {
                    throw TestError.sample
                },
                saveHostsAction: { _ in },
                storageDirectoryDescriptionAction: { "/tmp/SSHub" },
                connectivityCheckAction: { _ in "ok" }
            )
        }

        let state = await MainActor.run {
            (model.hosts, model.hostErrorMessage)
        }

        XCTAssertTrue(state.0.isEmpty)
        XCTAssertEqual(state.1, TestError.sample.localizedDescription)
    }

    func testLoadHostsRefreshesAllStatusesAndPersistsResults() async throws {
        let recorder = SaveRecorder()
        let checker = ConnectivityCheckRecorder(
            resultsByAlias: [
                "gpu-01": .success("ok"),
                "gpu-02": .failure(SSHServiceError.connectivityCheckFailed("Timed out"))
            ]
        )
        let hosts = [
            Host(
                id: UUID(),
                name: "gpu-01",
                hostAlias: "gpu-01",
                username: nil,
                port: nil,
                status: .unknown,
                statusMessage: nil,
                lastCheckedAt: nil
            ),
            Host(
                id: UUID(),
                name: "gpu-02",
                hostAlias: "gpu-02",
                username: nil,
                port: nil,
                status: .unknown,
                statusMessage: nil,
                lastCheckedAt: nil
            )
        ]

        let model = await MainActor.run {
            AppModel(
                loadHostsAction: { hosts },
                saveHostsAction: recorder.save(hosts:),
                storageDirectoryDescriptionAction: { "/tmp/SSHub" },
                connectivityCheckAction: { host in
                    try await checker.run(host: host)
                }
            )
        }

        try await waitUntil {
            let currentHosts = await MainActor.run { model.hosts }
            return currentHosts.contains { $0.status == .reachable }
                && currentHosts.contains { $0.status == .unreachable }
        }

        let state = await MainActor.run {
            (model.hosts, model.backendStatus, model.hostErrorMessage)
        }

        XCTAssertEqual(state.0.count, 2)
        XCTAssertEqual(state.0.first(where: { $0.hostAlias == "gpu-01" })?.status, .reachable)
        XCTAssertEqual(state.0.first(where: { $0.hostAlias == "gpu-02" })?.status, .unreachable)
        XCTAssertEqual(state.0.first(where: { $0.hostAlias == "gpu-02" })?.statusMessage, "Timed out")
        XCTAssertEqual(state.1, "Reachability check finished: 1/2 reachable")
        XCTAssertNil(state.2)
        XCTAssertEqual(recorder.snapshots().last?.count, 2)
    }

    func testDeleteHostsPersistsRemainingHosts() async {
        let recorder = SaveRecorder()
        let model = await MainActor.run {
            AppModel(
                loadHostsAction: { [] },
                saveHostsAction: recorder.save(hosts:),
                storageDirectoryDescriptionAction: { "/tmp/SSHub" },
                connectivityCheckAction: { _ in "ok" }
            )
        }
        let hosts = [
            Host(
                id: UUID(),
                name: "gpu-01",
                hostAlias: "gpu-01",
                username: nil,
                port: nil,
                status: .unknown,
                statusMessage: nil,
                lastCheckedAt: nil
            ),
            Host(
                id: UUID(),
                name: "gpu-02",
                hostAlias: "gpu-02",
                username: nil,
                port: nil,
                status: .unknown,
                statusMessage: nil,
                lastCheckedAt: nil
            )
        ]

        await MainActor.run {
            model.hosts = hosts
            model.deleteHosts(at: IndexSet(integer: 0))
        }

        let remainingHosts = await MainActor.run { model.hosts }

        XCTAssertEqual(remainingHosts, [hosts[1]])
        XCTAssertEqual(recorder.snapshots().last, [hosts[1]])
    }

    func testPersistFailureSurfacesErrorMessage() async {
        let model = await MainActor.run {
            AppModel(
                loadHostsAction: { [] },
                saveHostsAction: { _ in
                    throw TestError.sample
                },
                storageDirectoryDescriptionAction: { "/tmp/SSHub" },
                connectivityCheckAction: { _ in "ok" }
            )
        }

        var draft = HostDraft()
        draft.name = "gpu-01"
        draft.hostAlias = "gpu-01"
        let addDraft = draft

        await MainActor.run {
            model.addHost(from: addDraft)
        }

        let hostErrorMessage = await MainActor.run { model.hostErrorMessage }
        XCTAssertEqual(hostErrorMessage, TestError.sample.localizedDescription)
    }

    func testUpdateAndDeleteMissingHostLeaveStateUnchanged() async {
        let model = await MainActor.run {
            AppModel(
                loadHostsAction: { [] },
                saveHostsAction: { _ in },
                storageDirectoryDescriptionAction: { "/tmp/SSHub" },
                connectivityCheckAction: { _ in "ok" }
            )
        }
        let existingHost = Host(
            id: UUID(),
            name: "gpu-01",
            hostAlias: "gpu-01",
            username: nil,
            port: nil,
            status: .unknown,
            statusMessage: nil,
            lastCheckedAt: nil
        )
        let missingHost = Host(
            id: UUID(),
            name: "missing",
            hostAlias: "missing",
            username: nil,
            port: nil,
            status: .unknown,
            statusMessage: nil,
            lastCheckedAt: nil
        )
        var draft = HostDraft()
        draft.name = "updated"
        draft.hostAlias = "updated"
        let updateDraft = draft

        await MainActor.run {
            model.hosts = [existingHost]
            model.updateHost(missingHost, from: updateDraft)
            model.deleteHost(missingHost)
            model.reconnectHost(missingHost)
        }

        try? await Task.sleep(nanoseconds: 50_000_000)

        let currentHosts = await MainActor.run { model.hosts }
        XCTAssertEqual(currentHosts, [existingHost])
    }

    func testAddJobUsesSelectedHostIdentityAndTrimsFields() async {
        let model = await MainActor.run {
            AppModel(
                loadHostsAction: { [] },
                saveHostsAction: { _ in },
                storageDirectoryDescriptionAction: { "/tmp/SSHub" },
                connectivityCheckAction: { _ in "ok" }
            )
        }
        let host = Host(
            id: UUID(),
            name: "gpu-01",
            hostAlias: "gpu-01",
            username: nil,
            port: nil,
            status: .reachable,
            statusMessage: nil,
            lastCheckedAt: nil
        )

        await MainActor.run {
            model.hosts = [host]
            model.sessions = [makeSession(for: host, name: "vision-lab")]
            model.jobs = []
        }

        var draft = JobDraft()
        draft.name = " train-resnet50 "
        draft.hostID = host.id
        draft.sessionID = host.id
        draft.command = " python train.py "
        draft.workingDirectory = " ~/workspace "
        let addDraft = draft

        await MainActor.run {
            model.addJob(from: addDraft)
        }

        let job = await MainActor.run { model.jobs.first }
        XCTAssertEqual(job?.name, "train-resnet50")
        XCTAssertEqual(job?.hostID, host.id)
        XCTAssertEqual(job?.hostName, "gpu-01")
        XCTAssertEqual(job?.sessionID, host.id)
        XCTAssertEqual(job?.sessionName, "vision-lab")
        XCTAssertEqual(job?.command, "python train.py")
        XCTAssertEqual(job?.workingDirectory, "~/workspace")
        XCTAssertEqual(job?.status, .running)
        XCTAssertEqual(job?.progressSummary, "Launching...")
        XCTAssertNotNil(job?.pid)
    }

    func testAddJobWithMissingHostKeepsStateAndSetsError() async {
        let model = await MainActor.run {
            AppModel(
                loadHostsAction: { [] },
                saveHostsAction: { _ in },
                storageDirectoryDescriptionAction: { "/tmp/SSHub" },
                connectivityCheckAction: { _ in "ok" }
            )
        }

        await MainActor.run {
            model.hosts = []
            model.jobs = []
        }

        let draft = JobDraft(
            name: "train-resnet50",
            hostID: UUID(),
            sessionID: UUID(),
            command: "python train.py",
            workingDirectory: ""
        )

        await MainActor.run {
            model.addJob(from: draft)
        }

        let state = await MainActor.run { (model.jobs, model.jobErrorMessage) }
        XCTAssertTrue(state.0.isEmpty)
        XCTAssertEqual(state.1, "Select an existing host and tmux session before launching the job.")
    }

    func testUpdateJobMatchesByIdentifierAndPreservesRuntimeFields() async {
        let model = await MainActor.run {
            AppModel(
                loadHostsAction: { [] },
                saveHostsAction: { _ in },
                storageDirectoryDescriptionAction: { "/tmp/SSHub" },
                connectivityCheckAction: { _ in "ok" }
            )
        }
        let originalHost = Host(
            id: UUID(),
            name: "gpu-01",
            hostAlias: "gpu-01",
            username: nil,
            port: nil,
            status: .reachable,
            statusMessage: nil,
            lastCheckedAt: nil
        )
        let replacementHost = Host(
            id: UUID(),
            name: "gpu-02",
            hostAlias: "gpu-02",
            username: nil,
            port: nil,
            status: .reachable,
            statusMessage: nil,
            lastCheckedAt: nil
        )
        let originalSession = makeSession(for: originalHost, id: UUID(), name: "vision-lab")
        let replacementSession = makeSession(for: replacementHost, id: UUID(), name: "resume-lab")
        let jobID = UUID()
        let startedAt = Date(timeIntervalSince1970: 1234)
        let job = Job(
            id: jobID,
            name: "train-resnet50",
            hostID: originalHost.id,
            hostName: originalHost.name,
            sessionID: originalSession.id,
            sessionName: originalSession.name,
            status: .failed,
            progressSummary: "stderr tail available",
            startedAt: startedAt,
            command: "python train.py",
            workingDirectory: nil,
            pid: 43210
        )
        let staleCopy = Job(
            id: jobID,
            name: "outdated",
            hostID: originalHost.id,
            hostName: originalHost.name,
            sessionID: originalSession.id,
            sessionName: originalSession.name,
            status: .running,
            progressSummary: "running",
            startedAt: .now,
            command: "old command",
            workingDirectory: "~/old",
            pid: nil
        )

        await MainActor.run {
            model.hosts = [originalHost, replacementHost]
            model.sessions = [originalSession, replacementSession]
            model.jobs = [job]
        }

        var draft = JobDraft()
        draft.name = " updated-job "
        draft.hostID = replacementHost.id
        draft.sessionID = replacementSession.id
        draft.command = " ./run.sh --resume "
        draft.workingDirectory = " /tmp/run "
        let updateDraft = draft

        await MainActor.run {
            model.updateJob(staleCopy, from: updateDraft)
        }

        let updatedJob = await MainActor.run { model.jobs.first }
        XCTAssertEqual(updatedJob?.id, jobID)
        XCTAssertEqual(updatedJob?.name, "updated-job")
        XCTAssertEqual(updatedJob?.hostID, replacementHost.id)
        XCTAssertEqual(updatedJob?.hostName, "gpu-02")
        XCTAssertEqual(updatedJob?.sessionID, replacementSession.id)
        XCTAssertEqual(updatedJob?.sessionName, "resume-lab")
        XCTAssertEqual(updatedJob?.command, "./run.sh --resume")
        XCTAssertEqual(updatedJob?.workingDirectory, "/tmp/run")
        XCTAssertEqual(updatedJob?.status, .failed)
        XCTAssertEqual(updatedJob?.progressSummary, "stderr tail available")
        XCTAssertEqual(updatedJob?.startedAt, startedAt)
        XCTAssertEqual(updatedJob?.pid, 43210)
    }

    func testUpdateJobWithMissingHostLeavesJobUnchangedAndSetsError() async {
        let model = await MainActor.run {
            AppModel(
                loadHostsAction: { [] },
                saveHostsAction: { _ in },
                storageDirectoryDescriptionAction: { "/tmp/SSHub" },
                connectivityCheckAction: { _ in "ok" }
            )
        }
        let host = Host(
            id: UUID(),
            name: "gpu-01",
            hostAlias: "gpu-01",
            username: nil,
            port: nil,
            status: .reachable,
            statusMessage: nil,
            lastCheckedAt: nil
        )
        let job = Job(
            id: UUID(),
            name: "train-resnet50",
            hostID: host.id,
            hostName: host.name,
            sessionID: host.id,
            sessionName: "vision-lab",
            status: .failed,
            progressSummary: "stderr tail available",
            startedAt: Date(timeIntervalSince1970: 1234),
            command: "python train.py",
            workingDirectory: nil,
            pid: 43210
        )
        let draft = JobDraft(
            name: "updated-job",
            hostID: UUID(),
            sessionID: UUID(),
            command: "./run.sh --resume",
            workingDirectory: "/tmp/run"
        )

        await MainActor.run {
            model.hosts = [host]
            model.sessions = [makeSession(for: host, name: "vision-lab")]
            model.jobs = [job]
            model.updateJob(job, from: draft)
        }

        let state = await MainActor.run { (model.jobs.first, model.jobErrorMessage) }
        XCTAssertEqual(state.0, job)
        XCTAssertEqual(state.1, "Select an existing host and tmux session before saving the job.")
    }

    func testDeleteHostWithRunningJobIsBlocked() async {
        let model = await MainActor.run {
            AppModel(
                loadHostsAction: { [] },
                saveHostsAction: { _ in },
                storageDirectoryDescriptionAction: { "/tmp/SSHub" },
                connectivityCheckAction: { _ in "ok" }
            )
        }
        let host = Host(
            id: UUID(),
            name: "gpu-01",
            hostAlias: "gpu-01",
            username: nil,
            port: nil,
            status: .reachable,
            statusMessage: nil,
            lastCheckedAt: nil
        )
        let runningJob = Job(
            id: UUID(),
            name: "train-resnet50",
            hostID: host.id,
            hostName: host.name,
            status: .running,
            progressSummary: "Launching...",
            startedAt: Date(timeIntervalSince1970: 100),
            command: "python train.py",
            workingDirectory: nil,
            pid: 12345
        )

        await MainActor.run {
            model.hosts = [host]
            model.jobs = [runningJob]
            model.deleteHost(host)
        }

        let state = await MainActor.run { (model.hosts, model.hostErrorMessage) }
        XCTAssertEqual(state.0, [host])
        XCTAssertEqual(state.1, "Stop running jobs on gpu-01 before removing this host.")
    }

    func testDeleteHostsWithRunningJobIsBlocked() async {
        let recorder = SaveRecorder()
        let model = await MainActor.run {
            AppModel(
                loadHostsAction: { [] },
                saveHostsAction: recorder.save(hosts:),
                storageDirectoryDescriptionAction: { "/tmp/SSHub" },
                connectivityCheckAction: { _ in "ok" }
            )
        }
        let hosts = [
            Host(
                id: UUID(),
                name: "gpu-01",
                hostAlias: "gpu-01",
                username: nil,
                port: nil,
                status: .unknown,
                statusMessage: nil,
                lastCheckedAt: nil
            ),
            Host(
                id: UUID(),
                name: "gpu-02",
                hostAlias: "gpu-02",
                username: nil,
                port: nil,
                status: .unknown,
                statusMessage: nil,
                lastCheckedAt: nil
            )
        ]
        let runningJob = Job(
            id: UUID(),
            name: "train-resnet50",
            hostID: hosts[0].id,
            hostName: hosts[0].name,
            status: .running,
            progressSummary: "Launching...",
            startedAt: Date(timeIntervalSince1970: 100),
            command: "python train.py",
            workingDirectory: nil,
            pid: 12345
        )

        await MainActor.run {
            model.hosts = hosts
            model.jobs = [runningJob]
            model.deleteHosts(at: IndexSet(integer: 0))
        }

        let state = await MainActor.run { (model.hosts, model.hostErrorMessage) }
        XCTAssertEqual(state.0, hosts)
        XCTAssertEqual(state.1, "Stop running jobs on gpu-01 before removing this host.")
        XCTAssertTrue(recorder.snapshots().isEmpty)
    }

    func testDeleteHostsWithMultipleBlockedHostsUsesPluralMessage() async {
        let model = await MainActor.run {
            AppModel(
                loadHostsAction: { [] },
                saveHostsAction: { _ in },
                storageDirectoryDescriptionAction: { "/tmp/SSHub" },
                connectivityCheckAction: { _ in "ok" }
            )
        }
        let firstHost = Host(
            id: UUID(),
            name: "gpu-01",
            hostAlias: "gpu-01",
            username: nil,
            port: nil,
            status: .reachable,
            statusMessage: nil,
            lastCheckedAt: nil
        )
        let secondHost = Host(
            id: UUID(),
            name: "gpu-02",
            hostAlias: "gpu-02",
            username: nil,
            port: nil,
            status: .reachable,
            statusMessage: nil,
            lastCheckedAt: nil
        )

        await MainActor.run {
            model.hosts = [firstHost, secondHost]
            model.jobs = [
                Job(
                    id: UUID(),
                    name: "train-a",
                    hostID: firstHost.id,
                    hostName: firstHost.name,
                    status: .running,
                    progressSummary: "Launching...",
                    startedAt: Date(timeIntervalSince1970: 100),
                    command: "python train.py",
                    workingDirectory: nil,
                    pid: 12345
                ),
                Job(
                    id: UUID(),
                    name: "train-b",
                    hostID: secondHost.id,
                    hostName: secondHost.name,
                    status: .running,
                    progressSummary: "Launching...",
                    startedAt: Date(timeIntervalSince1970: 200),
                    command: "python train.py",
                    workingDirectory: nil,
                    pid: 54321
                )
            ]
            model.deleteHosts(at: IndexSet([0, 1, 4]))
        }

        let state = await MainActor.run { (model.hosts, model.hostErrorMessage) }
        XCTAssertEqual(state.0, [firstHost, secondHost])
        XCTAssertEqual(state.1, "Stop running jobs on the selected hosts before removing them.")
    }

    func testAddSessionCreatesDetachedSessionForHost() async {
        let model = await MainActor.run {
            AppModel(
                loadHostsAction: { [] },
                saveHostsAction: { _ in },
                storageDirectoryDescriptionAction: { "/tmp/SSHub" },
                connectivityCheckAction: { _ in "ok" }
            )
        }
        let host = Host(
            id: UUID(),
            name: "gpu-01",
            hostAlias: "gpu-01",
            username: nil,
            port: nil,
            status: .reachable,
            statusMessage: nil,
            lastCheckedAt: nil
        )
        let draft = TmuxSessionDraft(name: " vision-lab ", hostID: host.id, workingDirectory: " ~/workspace ")

        await MainActor.run {
            model.hosts = [host]
            model.sessions = []
            model.addSession(from: draft)
        }

        let session = await MainActor.run { model.sessions.first }
        XCTAssertEqual(session?.name, "vision-lab")
        XCTAssertEqual(session?.hostID, host.id)
        XCTAssertEqual(session?.hostName, host.name)
        XCTAssertEqual(session?.workingDirectory, "~/workspace")
        XCTAssertEqual(session?.status, .detached)
    }

    func testAddSessionWithMissingHostSetsError() async {
        let model = await MainActor.run {
            AppModel(
                loadHostsAction: { [] },
                saveHostsAction: { _ in },
                storageDirectoryDescriptionAction: { "/tmp/SSHub" },
                connectivityCheckAction: { _ in "ok" }
            )
        }
        let draft = TmuxSessionDraft(name: "vision-lab", hostID: UUID(), workingDirectory: "")

        await MainActor.run {
            model.sessions = []
            model.jobErrorMessage = "previous error"
            model.addSession(from: draft)
        }

        let state = await MainActor.run { (model.sessions, model.jobErrorMessage) }
        XCTAssertTrue(state.0.isEmpty)
        XCTAssertEqual(state.1, "Select an existing host before creating the tmux session.")
    }

    func testUpdateSessionRefreshesMatchingJobsByIdentifier() async {
        let model = await MainActor.run {
            AppModel(
                loadHostsAction: { [] },
                saveHostsAction: { _ in },
                storageDirectoryDescriptionAction: { "/tmp/SSHub" },
                connectivityCheckAction: { _ in "ok" }
            )
        }
        let originalHost = Host(
            id: UUID(),
            name: "gpu-01",
            hostAlias: "gpu-01",
            username: nil,
            port: nil,
            status: .reachable,
            statusMessage: nil,
            lastCheckedAt: nil
        )
        let replacementHost = Host(
            id: UUID(),
            name: "gpu-02",
            hostAlias: "gpu-02",
            username: nil,
            port: nil,
            status: .reachable,
            statusMessage: nil,
            lastCheckedAt: nil
        )
        let sessionID = UUID()
        let createdAt = Date(timeIntervalSince1970: 10)
        let lastAttachedAt = Date(timeIntervalSince1970: 20)
        let session = TmuxSession(
            id: sessionID,
            hostID: originalHost.id,
            hostName: originalHost.name,
            name: "vision-lab",
            workingDirectory: "~/old",
            status: .attached,
            createdAt: createdAt,
            lastAttachedAt: lastAttachedAt
        )
        let staleCopy = TmuxSession(
            id: sessionID,
            hostID: originalHost.id,
            hostName: originalHost.name,
            name: "stale",
            workingDirectory: nil,
            status: .detached,
            createdAt: .now,
            lastAttachedAt: nil
        )
        let matchingJob = Job(
            id: UUID(),
            name: "train-a",
            hostID: originalHost.id,
            hostName: originalHost.name,
            sessionID: sessionID,
            sessionName: "vision-lab",
            status: .running,
            progressSummary: "Launching...",
            startedAt: Date(timeIntervalSince1970: 100),
            command: "python train.py",
            workingDirectory: nil,
            pid: 11111
        )
        let unrelatedJob = Job(
            id: UUID(),
            name: "train-b",
            hostID: originalHost.id,
            hostName: originalHost.name,
            sessionID: UUID(),
            sessionName: "other",
            status: .queued,
            progressSummary: "Queued",
            startedAt: Date(timeIntervalSince1970: 200),
            command: "python eval.py",
            workingDirectory: nil,
            pid: nil
        )
        let draft = TmuxSessionDraft(name: " updated-lab ", hostID: replacementHost.id, workingDirectory: " ~/new ")

        await MainActor.run {
            model.hosts = [originalHost, replacementHost]
            model.sessions = [session]
            model.jobs = [matchingJob, unrelatedJob]
            model.updateSession(staleCopy, from: draft)
        }

        let state = await MainActor.run { (model.sessions.first, model.jobs, model.jobErrorMessage) }
        XCTAssertEqual(state.0?.id, sessionID)
        XCTAssertEqual(state.0?.hostID, replacementHost.id)
        XCTAssertEqual(state.0?.hostName, replacementHost.name)
        XCTAssertEqual(state.0?.name, "updated-lab")
        XCTAssertEqual(state.0?.workingDirectory, "~/new")
        XCTAssertEqual(state.0?.status, .attached)
        XCTAssertEqual(state.0?.createdAt, createdAt)
        XCTAssertEqual(state.0?.lastAttachedAt, lastAttachedAt)
        XCTAssertEqual(state.1[0].hostID, replacementHost.id)
        XCTAssertEqual(state.1[0].hostName, replacementHost.name)
        XCTAssertEqual(state.1[0].sessionName, "updated-lab")
        XCTAssertEqual(state.1[1], unrelatedJob)
        XCTAssertNil(state.2)
    }

    func testUpdateSessionWithMissingHostLeavesStateAndSetsError() async {
        let model = await MainActor.run {
            AppModel(
                loadHostsAction: { [] },
                saveHostsAction: { _ in },
                storageDirectoryDescriptionAction: { "/tmp/SSHub" },
                connectivityCheckAction: { _ in "ok" }
            )
        }
        let host = Host(
            id: UUID(),
            name: "gpu-01",
            hostAlias: "gpu-01",
            username: nil,
            port: nil,
            status: .reachable,
            statusMessage: nil,
            lastCheckedAt: nil
        )
        let session = makeSession(for: host, id: UUID(), name: "vision-lab")
        let draft = TmuxSessionDraft(name: "updated-lab", hostID: UUID(), workingDirectory: "/tmp/run")

        await MainActor.run {
            model.hosts = [host]
            model.sessions = [session]
            model.jobErrorMessage = nil
            model.updateSession(session, from: draft)
        }

        let state = await MainActor.run { (model.sessions, model.jobErrorMessage) }
        XCTAssertEqual(state.0, [session])
        XCTAssertEqual(state.1, "Select an existing host before saving the tmux session.")
    }

    func testDeleteSessionWithoutRunningJobRemovesSessionAndClearsError() async {
        let model = await MainActor.run {
            AppModel(
                loadHostsAction: { [] },
                saveHostsAction: { _ in },
                storageDirectoryDescriptionAction: { "/tmp/SSHub" },
                connectivityCheckAction: { _ in "ok" }
            )
        }
        let host = Host(
            id: UUID(),
            name: "gpu-01",
            hostAlias: "gpu-01",
            username: nil,
            port: nil,
            status: .reachable,
            statusMessage: nil,
            lastCheckedAt: nil
        )
        let session = makeSession(for: host, id: UUID(), name: "vision-lab")
        let finishedJob = Job(
            id: UUID(),
            name: "train-resnet50",
            hostID: host.id,
            hostName: host.name,
            sessionID: session.id,
            sessionName: session.name,
            status: .completed,
            progressSummary: "Done",
            startedAt: Date(timeIntervalSince1970: 100),
            command: "python train.py",
            workingDirectory: nil,
            pid: nil
        )

        await MainActor.run {
            model.sessions = [session]
            model.jobs = [finishedJob]
            model.jobErrorMessage = "previous error"
            model.deleteSession(session)
        }

        let state = await MainActor.run { (model.sessions, model.jobErrorMessage) }
        XCTAssertTrue(state.0.isEmpty)
        XCTAssertNil(state.1)
    }

    func testDeleteMissingSessionLeavesStateUnchanged() async {
        let model = await MainActor.run {
            AppModel(
                loadHostsAction: { [] },
                saveHostsAction: { _ in },
                storageDirectoryDescriptionAction: { "/tmp/SSHub" },
                connectivityCheckAction: { _ in "ok" }
            )
        }
        let host = Host(
            id: UUID(),
            name: "gpu-01",
            hostAlias: "gpu-01",
            username: nil,
            port: nil,
            status: .reachable,
            statusMessage: nil,
            lastCheckedAt: nil
        )
        let session = makeSession(for: host, id: UUID(), name: "vision-lab")

        await MainActor.run {
            model.sessions = [session]
            model.deleteSession(makeSession(for: host, id: UUID(), name: "other"))
        }

        let sessions = await MainActor.run { model.sessions }
        XCTAssertEqual(sessions, [session])
    }

    func testDeleteSessionWithRunningJobIsBlocked() async {
        let model = await MainActor.run {
            AppModel(
                loadHostsAction: { [] },
                saveHostsAction: { _ in },
                storageDirectoryDescriptionAction: { "/tmp/SSHub" },
                connectivityCheckAction: { _ in "ok" }
            )
        }
        let host = Host(
            id: UUID(),
            name: "gpu-01",
            hostAlias: "gpu-01",
            username: nil,
            port: nil,
            status: .reachable,
            statusMessage: nil,
            lastCheckedAt: nil
        )
        let session = makeSession(for: host, name: "vision-lab")
        let runningJob = Job(
            id: UUID(),
            name: "train-resnet50",
            hostID: host.id,
            hostName: host.name,
            sessionID: session.id,
            sessionName: session.name,
            status: .running,
            progressSummary: "Launching...",
            startedAt: Date(timeIntervalSince1970: 100),
            command: "python train.py",
            workingDirectory: nil,
            pid: 12345
        )

        await MainActor.run {
            model.hosts = [host]
            model.sessions = [session]
            model.jobs = [runningJob]
            model.deleteSession(session)
        }

        let state = await MainActor.run { (model.sessions, model.jobErrorMessage) }
        XCTAssertEqual(state.0, [session])
        XCTAssertEqual(state.1, "Stop running jobs in vision-lab before removing the tmux session.")
    }

    func testRestartJobWithoutSessionSetsErrorAndPreservesState() async {
        let model = await MainActor.run {
            AppModel(
                loadHostsAction: { [] },
                saveHostsAction: { _ in },
                storageDirectoryDescriptionAction: { "/tmp/SSHub" },
                connectivityCheckAction: { _ in "ok" }
            )
        }
        let job = Job(
            id: UUID(),
            name: "train-resnet50",
            hostID: UUID(),
            hostName: "gpu-01",
            sessionID: UUID(),
            sessionName: "vision-lab",
            status: .stopped,
            progressSummary: "Stopped by user",
            startedAt: Date(timeIntervalSince1970: 100),
            command: "python train.py",
            workingDirectory: nil,
            pid: 11111
        )

        await MainActor.run {
            model.sessions = []
            model.jobs = [job]
            model.restartJob(job)
        }

        let state = await MainActor.run { (model.jobs.first, model.jobErrorMessage) }
        XCTAssertEqual(state.0, job)
        XCTAssertEqual(state.1, "The tmux session for this job no longer exists.")
    }

    func testCompleteAndFailJobOperateByIdentifier() async {
        let model = await MainActor.run {
            AppModel(
                loadHostsAction: { [] },
                saveHostsAction: { _ in },
                storageDirectoryDescriptionAction: { "/tmp/SSHub" },
                connectivityCheckAction: { _ in "ok" }
            )
        }
        let jobID = UUID()
        let job = Job(
            id: jobID,
            name: "train-resnet50",
            hostID: UUID(),
            hostName: "gpu-01",
            sessionID: UUID(),
            sessionName: "vision-lab",
            status: .running,
            progressSummary: "Epoch 2/10",
            startedAt: Date(timeIntervalSince1970: 100),
            command: "python train.py",
            workingDirectory: nil,
            pid: 11111
        )
        let staleCopy = Job(
            id: jobID,
            name: "stale",
            hostID: UUID(),
            hostName: "stale",
            sessionID: UUID(),
            sessionName: "stale",
            status: .failed,
            progressSummary: "old",
            startedAt: .now,
            command: "old",
            workingDirectory: "~/old",
            pid: nil
        )

        await MainActor.run {
            model.jobs = [job]
            model.completeJob(staleCopy)
        }

        var updatedJob = await MainActor.run { model.jobs.first }
        XCTAssertEqual(updatedJob?.status, .completed)
        XCTAssertEqual(updatedJob?.progressSummary, "Completed successfully")

        await MainActor.run {
            model.failJob(staleCopy)
        }

        updatedJob = await MainActor.run { model.jobs.first }
        XCTAssertEqual(updatedJob?.status, .failed)
        XCTAssertEqual(updatedJob?.progressSummary, "Failure detected")
    }

    func testJobStatusActionsAndDeleteOperateByIdentifier() async {
        let model = await MainActor.run {
            AppModel(
                loadHostsAction: { [] },
                saveHostsAction: { _ in },
                storageDirectoryDescriptionAction: { "/tmp/SSHub" },
                connectivityCheckAction: { _ in "ok" }
            )
        }
        let jobID = UUID()
        let job = Job(
            id: jobID,
            name: "train-resnet50",
            hostID: UUID(),
            hostName: "gpu-01",
            sessionID: UUID(),
            sessionName: "vision-lab",
            status: .running,
            progressSummary: "Epoch 2/10",
            startedAt: Date(timeIntervalSince1970: 100),
            command: "python train.py",
            workingDirectory: nil,
            pid: 11111
        )
        let staleCopy = Job(
            id: jobID,
            name: "stale",
            hostID: UUID(),
            hostName: "gpu-01",
            sessionID: job.sessionID,
            sessionName: "vision-lab",
            status: .failed,
            progressSummary: "old",
            startedAt: .now,
            command: "old",
            workingDirectory: "~/old",
            pid: nil
        )

        await MainActor.run {
            model.sessions = [
                TmuxSession(
                    id: job.sessionID,
                    hostID: job.hostID,
                    hostName: job.hostName,
                    name: job.sessionName,
                    workingDirectory: nil,
                    status: .attached,
                    createdAt: Date(timeIntervalSince1970: 0),
                    lastAttachedAt: nil
                )
            ]
            model.jobs = [job]
            model.stopJob(staleCopy)
        }

        let stoppedJob = await MainActor.run { model.jobs.first }
        XCTAssertEqual(stoppedJob?.status, .stopped)
        XCTAssertEqual(stoppedJob?.progressSummary, "Stopped by user")

        await MainActor.run {
            model.restartJob(staleCopy)
        }
        let restartedJob = await MainActor.run { model.jobs.first }
        XCTAssertEqual(restartedJob?.status, .running)
        XCTAssertEqual(restartedJob?.progressSummary, "Restart requested")

        await MainActor.run {
            model.deleteJob(staleCopy)
        }
        let jobs = await MainActor.run { model.jobs }
        XCTAssertTrue(jobs.isEmpty)
    }

    private func waitUntil(
        timeoutNanoseconds: UInt64 = 2_000_000_000,
        pollIntervalNanoseconds: UInt64 = 20_000_000,
        condition: @escaping () async -> Bool
    ) async throws {
        let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds

        while DispatchTime.now().uptimeNanoseconds < deadline {
            if await condition() {
                return
            }

            try await Task.sleep(nanoseconds: pollIntervalNanoseconds)
        }

        XCTFail("Condition was not met before timeout")
    }
}
// swiftlint:enable type_body_length function_body_length

private enum TestError: LocalizedError {
    case sample

    var errorDescription: String? {
        switch self {
        case .sample:
            return "Sample failure"
        }
    }
}

private final class SaveRecorder {
    private let lock = NSLock()
    private var savedSnapshots: [[SSHub.Host]] = []

    func save(hosts: [SSHub.Host]) {
        lock.lock()
        defer { lock.unlock() }
        savedSnapshots.append(hosts)
    }

    func snapshots() -> [[SSHub.Host]] {
        lock.lock()
        defer { lock.unlock() }
        return savedSnapshots
    }
}

private func makeSession(for host: SSHub.Host, id: UUID? = nil, name: String = "default") -> SSHub.TmuxSession {
    SSHub.TmuxSession(
        id: id ?? host.id,
        hostID: host.id,
        hostName: host.name,
        name: name,
        workingDirectory: nil,
        status: .attached,
        createdAt: Date(timeIntervalSince1970: 0),
        lastAttachedAt: nil
    )
}

private actor ConnectivityCheckRecorder {
    private let result: Result<String, Error>?
    private let resultsByAlias: [String: Result<String, Error>]
    private var requestedHosts: [SSHub.Host] = []

    init(result: Result<String, Error>) {
        self.result = result
        self.resultsByAlias = [:]
    }

    init(resultsByAlias: [String: Result<String, Error>]) {
        self.result = nil
        self.resultsByAlias = resultsByAlias
    }

    func run(host: SSHub.Host) throws -> String {
        requestedHosts.append(host)
        if let result {
            return try result.get()
        }

        return try resultsByAlias[host.hostAlias, default: .success("Reachability check OK")].get()
    }

    func checkedHostAliases() -> [String] {
        requestedHosts.map { $0.hostAlias }
    }
}
