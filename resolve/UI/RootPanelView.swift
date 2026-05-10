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
    /// One-shot prompt forwarded to a freshly-mounted ChatPaletteView so
    /// the chat opens with the user's question already in flight. Used
    /// by Past Chats' empty-state "try an example" picker. Cleared on
    /// chat back-navigation so a subsequent visit to .main starts blank.
    @State private var pendingPromptForNewChat: String? = nil
    @State private var diveInToken: NSObjectProtocol?
    @State private var openSettingsToken: NSObjectProtocol?
    /// Runtime "are we currently in the onboarding flow" gate. Independent
    /// of the persistent `hasCompletedOnboarding` flag — that one tracks
    /// "has the user ever finished the tour" and never resets after first
    /// completion. This `@State` is what flips true on every sign-out (so
    /// the unfurl + sign-in card play again) and false on `onComplete`.
    @State private var inOnboarding: Bool = !UserSettingsStore.shared.hasCompletedOnboarding
    /// Drives the "Sign out?" confirmation card. Triggered by the
    /// Sign Out link, the ⌘⇧S shortcut, and the ⌘K menu row — all
    /// route through this so the user can't sign out by accident.
    @State private var showSignOutConfirmation = false
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
                    icon: "questionmark.circle", keys: keys("howItWorks")
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
            // identity + phase. Rows are grayed (and unfireable) whenever
            // we're not on the chat route, so users can still see the
            // chord but aren't misled into clicking a no-op.
            let chatInactive = signedInRoute != .main
            actions.append(CmdKAction(
                id: "resolve", title: "Resolve",
                icon: "wand.and.stars", keys: keys("resolve"),
                action: {
                    NotificationCenter.default.post(name: resolveRoundNotification, object: nil)
                },
                disabled: chatInactive
            ))
            actions.append(CmdKAction(
                id: "previousRound", title: "Previous round",
                icon: "chevron.left.circle", keys: keys("previousRound"),
                action: {
                    NotificationCenter.default.post(name: previousRoundNotification, object: nil)
                },
                disabled: chatInactive
            ))
            actions.append(CmdKAction(
                id: "nextRound", title: "Next round",
                icon: "chevron.right.circle", keys: keys("nextRound"),
                action: {
                    NotificationCenter.default.post(name: nextRoundNotification, object: nil)
                },
                disabled: chatInactive
            ))
            actions.append(CmdKAction(
                id: "closeDrawer", title: "Close advocate drawer",
                icon: "sidebar.right", keys: keys("closeDrawer"),
                action: {
                    NotificationCenter.default.post(name: closeAdvocateDrawerNotification, object: nil)
                },
                disabled: chatInactive
            ))
            actions.append(CmdKAction(
                id: "copySummary", title: "Copy arbiter summary",
                icon: "doc.on.doc", keys: keys("copySummary"),
                action: {
                    NotificationCenter.default.post(name: copyArbiterSummaryNotification, object: nil)
                },
                disabled: chatInactive
            ))
            actions.append(CmdKAction(
                id: "exportChat", title: "Export chat as markdown",
                icon: "square.and.arrow.up", keys: keys("exportChat"),
                action: {
                    NotificationCenter.default.post(name: exportChatMarkdownNotification, object: nil)
                },
                disabled: chatInactive
            ))

            actions.append(CmdKAction(
                id: "signout", title: "Sign out",
                icon: "rectangle.portrait.and.arrow.right", keys: keys("signOut")
            ) {
                showSignOutConfirmation = true
            })
        }

        actions.append(CmdKAction(
            id: "cycleStanceGlow", title: "Cycle ambient stance glow",
            icon: "circle.dashed", keys: keys("cycleStanceGlow"),
            action: {
                UserSettingsStore.shared.cycleAmbientStanceGlow()
            },
            disabled: signedInRoute != .main
        ))
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

        // Push disabled rows to the bottom so the menu's enabled half
        // stays compact at the top. `filter` preserves relative order
        // within each partition, so the visible grouping each user
        // built their muscle memory around is preserved among enabled
        // rows; disabled rows trail in the same relative order they
        // were declared.
        return actions.filter { !$0.disabled } + actions.filter { $0.disabled }
    }

    var body: some View {
        routeContent
            .background { hiddenGlobalShortcuts }
            .overlay {
                if showSignOutConfirmation {
                    signOutConfirmationOverlay
                        .transition(.opacity)
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

    /// Top-level route dispatch — onboarding vs. signed-in vs. loading.
    /// Extracted from `body` so the type checker has a smaller chunk to
    /// chew on; SwiftUI's body inference times out on the original
    /// inlined version.
    @ViewBuilder
    private var routeContent: some View {
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
            signedInContent(user: user)
        } else if authManager.isLoadingAuth {
            Text("Signing in...")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func signedInContent(user: AuthManager.ClerkUser) -> some View {
        switch signedInRoute {
        case .home:
            AuthenticatedView(
                user: user,
                isPrimary: isPrimaryPanel,
                onDiveIn: { signedInRoute = .main },
                onPastChats: { signedInRoute = .pastChats },
                onHowItWorks: { signedInRoute = .howItWorks },
                onSettings: { signedInRoute = .settings },
                onSignOut: { showSignOutConfirmation = true }
            )
        case .pastChats:
            PastChatsView(
                onBack: { signedInRoute = .home },
                onOpenConversation: { conversationId in
                    selectedConversationId = conversationId
                    pendingPromptForNewChat = nil
                    signedInRoute = .main
                },
                onStartChatWithPrompt: { prompt in
                    selectedConversationId = nil
                    pendingPromptForNewChat = prompt
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
                initialPrompt: pendingPromptForNewChat,
                onBack: {
                    selectedConversationId = nil
                    pendingPromptForNewChat = nil
                    signedInRoute = .home
                }
            )
        }
    }

    /// Hidden 0×0 buttons that capture global key chords while the
    /// panel is the key window. Lives in `.background` so it doesn't
    /// affect layout.
    private var hiddenGlobalShortcuts: some View {
        Group {
            // ⌘ K — open the command menu
            Button("") {
                CmdKWindowController.shared.toggle(actions: cmdKActions)
            }
            .keyboardShortcut("k", modifiers: .command)

            // ⌘ H — jump to the "How Resolve Works" page
            Button("") { signedInRoute = .howItWorks }
                .keyboardShortcut("h", modifiers: .command)
                .disabled(!authManager.isAuthenticated || signedInRoute == .howItWorks)

            // ⌘ ⇧ S — open the sign-out confirmation
            Button("") { showSignOutConfirmation = true }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(!authManager.isAuthenticated || showSignOutConfirmation)
        }
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }

    /// Sign-out confirmation card. Tapping the dim backdrop or pressing
    /// Esc cancels; ⌘↵ confirms and signs out. Lives as an `.overlay`
    /// on the root, so it covers every route and disappears the moment
    /// the user dismisses or completes it.
    private var signOutConfirmationOverlay: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { showSignOutConfirmation = false }

            VStack(alignment: .leading, spacing: 14) {
                Text("Sign out?")
                    .font(.system(size: 16, weight: .semibold))

                Text("You'll need to sign in again to use Resolve.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Spacer(minLength: 0)

                    Button {
                        showSignOutConfirmation = false
                    } label: {
                        HStack(spacing: 6) {
                            Text("Cancel")
                            if settings.showKeyboardHintChips {
                                Text("esc")
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                    }
                    .buttonStyle(.plain)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                    )
                    .keyboardShortcut(.cancelAction)

                    Button {
                        showSignOutConfirmation = false
                        signedInRoute = .home
                        authManager.signOut()
                    } label: {
                        HStack(spacing: 6) {
                            Text("Sign out")
                            if settings.showKeyboardHintChips {
                                Text("⌘ ↵")
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(.primary.opacity(0.85))
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.red.opacity(0.85))
                    )
                    .keyboardShortcut(.return, modifiers: .command)
                }
            }
            .padding(20)
            .frame(width: 360)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(settings.panelTranslucency.material)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.45), radius: 30, x: 0, y: 8)
        }
    }
}
