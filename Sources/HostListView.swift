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
            maxWidth: layout == .compact ? 360 : .infinity,
            alignment: .topLeading
        )
        .panelStyle()
        .sheet(isPresented: $isPresentingAddHostSheet) {
            AddHostSheet { draft in
                appModel.addHost(from: draft)
            }
        }
    }

    private var hostRows: some View {
        ForEach(hosts) { host in
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(host.name)
                            .font(.headline)
                        Text(host.targetDescription)
                            .foregroundStyle(.secondary)
                        if let statusMessage = host.statusMessage, !statusMessage.isEmpty {
                            Text(statusMessage)
                                .font(.footnote)
                                .foregroundStyle(messageColor(for: host.status))
                                .lineLimit(layout == .compact ? 2 : nil)
                        }
                    }

                    Spacer()

                    StatusBadge(text: host.status.rawValue, tint: tint(for: host.status))
                }

                if layout == .full {
                    HStack {
                        Text(host.username == nil && host.port == nil ? "Using ~/.ssh/config defaults" : "Using overrides where specified")
                        Spacer()
                        Button("Reconnect") {
                            appModel.reconnectHost(host)
                        }
                        .buttonStyle(.link)
                        .disabled(host.status == .checking)
                        Button("Delete", role: .destructive) {
                            delete(host)
                        }
                        .buttonStyle(.link)
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(16)
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

    private func delete(_ host: Host) {
        guard let index = appModel.hosts.firstIndex(of: host) else {
            return
        }

        appModel.deleteHosts(at: IndexSet(integer: index))
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
}

#Preview {
    HostListView(hosts: Host.sampleData)
        .environmentObject(AppModel())
        .padding()
}
