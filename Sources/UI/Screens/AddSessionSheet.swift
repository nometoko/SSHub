import SwiftUI

struct AddSessionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: TmuxSessionDraft

    let title: String
    let saveButtonTitle: String
    let hosts: [Host]
    let missingHostName: String?
    let onSave: (TmuxSessionDraft) -> Bool

    init(
        title: String = "Add Session",
        saveButtonTitle: String = "Save",
        hosts: [Host],
        initialDraft: TmuxSessionDraft? = nil,
        missingHostName: String? = nil,
        onSave: @escaping (TmuxSessionDraft) -> Bool
    ) {
        self.title = title
        self.saveButtonTitle = saveButtonTitle
        self.hosts = hosts
        self.missingHostName = missingHostName
        self.onSave = onSave

        let fallbackHostID = hosts.first?.id
        var draft = initialDraft ?? TmuxSessionDraft(hostID: fallbackHostID)
        draft.hostID = draft.normalizedHostID(in: hosts)
        _draft = State(initialValue: draft)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Session Info") {
                    TextField("Session name", text: $draft.name)

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

                    TextField("Working directory (optional)", text: $draft.workingDirectory)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(title)
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
        .frame(minWidth: 460, minHeight: 260)
    }

    private var staleHostMessage: String? {
        guard draft.hostID != nil, !draft.selectedHostExists(in: hosts) else {
            return nil
        }

        return "The previously selected host was removed. Choose an existing host before saving."
    }

    private var missingHostLabel: String {
        if let missingHostName, !missingHostName.isEmpty {
            return "\(missingHostName) (removed)"
        }

        return "Removed host"
    }
}

#Preview {
    AddSessionSheet(hosts: Host.sampleData) { _ in true }
}
