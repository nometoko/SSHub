import Foundation

struct HostStore {
    typealias AppSupportDirectoryAction = () throws -> URL

    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let appSupportDirectoryAction: AppSupportDirectoryAction

    init(
        fileManager: FileManager = .default,
        encoder: JSONEncoder = HostStore.makeEncoder(),
        decoder: JSONDecoder = JSONDecoder(),
        appSupportDirectoryAction: AppSupportDirectoryAction? = nil
    ) {
        self.fileManager = fileManager
        self.encoder = encoder
        self.decoder = decoder
        self.appSupportDirectoryAction = appSupportDirectoryAction ?? {
            guard let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
                throw HostStoreError.appSupportDirectoryUnavailable
            }

            return baseURL.appendingPathComponent("SSHub", isDirectory: true)
        }
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

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
        try appSupportDirectoryAction()
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
