import SwiftUI

struct AddHostSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: HostDraft

    let title: String
    let saveButtonTitle: String

    let onSave: (HostDraft) -> Void

    init(
        title: String = "Add Host",
        saveButtonTitle: String = "Save",
        initialDraft: HostDraft = HostDraft(),
        onSave: @escaping (HostDraft) -> Void
    ) {
        self.title = title
        self.saveButtonTitle = saveButtonTitle
        self.onSave = onSave
        _draft = State(initialValue: initialDraft)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Info") {
                    TextField("Display name", text: $draft.name)
                    TextField("Host alias or hostname", text: $draft.hostAlias)
                    TextField("Username override (optional)", text: $draft.username)
                    TextField("Port override (optional)", text: $draft.portText)
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
        .frame(minWidth: 420, minHeight: 260)
    }
}

#Preview {
    AddHostSheet { _ in }
}
