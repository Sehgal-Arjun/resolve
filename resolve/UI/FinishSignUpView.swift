import SwiftUI

struct FinishSignUpView: View {
    @EnvironmentObject private var authManager: AuthManager

    var body: some View {
        VStack(spacing: 18) {
            Text("Finish sign-in in your browser")
                .font(.system(size: 22, weight: .semibold))

            Text("Resolve now uses a secure web-based sign-in flow. If you need to create an account, complete it in the browser and return here.")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Continue") {
                authManager.login()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .frame(width: 420, height: 260)
    }
}
