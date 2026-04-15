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
    private let checkedAtFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter
    }()

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
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .center, spacing: 10) {
                            Text(host.name)
                                .font(.title3.weight(.semibold))

                            if layout == .full {
                                HStack(spacing: 8) {
                                    iconButton(
                                        systemName: "pencil",
                                        label: "Edit Host"
                                    ) {
                                        editingHost = host
                                    }

                                    iconButton(
                                        systemName: "arrow.clockwise",
                                        label: "Recheck Host",
                                        isProminent: true
                                    ) {
                                        appModel.reconnectHost(host)
                                    }
                                    .disabled(host.status == .checking)

                                    iconButton(
                                        systemName: "trash",
                                        label: "Delete Host",
                                        role: .destructive
                                    ) {
                                        appModel.deleteHost(host)
                                    }
                                }
                            }
                        }

                        Label {
                            Text(host.displayTarget)
                                .font(.subheadline.weight(.medium))
                                .monospaced()
                                .textSelection(.enabled)
                        } icon: {
                            Image(systemName: "server.rack")
                        }
                        .foregroundStyle(.secondary)

                        if let statusMessage = host.displayStatusMessage {
                            Text(statusMessage)
                                .font(.subheadline)
                                .foregroundStyle(messageColor(for: host.status))
                                .lineLimit(layout == .compact ? 2 : nil)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 8) {
                        StatusBadge(text: host.status.rawValue, tint: tint(for: host.status))

                        if let lastCheckedAt = host.lastCheckedAt {
                            Label {
                                Text("Last checked: \(checkedAtFormatter.string(from: lastCheckedAt))")
                                    .font(.footnote.weight(.medium))
                            } icon: {
                                Image(systemName: "clock")
                            }
                            .foregroundStyle(.tertiary)
                        }
                    }
                }

                if layout != .full {
                    HStack(spacing: 10) {
                        Spacer()
                        iconButton(
                            systemName: "arrow.clockwise",
                            label: "Recheck Host"
                        ) {
                            appModel.reconnectHost(host)
                        }
                        .disabled(host.status == .checking)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
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
        case .reachable:
            return .green
        case .unreachable:
            return .red
        case .unknown:
            return .gray
        }
    }

    private func messageColor(for status: HostStatus) -> Color {
        switch status {
        case .checking:
            return .orange
        case .reachable:
            return .secondary
        case .unreachable:
            return .red
        case .unknown:
            return .secondary
        }
    }

    private func iconButton(
        systemName: String,
        label: String,
        role: ButtonRole? = nil,
        isProminent: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        HostActionButton(
            systemName: systemName,
            label: label,
            role: role,
            isProminent: isProminent,
            action: action
        )
    }
}

private struct HostActionButton: View {
    let systemName: String
    let label: String
    let role: ButtonRole?
    let isProminent: Bool
    let action: () -> Void

    @State private var isHovering = false
    @State private var isShowingTooltip = false
    @State private var hoverTask: Task<Void, Never>?

    var body: some View {
        Group {
            if isProminent {
                Button(role: role, action: action) {
                    icon
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button(role: role, action: action) {
                    icon
                }
                .buttonStyle(.bordered)
            }
        }
        .controlSize(.regular)
        .accessibilityLabel(label)
        .overlay(alignment: .top) {
            if isShowingTooltip {
                Text(label)
                    .font(.caption)
                    .fixedSize()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.regularMaterial, in: Capsule())
                    .shadow(color: Color.black.opacity(0.12), radius: 8, y: 2)
                    .offset(y: -34)
                    .allowsHitTesting(false)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .zIndex(isShowingTooltip ? 10 : 0)
        .onHover { hovering in
            isHovering = hovering
            hoverTask?.cancel()

            if hovering {
                hoverTask = Task {
                    try? await Task.sleep(for: .milliseconds(150))
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        if isHovering {
                            withAnimation(.easeOut(duration: 0.12)) {
                                isShowingTooltip = true
                            }
                        }
                    }
                }
            } else {
                withAnimation(.easeOut(duration: 0.08)) {
                    isShowingTooltip = false
                }
            }
        }
        .onDisappear {
            hoverTask?.cancel()
        }
    }

    private var icon: some View {
        Image(systemName: systemName)
            .font(.body.weight(.semibold))
            .frame(width: 16, height: 16)
    }
}

#Preview {
    HostListView(hosts: Host.sampleData)
        .environmentObject(AppModel())
        .padding()
}
