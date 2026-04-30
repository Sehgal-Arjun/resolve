import SwiftUI

struct RootPanelView: View {
    @ObservedObject var authManager: AuthManager
    @ObservedObject private var settings = UserSettingsStore.shared

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
    @State private var openSettingsToken: NSObjectProtocol?
    /// Runtime "are we currently in the onboarding flow" gate. Independent
    /// of the persistent `hasCompletedOnboarding` flag — that one tracks
    /// "has the user ever finished the tour" and never resets after first
    /// completion. This `@State` is what flips true on every sign-out (so
    /// the unfurl + sign-in card play again) and false on `onComplete`.
    @State private var inOnboarding: Bool = !UserSettingsStore.shared.hasCompletedOnboarding
    @Environment(\.resolvePanelController) private var panelController

    private var isPrimaryPanel: Bool {
        panelController?.isPrimary ?? true
    }

    /// True whenever the user should be looking at the onboarding flow.
    /// Driven entirely by the `inOnboarding` runtime flag so SwiftUI keeps
    /// the same `OnboardingFlowView` identity across every auth state
    /// transition mid-flow — that's what prevents the unfurl from replaying
    /// when state flips through `.signingIn`/`.signedIn`. Whether to enter
    /// onboarding in the first place is decided at view init (first-time
    /// user) and on `.signedOut` transitions (sign-out replays the flow).
    private var shouldShowOnboarding: Bool {
        isPrimaryPanel && inOnboarding
    }

    var body: some View {
        Group {
            if shouldShowOnboarding {
                OnboardingFlowView(onComplete: { diveInAfter in
                    settings.hasCompletedOnboarding = true
                    inOnboarding = false
                    if diveInAfter {
                        signedInRoute = .main
                    } else {
                        // Reset to home so a user replaying from Settings
                        // doesn't land back inside Settings after the flow.
                        signedInRoute = .home
                    }
                })
            } else if authManager.isAuthenticated, let user = authManager.currentUser {
                switch signedInRoute {
                case .home:
                    AuthenticatedView(
                        user: user,
                        isPrimary: isPrimaryPanel,
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
            } else if authManager.isLoadingAuth {
                Text("Signing in...")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .environmentObject(authManager)
        .tint(settings.resolvedAccentColor)
        .onChange(of: settings.cornerRadiusStyle) { _, _ in
            CommandPanelManager.shared.invalidateAllShadows()
        }
        .onChange(of: settings.panelTranslucency) { _, _ in
            CommandPanelManager.shared.invalidateAllShadows()
        }
        .onChange(of: settings.panelAnchor) { _, _ in
            CommandPanelManager.shared.reapplyAnchorToAll()
        }
        .onChange(of: settings.hideOnFocusLoss) { _, newValue in
            CommandPanelManager.shared.applyHideOnFocusLossToAll(newValue)
        }
        .onChange(of: authManager.state) { _, newValue in
            if case .signedIn = newValue {
                // keep current route
            } else if case .signedOut = newValue {
                // Sign-out replays onboarding. The persistent
                // `hasCompletedOnboarding` flag stays `true` (so we know
                // the user has seen the tour before and can skip the
                // hotkey teaching beat), but `inOnboarding` flips to true
                // to re-enter the flow.
                signedInRoute = .home
                inOnboarding = true
            } else {
                signedInRoute = .home
            }
        }
        .onChange(of: settings.hasCompletedOnboarding) { _, newValue in
            // The "Replay onboarding" button in Settings flips this to
            // `false`. Re-enter the flow when that happens. The opposite
            // case (`true` → set by `onComplete`) is already handled
            // inside the onComplete callback above.
            if !newValue {
                inOnboarding = true
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
            openSettingsToken = NotificationCenter.default.addObserver(
                forName: openSettingsNotification,
                object: nil,
                queue: .main
            ) { _ in
                // Settings only lives on the original instance. The command
                // already filters this, but guard here too in case the
                // notification is posted from anywhere else.
                guard panelController?.isPrimary == true else { return }
                if case .signedIn = authManager.state {
                    signedInRoute = .settings
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
            if let token = openSettingsToken {
                NotificationCenter.default.removeObserver(token)
            }
        }
    }
}
