import SwiftUI

struct AuthenticatedView: View {
    let user: AuthManager.ClerkUser
    let onDiveIn: () -> Void
    let onSettings: () -> Void
    let onSignOut: () -> Void

    private var firstName: String {
        let trimmed = user.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let first = trimmed.split(separator: " ").first {
            return String(first)
        }
        return trimmed.isEmpty ? "there" : trimmed
    }

    private let cardWidth: CGFloat = 520
    private let cardHeight: CGFloat = 520

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
                Spacer()

                VStack(spacing: 8) {
                    Text("Hi, \(firstName). Welcome to Resolve.")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)

                    if !user.email.isEmpty {
                        Text(user.email)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .padding(.bottom, 22)
                .padding(.top, 18)
                .frame(maxWidth: .infinity)

                VStack(spacing: 10) {
                    Button {
                        onDiveIn()
                    } label: {
                        Text("Dive in")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white)
                    )

                    Button {
                        onSettings()
                    } label: {
                        Text("Settings")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.10))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                    )

                    Button {
                        onSignOut()
                    } label: {
                        Text("Sign out")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                    )
                }
                .frame(width: 300)

                Spacer()
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
