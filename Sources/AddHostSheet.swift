import SwiftUI

struct AddHostSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft = HostDraft()

    let onSave: (HostDraft) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Info") {
                    TextField("Display name", text: $draft.name)
                    TextField("Host alias or hostname", text: $draft.hostAlias)
                    TextField("Username", text: $draft.username)
                    TextField(
                        "Port",
                        value: $draft.port,
                        format: .number
                    )
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Add Host")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
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
