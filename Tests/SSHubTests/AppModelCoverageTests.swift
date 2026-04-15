import Foundation
import XCTest
@testable import SSHub

final class AppModelCoverageTests: XCTestCase {
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
}
