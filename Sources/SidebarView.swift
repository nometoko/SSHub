import SwiftUI

struct SidebarView: View {
    @Binding var selectedSection: SidebarSection?

    var body: some View {
        List(SidebarSection.allCases, selection: $selectedSection) { section in
            Label(section.title, systemImage: iconName(for: section))
                .tag(section)
        }
        .navigationTitle("SSHub")
        .listStyle(.sidebar)
    }

    private func iconName(for section: SidebarSection) -> String {
        switch section {
        case .dashboard:
            return "rectangle.grid.2x2"
        case .hosts:
            return "server.rack"
        case .jobs:
            return "terminal"
        case .settings:
            return "gearshape"
        }
    }
}

#Preview {
    SidebarView(selectedSection: .constant(.dashboard))
}
