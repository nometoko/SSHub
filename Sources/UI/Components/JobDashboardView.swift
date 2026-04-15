import SwiftUI

struct JobDashboardView: View {
    let jobs: [Job]
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
                                Text(job.hostName)
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
                                }

                                if job.status != .running, let onRestart {
                                    Button("Restart") {
                                        onRestart(job)
                                    }
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
    JobDashboardView(jobs: Job.sampleData)
        .padding()
}
