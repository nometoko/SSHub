import SwiftUI

struct JobsScreen: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var isPresentingAddJobSheet = false
    @State private var editingJob: Job?
    @State private var searchText = ""
    @State private var selectedStatus: JobStatus?
    @State private var selectedHostID: UUID?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                filtersSection

                if let jobErrorMessage = appModel.jobErrorMessage {
                    Text(jobErrorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }

                JobDashboardView(
                    jobs: filteredJobs,
                    hosts: appModel.hosts,
                    headerTitle: "Job Management",
                    headerSubtitle: "Jobs",
                    buttonTitle: "Launch Job",
                    emptyStateTitle: emptyStateTitle,
                    emptyStateMessage: emptyStateMessage,
                    onLaunch: { isPresentingAddJobSheet = true },
                    onEdit: { editingJob = $0 },
                    onStop: appModel.stopJob(_:),
                    onRestart: appModel.restartJob(_:),
                    onDelete: appModel.deleteJob(_:)
                )
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $isPresentingAddJobSheet) {
            AddJobSheet(hosts: appModel.hosts) { draft in
                appModel.addJob(from: draft)
                return appModel.jobErrorMessage == nil
            }
        }
        .sheet(item: $editingJob) { job in
            AddJobSheet(
                title: "Edit Job",
                saveButtonTitle: "Save",
                hosts: appModel.hosts,
                initialDraft: job.makeDraft(),
                missingHostName: job.hostName
            ) { draft in
                appModel.updateJob(job, from: draft)
                return appModel.jobErrorMessage == nil
            }
        }
    }

    private var filteredJobs: [Job] {
        appModel.jobs.filter { job in
            matchesSearch(job) &&
            matchesStatus(job) &&
            matchesHost(job)
        }
    }

    private var filtersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Search and filter jobs by host, status, or command to focus on the active work.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(alignment: .center, spacing: 12) {
                TextField("Search jobs", text: $searchText)
                    .textFieldStyle(.roundedBorder)

                Picker("Status", selection: $selectedStatus) {
                    Text("All statuses").tag(Optional<JobStatus>.none)
                    ForEach(JobStatus.allCases, id: \.self) { status in
                        Text(status.rawValue.capitalized).tag(Optional(status))
                    }
                }
                .frame(width: 180)

                Picker("Host", selection: $selectedHostID) {
                    Text("All hosts").tag(Optional<UUID>.none)
                    ForEach(appModel.hosts) { host in
                        Text(host.name).tag(Optional(host.id))
                    }
                }
                .frame(width: 180)
            }
        }
        .panelStyle()
    }

    private var emptyStateTitle: String {
        appModel.jobs.isEmpty ? "No jobs yet" : "No matching jobs"
    }

    private var emptyStateMessage: String {
        appModel.jobs.isEmpty
            ? "Launch a job from a registered host to begin tracking it here."
            : "Try changing the search text or filters to widen the result set."
    }

    private func matchesSearch(_ job: Job) -> Bool {
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return true
        }

        let query = trimmedQuery.lowercased()
        return job.name.lowercased().contains(query)
            || job.hostName.lowercased().contains(query)
            || job.command.lowercased().contains(query)
            || job.progressSummary.lowercased().contains(query)
    }

    private func matchesStatus(_ job: Job) -> Bool {
        guard let selectedStatus else {
            return true
        }

        return job.status == selectedStatus
    }

    private func matchesHost(_ job: Job) -> Bool {
        guard let selectedHostID else {
            return true
        }

        return job.hostID == selectedHostID
    }
}

#Preview {
    JobsScreen()
        .environmentObject(AppModel())
}
