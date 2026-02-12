import SwiftUI

struct RootPanelView: View {
    @ObservedObject var authManager: AuthManager

    private enum SignedInRoute {
        case home
        case pastChats
        case howItWorks
        case settings
        case main
    }

    @State private var signedInRoute: SignedInRoute = .home
    @State private var diveInToken: NSObjectProtocol?
    @Environment(\.resolvePanelController) private var panelController

    var body: some View {
        Group {
            switch authManager.state {
            case .signedIn(let user):
                switch signedInRoute {
                case .home:
                    AuthenticatedView(
                        user: user,
                        onDiveIn: { signedInRoute = .main },
                        onPastChats: { signedInRoute = .pastChats },
                        onHowItWorks: { signedInRoute = .howItWorks },
                        onSettings: { signedInRoute = .settings },
                        onSignOut: {
                            signedInRoute = .home
                            authManager.signOut()
                        }
                    )
                case .pastChats:
                    PastChatsView(onBack: { signedInRoute = .home })
                case .howItWorks:
                    HowResolveWorksView(onBack: { signedInRoute = .home })
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
        .onAppear {
            diveInToken = NotificationCenter.default.addObserver(
                forName: diveInNotification,
                object: nil,
                queue: .main
            ) { _ in
                guard CommandPanelController.shared === panelController else { return }
                if case .signedIn = authManager.state {
                    signedInRoute = .main
                }
            }
        }
        .onDisappear {
            if let token = diveInToken {
                NotificationCenter.default.removeObserver(token)
            }
        }
    }
}
