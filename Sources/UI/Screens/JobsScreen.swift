import SwiftUI

struct JobsScreen: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var isPresentingAddSessionSheet = false
    @State private var isPresentingAddJobSheet = false
    @State private var editingSession: TmuxSession?
    @State private var editingJob: Job?
    @State private var searchText = ""
    @State private var selectedStatus: JobStatus?
    @State private var selectedHostID: UUID?
    @State private var selectedSessionID: UUID?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                filtersSection

                if let jobErrorMessage = appModel.jobErrorMessage {
                    Text(jobErrorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }

                SessionDashboardView(
                    sessions: filteredSessions,
                    hosts: appModel.hosts,
                    jobs: appModel.jobs,
                    onAdd: { isPresentingAddSessionSheet = true },
                    onEdit: { editingSession = $0 },
                    onDelete: appModel.deleteSession(_:)
                )

                JobDashboardView(
                    jobs: filteredJobs,
                    hosts: appModel.hosts,
                    sessions: appModel.sessions,
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
        .sheet(isPresented: $isPresentingAddSessionSheet) {
            AddSessionSheet(hosts: appModel.hosts) { draft in
                appModel.addSession(from: draft)
                return appModel.jobErrorMessage == nil
            }
        }
        .sheet(isPresented: $isPresentingAddJobSheet) {
            AddJobSheet(hosts: appModel.hosts, sessions: appModel.sessions) { draft in
                appModel.addJob(from: draft)
                return appModel.jobErrorMessage == nil
            }
        }
        .sheet(item: $editingSession) { session in
            AddSessionSheet(
                title: "Edit Session",
                saveButtonTitle: "Save",
                hosts: appModel.hosts,
                initialDraft: session.makeDraft(),
                missingHostName: session.hostName
            ) { draft in
                appModel.updateSession(session, from: draft)
                return appModel.jobErrorMessage == nil
            }
        }
        .sheet(item: $editingJob) { job in
            AddJobSheet(
                title: "Edit Job",
                saveButtonTitle: "Save",
                hosts: appModel.hosts,
                sessions: appModel.sessions,
                initialDraft: job.makeDraft(),
                missingHostName: job.hostName,
                missingSessionName: job.sessionName
            ) { draft in
                appModel.updateJob(job, from: draft)
                return appModel.jobErrorMessage == nil
            }
        }
    }

    private var filteredSessions: [TmuxSession] {
        appModel.sessions.filter { session in
            matchesSessionSearch(session) &&
            matchesSessionHost(session)
        }
    }

    private var filteredJobs: [Job] {
        appModel.jobs.filter { job in
            matchesSearch(job) &&
            matchesStatus(job) &&
            matchesHost(job) &&
            matchesSession(job)
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

                Picker("Session", selection: $selectedSessionID) {
                    Text("All sessions").tag(Optional<UUID>.none)
                    ForEach(filteredSessionOptions) { session in
                        Text(session.name).tag(Optional(session.id))
                    }
                }
                .frame(width: 180)
            }
        }
        .panelStyle()
        .onChange(of: selectedHostID) { _, newHostID in
            guard
                let selectedSessionID,
                let newHostID,
                !appModel.sessions.contains(where: { $0.id == selectedSessionID && $0.hostID == newHostID })
            else {
                return
            }

            self.selectedSessionID = nil
        }
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

    private func matchesSession(_ job: Job) -> Bool {
        guard let selectedSessionID else {
            return true
        }

        return job.sessionID == selectedSessionID
    }

    private func matchesSessionSearch(_ session: TmuxSession) -> Bool {
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return true
        }

        let query = trimmedQuery.lowercased()
        return session.name.lowercased().contains(query)
            || session.hostName.lowercased().contains(query)
            || (session.workingDirectory?.lowercased().contains(query) ?? false)
    }

    private func matchesSessionHost(_ session: TmuxSession) -> Bool {
        guard let selectedHostID else {
            return true
        }

        return session.hostID == selectedHostID
    }

    private var filteredSessionOptions: [TmuxSession] {
        appModel.sessions.filter { session in
            guard let selectedHostID else {
                return true
            }

            return session.hostID == selectedHostID
        }
    }
}

#Preview {
    JobsScreen()
        .environmentObject(AppModel())
}
