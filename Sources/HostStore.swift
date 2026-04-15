import Foundation

struct HostStore {
    private let fileManager = FileManager.default
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
    private let decoder = JSONDecoder()

    func loadHosts() throws -> [Host] {
        let url = try hostsFileURL()

        guard fileManager.fileExists(atPath: url.path) else {
            return []
        }

        let data = try Data(contentsOf: url)
        return try decoder.decode([Host].self, from: data)
    }

    func saveHosts(_ hosts: [Host]) throws {
        let url = try hostsFileURL()
        let directoryURL = url.deletingLastPathComponent()

        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let data = try encoder.encode(hosts)
        try data.write(to: url, options: .atomic)
    }

    func storageDirectoryDescription() -> String {
        do {
            let url = try appSupportDirectory()
            return url.path
        } catch {
            return "~/Library/Application Support/SSHub"
        }
    }

    private func hostsFileURL() throws -> URL {
        try appSupportDirectory().appendingPathComponent("hosts.json")
    }

    private func appSupportDirectory() throws -> URL {
        guard let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw HostStoreError.appSupportDirectoryUnavailable
        }

        return baseURL.appendingPathComponent("SSHub", isDirectory: true)
    }
}

enum HostStoreError: LocalizedError {
    case appSupportDirectoryUnavailable

    var errorDescription: String? {
        switch self {
        case .appSupportDirectoryUnavailable:
            return "Application Support directory is unavailable."
        }
    }
}
