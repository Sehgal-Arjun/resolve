import SwiftUI

struct LandingView: View {
    @EnvironmentObject private var authManager: AuthManager
    @ObservedObject private var settings = UserSettingsStore.shared

    private var cardWidth: CGFloat { settings.scaled(520) }
    private var cardHeight: CGFloat { settings.scaled(320) }
    private let cardCornerRadius: CGFloat = 16

    @State private var isContinueHovering = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: settings.cornerRadius(cardCornerRadius), style: .continuous)
                .fill(settings.panelTranslucency.material)
                .overlay(
                    RoundedRectangle(cornerRadius: settings.cornerRadius(cardCornerRadius), style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.30), radius: 14, x: 0, y: 0)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    ResolveLogoMark()

                    Text("Resolve")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.primary)

                    Spacer(minLength: 0)
                }

                Text("Sign in")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)

                Button("Sign in") {
                    authManager.startSignIn()
                }
                .buttonStyle(ResolvePrimaryButtonStyle(isHovering: isContinueHovering))
                .onHover { isContinueHovering = $0 }
                .keyboardShortcut(.defaultAction)

                Text("Analytical workspace")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.tertiary)

                Spacer(minLength: 0)
            }
            .padding(22)
            .frame(width: cardWidth)
            .clipShape(RoundedRectangle(cornerRadius: settings.cornerRadius(cardCornerRadius), style: .continuous))
        }
        .frame(width: cardWidth, height: cardHeight)
        .onAppear {
            CommandPanelController.shared.setSize(width: cardWidth, height: cardHeight, animated: !settings.reducedMotion)
        }
        .onChange(of: settings.panelSize) { _ in
            CommandPanelController.shared.setSize(width: cardWidth, height: cardHeight, animated: !settings.reducedMotion)
        }
    }
}

#Preview {
    LandingView()
        .environmentObject(AuthManager.shared)
        .preferredColorScheme(.dark)
}
