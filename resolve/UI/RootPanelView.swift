import SwiftUI

struct RootPanelView: View {
    @ObservedObject var authManager: AuthManager

    var body: some View {
        Group {
            switch authManager.state {
            case .signedIn(let user):
                AuthenticatedView(user: user, onSignOut: { authManager.signOut() })
            case .signUpNeedsDetails, .signUpNeedsPhoneCode:
                FinishSignUpView()
            case .signedOut, .signingIn:
                LandingView()
            }
        }
        .environmentObject(authManager)
    }
}
