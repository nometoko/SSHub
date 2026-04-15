import Foundation

enum SidebarSection: String, CaseIterable, Identifiable {
    case dashboard
    case hosts
    case jobs
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard:
            return "Dashboard"
        case .hosts:
            return "Hosts"
        case .jobs:
            return "Jobs"
        case .settings:
            return "Settings"
        }
    }
}

struct Host: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let hostAlias: String
    let username: String?
    let port: Int?
    let status: HostStatus
    let statusMessage: String?
    let lastCheckedAt: Date?

    static let sampleData: [Host] = [
        Host(
            id: UUID(),
            name: "gpu-01",
            hostAlias: "gpu-01",
            username: nil,
            port: nil,
            status: .reachable,
            statusMessage: "Reachability check OK",
            lastCheckedAt: .now
        ),
        Host(
            id: UUID(),
            name: "sim-lab",
            hostAlias: "sim-lab",
            username: "iwamoto",
            port: 2222,
            status: .unreachable,
            statusMessage: "Connection timed out",
            lastCheckedAt: .now.addingTimeInterval(-900)
        )
    ]
}

enum HostStatus: String, Codable {
    case checking
    case reachable
    case unreachable
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        switch rawValue {
        case "checking":
            self = .checking
        case "reachable", "connected":
            self = .reachable
        case "unreachable", "disconnected":
            self = .unreachable
        case "unknown":
            self = .unknown
        default:
            self = .unknown
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

extension Host {
    func withStatus(
        _ status: HostStatus,
        message: String? = nil,
        lastCheckedAt: Date? = nil
    ) -> Host {
        Host(
            id: id,
            name: name,
            hostAlias: hostAlias,
            username: username,
            port: port,
            status: status,
            statusMessage: message,
            lastCheckedAt: lastCheckedAt
        )
    }

    var displayTarget: String {
        let base = username.map { "\($0)@\(hostAlias)" } ?? hostAlias

        if let port {
            return "\(base):\(port)"
        }

        return base
    }

    func makeDraft() -> HostDraft {
        HostDraft(
            name: name,
            hostAlias: hostAlias,
            username: username ?? "",
            portText: port.map(String.init) ?? ""
        )
    }

    var displayStatusMessage: String? {
        guard let statusMessage, !statusMessage.isEmpty else {
            return nil
        }

        if status == .reachable {
            let normalized = statusMessage.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            if normalized == "ok" || normalized == "reachability check ok" {
                return nil
            }
        }

        return statusMessage
    }
}

struct HostDraft {
    var name: String = ""
    var hostAlias: String = ""
    var username: String = ""
    var portText: String = ""

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !hostAlias.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        hasValidPortOverride
    }

    private var hasValidPortOverride: Bool {
        let trimmed = portText.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            return true
        }

        guard let port = Int(trimmed) else {
            return false
        }

        return (1...65535).contains(port)
    }

    func makeHost() -> Host {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let usernameValue = trimmedUsername.isEmpty ? nil : trimmedUsername
        let trimmedPortText = portText.trimmingCharacters(in: .whitespacesAndNewlines)
        let portValue = trimmedPortText.isEmpty ? nil : Int(trimmedPortText)

        return Host(
            id: UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            hostAlias: hostAlias.trimmingCharacters(in: .whitespacesAndNewlines),
            username: usernameValue,
            port: portValue,
            status: .unknown,
            statusMessage: nil,
            lastCheckedAt: nil
        )
    }
}

struct Job: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let hostID: UUID
    let hostName: String
    let status: JobStatus
    let progressSummary: String
    let startedAt: Date
    let command: String
    let workingDirectory: String?
    let pid: Int?

    static let sampleData: [Job] = [
        Job(
            id: UUID(),
            name: "train-resnet50",
            hostID: UUID(),
            hostName: "gpu-01",
            status: .running,
            progressSummary: "Epoch 3/10",
            startedAt: .now.addingTimeInterval(-4200),
            command: "python train.py --config configs/resnet50.yaml",
            workingDirectory: "~/projects/vision",
            pid: 41231
        ),
        Job(
            id: UUID(),
            name: "fluid-sim-case7",
            hostID: UUID(),
            hostName: "sim-lab",
            status: .failed,
            progressSummary: "stderr tail available",
            startedAt: .now.addingTimeInterval(-11600),
            command: "./run_simulation.sh case7",
            workingDirectory: "~/simulations/case7",
            pid: 28114
        )
    ]
}

enum JobStatus: String, Codable, CaseIterable, Hashable {
    case running
    case queued
    case completed
    case failed
    case stopped
    case unknown
}

extension Job {
    func isHostAvailable(in hosts: [Host]) -> Bool {
        hosts.contains(where: { $0.id == hostID })
    }

    var runtimeSummary: String {
        let components = startedAt.formatted(date: .abbreviated, time: .shortened)
        return "Started: \(components)"
    }

    var executionSummary: String? {
        if let pid {
            return "PID \(pid)"
        }

        return nil
    }

    func makeDraft() -> JobDraft {
        JobDraft(
            name: name,
            hostID: hostID,
            command: command,
            workingDirectory: workingDirectory ?? ""
        )
    }
}

struct JobDraft {
    var name: String = ""
    var hostID: UUID?
    var command: String = ""
    var workingDirectory: String = ""

    var isValid: Bool {
        hostID != nil &&
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func normalizedHostID(in hosts: [Host]) -> UUID? {
        guard !hosts.isEmpty else {
            return nil
        }

        if let hostID, hosts.contains(where: { $0.id == hostID }) {
            return hostID
        }

        if hostID == nil {
            return hosts.first?.id
        }

        return hostID
    }

    func selectedHostExists(in hosts: [Host]) -> Bool {
        guard let hostID else {
            return false
        }

        return hosts.contains(where: { $0.id == hostID })
    }
}

struct NotificationSettings {
    var slackWebhookURL: String
    var notifyOnCompleted: Bool
    var notifyOnFailed: Bool

    static let sample = NotificationSettings(
        slackWebhookURL: "",
        notifyOnCompleted: true,
        notifyOnFailed: true
    )
}
