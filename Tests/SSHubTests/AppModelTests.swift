import Foundation
import XCTest
@testable import SSHub

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
            model.deleteHost(staleCopy)
        }

        let remainingHosts = await MainActor.run { model.hosts }
        XCTAssertEqual(remainingHosts, [secondaryHost])
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
            model.jobs = []
        }

        var draft = JobDraft()
        draft.name = " train-resnet50 "
        draft.hostID = host.id
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
        XCTAssertEqual(job?.command, "python train.py")
        XCTAssertEqual(job?.workingDirectory, "~/workspace")
        XCTAssertEqual(job?.status, .running)
        XCTAssertEqual(job?.progressSummary, "Launching...")
        XCTAssertNotNil(job?.pid)
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
        let jobID = UUID()
        let startedAt = Date(timeIntervalSince1970: 1234)
        let job = Job(
            id: jobID,
            name: "train-resnet50",
            hostID: originalHost.id,
            hostName: originalHost.name,
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
            status: .running,
            progressSummary: "running",
            startedAt: .now,
            command: "old command",
            workingDirectory: "~/old",
            pid: nil
        )

        await MainActor.run {
            model.hosts = [originalHost, replacementHost]
            model.jobs = [job]
        }

        var draft = JobDraft()
        draft.name = " updated-job "
        draft.hostID = replacementHost.id
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
        XCTAssertEqual(updatedJob?.command, "./run.sh --resume")
        XCTAssertEqual(updatedJob?.workingDirectory, "/tmp/run")
        XCTAssertEqual(updatedJob?.status, .failed)
        XCTAssertEqual(updatedJob?.progressSummary, "stderr tail available")
        XCTAssertEqual(updatedJob?.startedAt, startedAt)
        XCTAssertEqual(updatedJob?.pid, 43210)
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
            status: .failed,
            progressSummary: "old",
            startedAt: .now,
            command: "old",
            workingDirectory: "~/old",
            pid: nil
        )

        await MainActor.run {
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
