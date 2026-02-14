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
    @State private var selectedConversationId: UUID?
    @State private var diveInToken: NSObjectProtocol?
    @Environment(\.resolvePanelController) private var panelController

    var body: some View {
        Group {
            if authManager.isLoadingAuth {
                Text("Signing in...")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            } else if authManager.isAuthenticated, let user = authManager.currentUser {
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
                    PastChatsView(
                        onBack: { signedInRoute = .home },
                        onOpenConversation: { conversationId in
                            selectedConversationId = conversationId
                            signedInRoute = .main
                        }
                    )
                case .howItWorks:
                    HowResolveWorksView(onBack: { signedInRoute = .home })
                case .settings:
                    SettingsPanelView(onBack: { signedInRoute = .home })
                case .main:
                    MainAppPanelView(
                        initialConversationId: selectedConversationId,
                        onBack: {
                            selectedConversationId = nil
                            signedInRoute = .home
                        }
                    )
                }
            } else {
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
            Task { await authManager.refreshAuthState() }
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
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await authManager.refreshAuthState() }
        }
        .onDisappear {
            if let token = diveInToken {
                NotificationCenter.default.removeObserver(token)
            }
        }
    }
}
