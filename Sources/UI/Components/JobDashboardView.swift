import SwiftUI

struct JobDashboardView: View {
    let jobs: [Job]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Job Dashboard", subtitle: "Jobs", buttonTitle: "Launch Job", isPrimary: true)

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

                    Text("Started: \(job.startedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(job.progressSummary)
                        .font(.body)

                    Text(job.command)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(16)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .panelStyle()
    }

    private func tint(for status: JobStatus) -> Color {
        switch status {
        case .running:
            return .green
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
