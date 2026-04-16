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
            id: SampleDataIDs.gpuHost,
            name: "gpu-01",
            hostAlias: "gpu-01",
            username: nil,
            port: nil,
            status: .reachable,
            statusMessage: "Reachability check OK",
            lastCheckedAt: .now
        ),
        Host(
            id: SampleDataIDs.simHost,
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

private enum SampleDataIDs {
    static let gpuHost = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    static let simHost = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    static let gpuSession = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    static let simSession = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
}

struct TmuxSession: Identifiable, Codable, Equatable {
    let id: UUID
    let hostID: UUID
    let hostName: String
    let name: String
    let workingDirectory: String?
    let status: TmuxSessionStatus
    let createdAt: Date
    let lastAttachedAt: Date?

    static let sampleData: [TmuxSession] = [
        TmuxSession(
            id: SampleDataIDs.gpuSession,
            hostID: SampleDataIDs.gpuHost,
            hostName: "gpu-01",
            name: "vision-lab",
            workingDirectory: "~/projects/vision",
            status: .attached,
            createdAt: .now.addingTimeInterval(-12_000),
            lastAttachedAt: .now.addingTimeInterval(-300)
        ),
        TmuxSession(
            id: SampleDataIDs.simSession,
            hostID: SampleDataIDs.simHost,
            hostName: "sim-lab",
            name: "case7-debug",
            workingDirectory: "~/simulations/case7",
            status: .detached,
            createdAt: .now.addingTimeInterval(-28_000),
            lastAttachedAt: .now.addingTimeInterval(-3_600)
        )
    ]
}

enum TmuxSessionStatus: String, Codable, CaseIterable, Hashable {
    case attached
    case detached
    case terminated
    case unknown
}

extension TmuxSession {
    func isHostAvailable(in hosts: [Host]) -> Bool {
        hosts.contains(where: { $0.id == hostID })
    }

    func makeDraft() -> TmuxSessionDraft {
        TmuxSessionDraft(
            name: name,
            hostID: hostID,
            workingDirectory: workingDirectory ?? ""
        )
    }
}

struct TmuxSessionDraft {
    var name: String = ""
    var hostID: UUID?
    var workingDirectory: String = ""

    var isValid: Bool {
        hostID != nil &&
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

struct Job: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let hostID: UUID
    let hostName: String
    let sessionID: UUID
    let sessionName: String
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
            hostID: SampleDataIDs.gpuHost,
            hostName: "gpu-01",
            sessionID: SampleDataIDs.gpuSession,
            sessionName: "vision-lab",
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
            hostID: SampleDataIDs.simHost,
            hostName: "sim-lab",
            sessionID: SampleDataIDs.simSession,
            sessionName: "case7-debug",
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
    init(
        id: UUID,
        name: String,
        hostID: UUID,
        hostName: String,
        sessionID: UUID? = nil,
        sessionName: String? = nil,
        status: JobStatus,
        progressSummary: String,
        startedAt: Date,
        command: String,
        workingDirectory: String?,
        pid: Int?
    ) {
        self.id = id
        self.name = name
        self.hostID = hostID
        self.hostName = hostName
        self.sessionID = sessionID ?? hostID
        self.sessionName = sessionName ?? "default"
        self.status = status
        self.progressSummary = progressSummary
        self.startedAt = startedAt
        self.command = command
        self.workingDirectory = workingDirectory
        self.pid = pid
    }

    func isHostAvailable(in hosts: [Host]) -> Bool {
        hosts.contains(where: { $0.id == hostID })
    }

    func isSessionAvailable(in sessions: [TmuxSession]) -> Bool {
        sessions.contains(where: { $0.id == sessionID })
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
            sessionID: sessionID,
            command: command,
            workingDirectory: workingDirectory ?? ""
        )
    }
}

struct JobDraft {
    var name: String = ""
    var hostID: UUID?
    var sessionID: UUID?
    var command: String = ""
    var workingDirectory: String = ""

    var isValid: Bool {
        hostID != nil &&
        sessionID != nil &&
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

    func normalizedSessionID(in sessions: [TmuxSession]) -> UUID? {
        guard !sessions.isEmpty else {
            return nil
        }

        if let sessionID, sessions.contains(where: { $0.id == sessionID }) {
            return sessionID
        }

        if sessionID == nil {
            if let hostID {
                return sessions.first(where: { $0.hostID == hostID })?.id ?? sessions.first?.id
            }

            return sessions.first?.id
        }

        return sessionID
    }

    func selectedSessionExists(in sessions: [TmuxSession]) -> Bool {
        guard let sessionID else {
            return false
        }

        return sessions.contains(where: { $0.id == sessionID })
    }

    func availableSessions(in sessions: [TmuxSession]) -> [TmuxSession] {
        guard let hostID else {
            return sessions
        }

        return sessions.filter { $0.hostID == hostID }
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
