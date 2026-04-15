import SwiftUI

struct SessionDashboardView: View {
    let sessions: [TmuxSession]
    let hosts: [Host]
    let jobs: [Job]
    var onAdd: (() -> Void)?
    var onEdit: ((TmuxSession) -> Void)?
    var onDelete: ((TmuxSession) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                title: "Tmux Sessions",
                subtitle: "Sessions",
                buttonTitle: "Add Session",
                isPrimary: false,
                action: { onAdd?() }
            )

            if sessions.isEmpty {
                ContentUnavailableView(
                    "No tmux sessions yet",
                    systemImage: "rectangle.split.3x1",
                    description: Text("Create a tmux session per host, then launch jobs inside that session.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ForEach(sessions) { session in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(session.name)
                                    .font(.headline)
                                Text(hostSummary(for: session))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            StatusBadge(text: session.status.rawValue, tint: tint(for: session.status))
                        }

                        HStack(spacing: 12) {
                            if let workingDirectory = session.workingDirectory {
                                Text(workingDirectory)
                                    .lineLimit(1)
                            }

                            Text("\(jobCount(for: session)) job(s)")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                        if !session.isHostAvailable(in: hosts) {
                            Text("This session remains in history, but its host has been removed.")
                                .font(.footnote)
                                .foregroundStyle(.orange)
                        }

                        HStack(spacing: 10) {
                            if let onEdit {
                                Button("Edit") {
                                    onEdit(session)
                                }
                            }

                            if let onDelete {
                                Button("Delete", role: .destructive) {
                                    onDelete(session)
                                }
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .panelStyle()
    }

    private func jobCount(for session: TmuxSession) -> Int {
        jobs.filter { $0.sessionID == session.id }.count
    }

    private func hostSummary(for session: TmuxSession) -> String {
        if let host = hosts.first(where: { $0.id == session.hostID }) {
            return host.name
        }

        return "\(session.hostName) (removed)"
    }

    private func tint(for status: TmuxSessionStatus) -> Color {
        switch status {
        case .attached:
            return .green
        case .detached:
            return .blue
        case .terminated:
            return .orange
        case .unknown:
            return .gray
        }
    }
}

#Preview {
    SessionDashboardView(sessions: TmuxSession.sampleData, hosts: Host.sampleData, jobs: Job.sampleData)
        .padding()
}
