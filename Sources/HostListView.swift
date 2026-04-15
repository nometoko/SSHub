import SwiftUI

struct HostListView: View {
    enum LayoutMode {
        case compact
        case full
    }

    @EnvironmentObject private var appModel: AppModel
    let hosts: [Host]
    var layout: LayoutMode = .compact

    @State private var isPresentingAddHostSheet = false
    @State private var editingHost: Host?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                title: "SSH Hosts",
                subtitle: "Hosts",
                buttonTitle: "Add Host"
            ) {
                isPresentingAddHostSheet = true
            }

            if let hostErrorMessage = appModel.hostErrorMessage {
                Text(hostErrorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            if hosts.isEmpty {
                emptyState
            } else {
                hostRows
            }
        }
        .frame(
            maxWidth: layout == .compact ? 420 : .infinity,
            alignment: .topLeading
        )
        .panelStyle()
        .sheet(isPresented: $isPresentingAddHostSheet) {
            AddHostSheet { draft in
                appModel.addHost(from: draft)
            }
        }
        .sheet(item: $editingHost) { host in
            AddHostSheet(
                title: "Edit Host",
                saveButtonTitle: "Update",
                initialDraft: host.makeDraft()
            ) { draft in
                appModel.updateHost(host, from: draft)
            }
        }
    }

    private var hostRows: some View {
        ForEach(hosts) { host in
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(host.name)
                            .font(.title3.weight(.semibold))
                        Text(host.targetDescription)
                            .font(.body)
                            .foregroundStyle(.secondary)
                        if let statusMessage = host.statusMessage, !statusMessage.isEmpty {
                            Text(statusMessage)
                                .font(.subheadline)
                                .foregroundStyle(messageColor(for: host.status))
                                .lineLimit(layout == .compact ? 2 : nil)
                        }
                    }

                    Spacer()

                    StatusBadge(text: host.status.rawValue, tint: tint(for: host.status))
                }

                if layout == .full {
                    HStack(alignment: .center, spacing: 12) {
                        Text(host.username == nil && host.port == nil ? "Using ~/.ssh/config defaults" : "Using overrides where specified")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Button("Edit") {
                            editingHost = host
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)

                        Button(connectionButtonTitle(for: host)) {
                            handleConnectionAction(for: host)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(host.status == .checking)

                        Button("Delete", role: .destructive) {
                            appModel.deleteHost(host)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                } else {
                    HStack(spacing: 10) {
                        Spacer()
                        Button(connectionButtonTitle(for: host)) {
                            handleConnectionAction(for: host)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                        .disabled(host.status == .checking)
                    }
                }
            }
            .padding(20)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("No hosts yet")
                .font(.headline)

            Text("Add your first SSH host to keep it across app launches.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func tint(for status: HostStatus) -> Color {
        switch status {
        case .checking:
            return .orange
        case .connected:
            return .green
        case .disconnected:
            return .red
        case .unknown:
            return .gray
        }
    }

    private func messageColor(for status: HostStatus) -> Color {
        switch status {
        case .checking:
            return .orange
        case .connected:
            return .secondary
        case .disconnected:
            return .red
        case .unknown:
            return .secondary
        }
    }

    private func connectionButtonTitle(for host: Host) -> String {
        switch host.status {
        case .connected:
            return "Disconnect"
        case .checking, .disconnected, .unknown:
            return "Connect"
        }
    }

    private func handleConnectionAction(for host: Host) {
        switch host.status {
        case .connected:
            appModel.disconnectHost(host)
        case .checking:
            break
        case .disconnected, .unknown:
            appModel.reconnectHost(host)
        }
    }
}

#Preview {
    HostListView(hosts: Host.sampleData)
        .environmentObject(AppModel())
        .padding()
}
