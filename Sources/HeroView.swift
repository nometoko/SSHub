import SwiftUI

struct HeroView: View {
    let statusText: String

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("SSH Job Control")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Text("SSHub")
                    .font(.system(size: 52, weight: .bold, design: .rounded))

                Text("複数の SSH ホスト上で動く学習・simulation ジョブを、起動・監視・停止するための macOS アプリ。")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 16)

            VStack(alignment: .leading, spacing: 8) {
                Text("Backend status")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Text(statusText)
                    .font(.headline)
            }
            .frame(width: 280, alignment: .leading)
            .padding(18)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .padding(24)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.09, green: 0.18, blue: 0.27),
                    Color(red: 0.16, green: 0.31, blue: 0.38)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .foregroundStyle(.white)
    }
}

#Preview {
    HeroView(statusText: "macOS native skeleton ready")
        .padding()
}
