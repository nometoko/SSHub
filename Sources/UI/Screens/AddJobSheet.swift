import SwiftUI

struct AddJobSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: JobDraft

    let title: String
    let saveButtonTitle: String
    let hosts: [Host]
    let onSave: (JobDraft) -> Void

    init(
        title: String = "Launch Job",
        saveButtonTitle: String = "Launch",
        hosts: [Host],
        initialDraft: JobDraft? = nil,
        onSave: @escaping (JobDraft) -> Void
    ) {
        self.title = title
        self.saveButtonTitle = saveButtonTitle
        self.hosts = hosts
        self.onSave = onSave

        let fallbackHostID = hosts.first?.id
        _draft = State(initialValue: initialDraft ?? JobDraft(hostID: fallbackHostID))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Job Info") {
                    TextField("Job name", text: $draft.name)

                    Picker("Host", selection: Binding(
                        get: { draft.hostID ?? hosts.first?.id },
                        set: { draft.hostID = $0 }
                    )) {
                        ForEach(hosts) { host in
                            Text(host.name)
                                .tag(Optional(host.id))
                        }
                    }

                    TextField("Working directory (optional)", text: $draft.workingDirectory)
                    TextField("Command", text: $draft.command, axis: .vertical)
                        .lineLimit(3...6)
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
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(!draft.isValid)
                }
            }
        }
        .frame(minWidth: 480, minHeight: 320)
    }
}

#Preview {
    AddJobSheet(hosts: Host.sampleData) { _ in }
}
