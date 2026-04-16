import SwiftUI

struct AddJobSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: JobDraft

    let title: String
    let saveButtonTitle: String
    let hosts: [Host]
    let sessions: [TmuxSession]
    let missingHostName: String?
    let missingSessionName: String?
    let onSave: (JobDraft) -> Bool

    init(
        title: String = "Launch Job",
        saveButtonTitle: String = "Launch",
        hosts: [Host],
        sessions: [TmuxSession],
        initialDraft: JobDraft? = nil,
        missingHostName: String? = nil,
        missingSessionName: String? = nil,
        onSave: @escaping (JobDraft) -> Bool
    ) {
        self.title = title
        self.saveButtonTitle = saveButtonTitle
        self.hosts = hosts
        self.sessions = sessions
        self.missingHostName = missingHostName
        self.missingSessionName = missingSessionName
        self.onSave = onSave

        let fallbackHostID = hosts.first?.id
        var draft = initialDraft ?? JobDraft(hostID: fallbackHostID)
        draft.hostID = draft.normalizedHostID(in: hosts)
        draft.sessionID = draft.normalizedSessionID(in: draft.availableSessions(in: sessions))
        _draft = State(initialValue: draft)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Job Info") {
                    TextField("Job name", text: $draft.name)

                    Picker("Host", selection: Binding(get: { draft.hostID }, set: { draft.hostID = $0 })) {
                        if let missingHostID = draft.hostID, !draft.selectedHostExists(in: hosts) {
                            Text(missingHostLabel)
                                .tag(Optional(missingHostID))
                        }

                        ForEach(hosts) { host in
                            Text(host.name)
                                .tag(Optional(host.id))
                        }
                    }

                    if let staleHostMessage {
                        Text(staleHostMessage)
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }

                    Picker("Tmux session", selection: Binding(get: { draft.sessionID }, set: { draft.sessionID = $0 })) {
                        if let missingSessionID = draft.sessionID, !draft.selectedSessionExists(in: availableSessions) {
                            Text(missingSessionLabel)
                                .tag(Optional(missingSessionID))
                        }

                        ForEach(availableSessions) { session in
                            Text(session.name)
                                .tag(Optional(session.id))
                        }
                    }

                    if let staleSessionMessage {
                        Text(staleSessionMessage)
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }

                    TextField("Working directory (optional)", text: $draft.workingDirectory)
                    TextField("Command", text: $draft.command, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(title)
            .onChange(of: draft.hostID) { _, newHostID in
                let sessionsForHost = sessions.filter { $0.hostID == newHostID }
                if let selectedSessionID = draft.sessionID,
                   sessionsForHost.contains(where: { $0.id == selectedSessionID }) {
                    return
                }

                draft.sessionID = sessionsForHost.first?.id
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(saveButtonTitle) {
                        if onSave(draft) {
                            dismiss()
                        }
                    }
                    .disabled(!draft.isValid)
                }
            }
        }
        .frame(minWidth: 480, minHeight: 320)
    }

    private var staleHostMessage: String? {
        guard draft.hostID != nil, !draft.selectedHostExists(in: hosts) else {
            return nil
        }

        return "The previously selected host was removed. Choose an existing host before saving."
    }

    private var availableSessions: [TmuxSession] {
        draft.availableSessions(in: sessions)
    }

    private var staleSessionMessage: String? {
        guard draft.sessionID != nil, !draft.selectedSessionExists(in: availableSessions) else {
            return nil
        }

        if availableSessions.isEmpty {
            return "No tmux session exists for this host yet. Create one before launching the job."
        }

        return "The previously selected tmux session is no longer available for this host."
    }

    private var missingHostLabel: String {
        if let missingHostName, !missingHostName.isEmpty {
            return "\(missingHostName) (removed)"
        }

        return "Removed host"
    }

    private var missingSessionLabel: String {
        if let missingSessionName, !missingSessionName.isEmpty {
            return "\(missingSessionName) (removed)"
        }

        return "Removed session"
    }
}

#Preview {
    AddJobSheet(hosts: Host.sampleData, sessions: TmuxSession.sampleData) { _ in true }
}
