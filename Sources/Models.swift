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
    let username: String
    let port: Int
    let status: HostStatus

    static let sampleData: [Host] = [
        Host(id: UUID(), name: "gpu-01", hostAlias: "gpu-01.internal", username: "iwamoto", port: 22, status: .connected),
        Host(id: UUID(), name: "sim-lab", hostAlias: "sim-lab.internal", username: "iwamoto", port: 22, status: .disconnected)
    ]
}

enum HostStatus: String, Codable {
    case connected
    case disconnected
    case unknown
}

struct HostDraft {
    var name: String = ""
    var hostAlias: String = ""
    var username: String = NSUserName()
    var port: Int = 22

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !hostAlias.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (1...65535).contains(port)
    }

    func makeHost() -> Host {
        Host(
            id: UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            hostAlias: hostAlias.trimmingCharacters(in: .whitespacesAndNewlines),
            username: username.trimmingCharacters(in: .whitespacesAndNewlines),
            port: port,
            status: .unknown
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
