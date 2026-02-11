import SwiftUI

struct AuthenticatedView: View {
    let user: AuthManager.ClerkUser
    let onSignOut: () -> Void

    private var firstName: String {
        let trimmed = user.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let first = trimmed.split(separator: " ").first {
            return String(first)
        }
        return trimmed.isEmpty ? "there" : trimmed
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10))
                )
                .shadow(radius: 16)

            VStack(alignment: .leading, spacing: 14) {
                Text("Hi, \(firstName)")
                    .font(.system(size: 26, weight: .semibold))

                if !user.email.isEmpty {
                    Text(user.email)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }

                Button {
                    onSignOut()
                } label: {
                    Text("Sign out")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                )
                .frame(width: 160)

                Spacer(minLength: 0)
            }
            .padding(28)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}
