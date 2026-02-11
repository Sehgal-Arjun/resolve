import SwiftUI

struct RootPanelView: View {
    @ObservedObject var authManager: AuthManager

    private enum SignedInRoute {
        case home
        case settings
        case main
    }

    @State private var signedInRoute: SignedInRoute = .home

    var body: some View {
        Group {
            switch authManager.state {
            case .signedIn(let user):
                switch signedInRoute {
                case .home:
                    AuthenticatedView(
                        user: user,
                        onDiveIn: { signedInRoute = .main },
                        onSettings: { signedInRoute = .settings },
                        onSignOut: {
                            signedInRoute = .home
                            authManager.signOut()
                        }
                    )
                case .settings:
                    SettingsPanelView(onBack: { signedInRoute = .home })
                case .main:
                    MainAppPanelView(onBack: { signedInRoute = .home })
                }
            case .signUpNeedsDetails, .signUpNeedsPhoneCode:
                FinishSignUpView()
            case .signedOut, .signingIn:
                LandingView()
            }
        }
        .environmentObject(authManager)
        .onChange(of: authManager.state) { _, newValue in
            if case .signedIn = newValue {
                // keep current route
            } else {
                signedInRoute = .home
            }
        }
    }
}
