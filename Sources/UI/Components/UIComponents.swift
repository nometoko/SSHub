import SwiftUI

struct StatusBadge: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text.capitalized)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.14), in: Capsule())
            .foregroundStyle(tint)
    }
}

func sectionHeader(
    title: String,
    subtitle: String,
    buttonTitle: String,
    isPrimary: Bool = false,
    action: @escaping () -> Void = {}
) -> some View {
    HStack(alignment: .center) {
        VStack(alignment: .leading, spacing: 4) {
            Text(subtitle.uppercased())
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(title)
                .font(.title3.weight(.semibold))
        }

        Spacer()

        if isPrimary {
            Button(buttonTitle, action: action)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        } else {
            Button(buttonTitle, action: action)
                .buttonStyle(.bordered)
                .controlSize(.large)
        }
    }
}

struct PanelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

extension View {
    func panelStyle() -> some View {
        modifier(PanelModifier())
    }
}
