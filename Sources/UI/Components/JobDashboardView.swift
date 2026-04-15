import SwiftUI

struct JobDashboardView: View {
    let jobs: [Job]
    let hosts: [Host]
    var headerTitle: String = "Job Dashboard"
    var headerSubtitle: String = "Jobs"
    var buttonTitle: String = "Launch Job"
    var emptyStateTitle: String = "No jobs yet"
    var emptyStateMessage: String = "Launch a job to start tracking progress, logs, and status from one place."
    var onLaunch: (() -> Void)?
    var onEdit: ((Job) -> Void)?
    var onStop: ((Job) -> Void)?
    var onRestart: ((Job) -> Void)?
    var onDelete: ((Job) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                title: headerTitle,
                subtitle: headerSubtitle,
                buttonTitle: buttonTitle,
                isPrimary: true,
                action: { onLaunch?() }
            )

            if jobs.isEmpty {
                ContentUnavailableView(
                    emptyStateTitle,
                    systemImage: "terminal",
                    description: Text(emptyStateMessage)
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ForEach(jobs) { job in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(job.name)
                                    .font(.headline)
                                Text(hostSummary(for: job))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            StatusBadge(text: job.status.rawValue, tint: tint(for: job.status))
                        }

                        HStack(spacing: 12) {
                            Text(job.runtimeSummary)
                            if let executionSummary = job.executionSummary {
                                Text(executionSummary)
                            }
                            if let workingDirectory = job.workingDirectory {
                                Text(workingDirectory)
                                    .lineLimit(1)
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                        Text(job.progressSummary)
                            .font(.body)

                        if !job.isHostAvailable(in: hosts) {
                            orphanedHostWarning
                        }

                        Text(job.command)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)

                        if hasAnyActions {
                            HStack(spacing: 10) {
                                if let onEdit {
                                    Button("Edit") {
                                        onEdit(job)
                                    }
                                }

                                if job.status == .running, let onStop {
                                    Button("Stop") {
                                        onStop(job)
                                    }
                                    .disabled(!job.isHostAvailable(in: hosts))
                                }

                                if job.status != .running, let onRestart {
                                    Button("Restart") {
                                        onRestart(job)
                                    }
                                    .disabled(!job.isHostAvailable(in: hosts))
                                }

                                if let onDelete {
                                    Button("Delete", role: .destructive) {
                                        onDelete(job)
                                    }
                                }
                            }
                            .buttonStyle(.bordered)
                        }
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

    private var hasAnyActions: Bool {
        onEdit != nil || onStop != nil || onRestart != nil || onDelete != nil
    }

    private var orphanedHostWarning: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 4) {
                Text("Host Removed")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("This job still exists as history, but its host has been removed.")
                    .font(.footnote)
                    .foregroundStyle(.primary)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.orange.opacity(0.16))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.orange.opacity(0.45), lineWidth: 1)
        )
    }

    private func hostSummary(for job: Job) -> String {
        guard !job.isHostAvailable(in: hosts) else {
            return job.hostName
        }

        return "\(job.hostName) (removed)"
    }

    private func tint(for status: JobStatus) -> Color {
        switch status {
        case .running:
            return .green
        case .queued:
            return .yellow
        case .completed:
            return .blue
        case .failed:
            return .red
        case .stopped:
            return .orange
        case .unknown:
            return .gray
        }
    }
}

#Preview {
    JobDashboardView(jobs: Job.sampleData, hosts: Host.sampleData)
        .padding()
}
