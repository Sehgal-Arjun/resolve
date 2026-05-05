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
    /// Two ways onboarding can become active:
    ///   1. `inOnboarding` is explicitly set true (first launch with a
    ///      pending tour, or after an in-session sign-out / Replay tap).
    ///      This is the path that keeps `OnboardingFlowView` mounted through
    ///      the entire sign-in arc, so the unfurl doesn't replay mid-flow.
    ///   2. The user is unambiguously signed-out (not authenticated AND not
    ///      loading) — this catches relaunches with no/expired tokens, where
    ///      `inOnboarding` initialized to `false` because the persistent
    ///      `hasCompletedOnboarding` flag is true. Without this fallback,
    ///      RootPanelView's body would render nothing and the user would
    ///      see a transparent panel after pressing ⌘ ;.
    private var shouldShowOnboarding: Bool {
        guard isPrimaryPanel else { return false }
        if inOnboarding { return true }
        return !authManager.isAuthenticated && !authManager.isLoadingAuth
    }

    /// Builds the ⌘K command-menu action list dynamically from the
    /// current auth state and route. Items that wouldn't make sense for
    /// the current view (e.g. "Go home" when already on home) are
    /// omitted rather than being shown disabled. The `keys` glyph for
    /// each row comes from the shortcut catalog (see
    /// `hotkeys/KeyboardShortcuts.swift`) so the menu and the rest of
    /// the app stay in sync.
    private var cmdKActions: [CmdKAction] {
        func keys(_ id: String) -> String { KeyboardShortcutCatalog.keys(forId: id) }

        var actions: [CmdKAction] = []

        if authManager.isAuthenticated {
            if signedInRoute != .main {
                actions.append(CmdKAction(
                    id: "newchat", title: "New Chat",
                    icon: "plus.bubble", keys: keys("newChat")
                ) {
                    signedInRoute = .main
                })
            }
            if signedInRoute != .home {
                actions.append(CmdKAction(
                    id: "home", title: "Go home",
                    icon: "house", keys: keys("back")
                ) {
                    signedInRoute = .home
                })
            }
            if signedInRoute != .pastChats {
                actions.append(CmdKAction(
                    id: "pastchats", title: "Past Chats",
                    icon: "clock.arrow.circlepath", keys: ""
                ) {
                    signedInRoute = .pastChats
                })
            }
            if signedInRoute != .howItWorks {
                actions.append(CmdKAction(
                    id: "howitworks", title: "How Resolve Works",
                    icon: "questionmark.circle", keys: ""
                ) {
                    signedInRoute = .howItWorks
                })
            }
            if isPrimaryPanel, signedInRoute != .settings {
                actions.append(CmdKAction(
                    id: "settings", title: "Settings",
                    icon: "gearshape", keys: keys("settings")
                ) {
                    signedInRoute = .settings
                })
            }

            // Chat-context actions. The menu fires these via notifications;
            // ChatPaletteView listens and gates on its own active-panel
            // identity + phase, so picking these from a non-chat route is
            // a quiet no-op rather than a crash.
            actions.append(CmdKAction(
                id: "resolve", title: "Resolve",
                icon: "wand.and.stars", keys: keys("resolve")
            ) {
                NotificationCenter.default.post(name: resolveRoundNotification, object: nil)
            })
            actions.append(CmdKAction(
                id: "previousRound", title: "Previous round",
                icon: "chevron.left.circle", keys: keys("previousRound")
            ) {
                NotificationCenter.default.post(name: previousRoundNotification, object: nil)
            })
            actions.append(CmdKAction(
                id: "nextRound", title: "Next round",
                icon: "chevron.right.circle", keys: keys("nextRound")
            ) {
                NotificationCenter.default.post(name: nextRoundNotification, object: nil)
            })
            actions.append(CmdKAction(
                id: "closeDrawer", title: "Close advocate drawer",
                icon: "sidebar.right", keys: keys("closeDrawer")
            ) {
                NotificationCenter.default.post(name: closeAdvocateDrawerNotification, object: nil)
            })
            actions.append(CmdKAction(
                id: "copySummary", title: "Copy arbiter summary",
                icon: "doc.on.doc", keys: keys("copySummary")
            ) {
                NotificationCenter.default.post(name: copyArbiterSummaryNotification, object: nil)
            })
            actions.append(CmdKAction(
                id: "exportChat", title: "Export chat as markdown",
                icon: "square.and.arrow.up", keys: keys("exportChat")
            ) {
                NotificationCenter.default.post(name: exportChatMarkdownNotification, object: nil)
            })

            actions.append(CmdKAction(
                id: "signout", title: "Sign Out",
                icon: "rectangle.portrait.and.arrow.right", keys: ""
            ) {
                signedInRoute = .home
                authManager.signOut()
            })
        }

        actions.append(CmdKAction(
            id: "togglepalette", title: "Hide Resolve",
            icon: "sparkles", keys: keys("togglePalette")
        ) {
            CommandPanelManager.shared.smartToggle()
        })
        actions.append(CmdKAction(
            id: "newinstance", title: "Open New Instance",
            icon: "rectangle.on.rectangle", keys: keys("newInstance")
        ) {
            CommandPanelManager.shared.newInstance()
        })
        actions.append(CmdKAction(
            id: "quit", title: "Quit Resolve",
            icon: "power", keys: keys("quit")
        ) {
            NSApplication.shared.terminate(nil)
        })

        return actions
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
        .background {
            // Hidden ⌘K trigger. Lives in `.background` so it doesn't
            // affect layout but still lives in the SwiftUI hierarchy
            // when the panel is the key window. The menu itself opens
            // as a separate, screen-centered window — see CmdKWindowController.
            Button("") {
                CmdKWindowController.shared.toggle(actions: cmdKActions)
            }
            .keyboardShortcut("k", modifiers: .command)
            .opacity(0)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
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
