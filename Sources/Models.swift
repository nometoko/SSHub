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

    static let sampleData: [Host] = [
        Host(id: UUID(), name: "gpu-01", hostAlias: "gpu-01", username: nil, port: nil, status: .connected, statusMessage: "Connection OK"),
        Host(id: UUID(), name: "sim-lab", hostAlias: "sim-lab", username: "iwamoto", port: 2222, status: .disconnected, statusMessage: "Connection timed out")
    ]
}

enum HostStatus: String, Codable {
    case checking
    case connected
    case disconnected
    case unknown
}

extension Host {
    func withStatus(_ status: HostStatus, message: String? = nil) -> Host {
        Host(
            id: id,
            name: name,
            hostAlias: hostAlias,
            username: username,
            port: port,
            status: status,
            statusMessage: message
        )
    }

    var targetDescription: String {
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
            statusMessage: nil
        )
    }
}

struct Job: Identifiable {
    let id: UUID
    let name: String
    let hostName: String
    let status: JobStatus
    let progressSummary: String
    let startedAt: Date
    let command: String

    static let sampleData: [Job] = [
        Job(
            id: UUID(),
            name: "train-resnet50",
            hostName: "gpu-01",
            status: .running,
            progressSummary: "Epoch 3/10",
            startedAt: .now.addingTimeInterval(-4200),
            command: "python train.py --config configs/resnet50.yaml"
        ),
        Job(
            id: UUID(),
            name: "fluid-sim-case7",
            hostName: "sim-lab",
            status: .failed,
            progressSummary: "stderr tail available",
            startedAt: .now.addingTimeInterval(-11600),
            command: "./run_simulation.sh case7"
        )
    ]
}

enum JobStatus: String {
    case running
    case completed
    case failed
    case stopped
    case unknown
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
