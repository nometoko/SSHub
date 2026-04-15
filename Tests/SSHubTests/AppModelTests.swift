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
