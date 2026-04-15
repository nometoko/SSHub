import Foundation
import XCTest
@testable import SSHub

final class HostStoreTests: XCTestCase {
    func testLoadHostsReturnsEmptyArrayWhenFileDoesNotExist() throws {
        let temporaryDirectoryURL = makeTemporaryDirectory()
        let store = makeStore(baseDirectoryURL: temporaryDirectoryURL)

        let hosts = try store.loadHosts()

        XCTAssertTrue(hosts.isEmpty)
    }

    func testSaveHostsPersistsAndLoadHostsRestoresData() throws {
        let temporaryDirectoryURL = makeTemporaryDirectory()
        let store = makeStore(baseDirectoryURL: temporaryDirectoryURL)
        let hosts = [
            Host(
                id: UUID(),
                name: "gpu-01",
                hostAlias: "gpu-01",
                username: "iwamoto",
                port: 2222,
                status: .reachable,
                statusMessage: "Reachability check OK",
                lastCheckedAt: Date(timeIntervalSince1970: 1_234)
            )
        ]

        try store.saveHosts(hosts)
        let restoredHosts = try store.loadHosts()
        let hostsFileURL = temporaryDirectoryURL
            .appendingPathComponent("SSHub", isDirectory: true)
            .appendingPathComponent("hosts.json")

        XCTAssertEqual(restoredHosts, hosts)
        XCTAssertTrue(FileManager.default.fileExists(atPath: hostsFileURL.path))
    }

    func testStorageDirectoryDescriptionReturnsInjectedPath() {
        let temporaryDirectoryURL = makeTemporaryDirectory()
        let store = makeStore(baseDirectoryURL: temporaryDirectoryURL)

        XCTAssertEqual(
            store.storageDirectoryDescription(),
            temporaryDirectoryURL.appendingPathComponent("SSHub", isDirectory: true).path
        )
    }

    func testStorageDirectoryDescriptionFallsBackWhenDirectoryUnavailable() {
        let store = HostStore(appSupportDirectoryAction: {
            throw HostStoreError.appSupportDirectoryUnavailable
        })

        XCTAssertEqual(store.storageDirectoryDescription(), "~/Library/Application Support/SSHub")
    }

    func testLoadHostsThrowsWhenStoredJSONIsInvalid() throws {
        let temporaryDirectoryURL = makeTemporaryDirectory()
        let store = makeStore(baseDirectoryURL: temporaryDirectoryURL)
        let hostsDirectoryURL = temporaryDirectoryURL.appendingPathComponent("SSHub", isDirectory: true)
        let hostsFileURL = hostsDirectoryURL.appendingPathComponent("hosts.json")

        try FileManager.default.createDirectory(at: hostsDirectoryURL, withIntermediateDirectories: true)
        try Data("not-json".utf8).write(to: hostsFileURL, options: .atomic)

        XCTAssertThrowsError(try store.loadHosts())
    }

    func testHostStoreErrorProvidesLocalizedDescription() {
        XCTAssertEqual(
            HostStoreError.appSupportDirectoryUnavailable.localizedDescription,
            "Application Support directory is unavailable."
        )
    }

    private func makeTemporaryDirectory() -> URL {
        let directoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directoryURL)
        }
        return directoryURL
    }

    private func makeStore(baseDirectoryURL: URL) -> HostStore {
        HostStore(appSupportDirectoryAction: {
            baseDirectoryURL.appendingPathComponent("SSHub", isDirectory: true)
        })
    }
}
