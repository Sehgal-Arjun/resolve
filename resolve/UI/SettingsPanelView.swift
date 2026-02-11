import SwiftUI

struct SettingsPanelView: View {
    let onBack: () -> Void

    private let cardWidth: CGFloat = 520
    private let cardHeight: CGFloat = 420

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10))
                )
                .shadow(radius: 16)

            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Button {
                        onBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    )

                    Text("Settings")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.primary)

                    Spacer()
                }
                .padding(.bottom, 16)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Coming soon")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Text("This panel is a placeholder for app settings.")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.secondary.opacity(0.85))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)
            }
            .padding(32)
        }
        .frame(width: cardWidth, height: cardHeight)
        .onAppear {
            CommandPanelController.shared.setSize(width: cardWidth, height: cardHeight, animated: true)
        }
    }
}
