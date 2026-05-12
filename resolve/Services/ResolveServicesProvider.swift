import AppKit

/// Handles the macOS Service entry "Ask Resolve" — wired up in
/// `Info.plist` under `NSServices` and registered as the app's
/// services provider in `AppDelegate.applicationDidFinishLaunching`.
///
/// When a user selects text in any app and right-clicks → Services →
/// Ask Resolve, AppKit hands us the pasteboard and we forward the
/// trimmed text via `askResolveServiceNotification`. RootPanelView
/// listens for that notification and routes the user into a new
/// auto-sending chat using the existing `pendingPromptForNewChat`
/// plumbing.
@MainActor
final class ResolveServicesProvider: NSObject {

    /// Queue for service-invoked text when the panel hasn't mounted
    /// RootPanelView yet. Without this, the very first "Ask Resolve"
    /// invocation after Resolve has been hidden gets swallowed: the
    /// notification fires before RootPanelView's `.onAppear` observer
    /// is registered. Reads + writes happen on the main actor.
    static var pendingServiceText: String?

    /// Single dispatch path shared by the macOS Service handler, the
    /// global ⌘⇧A shortcut handler, and the menu-bar "Ask Resolve"
    /// item. Foregrounds the app, surfaces the panel, queues the
    /// prompt for RootPanelView's onAppear drain, and posts the live
    /// notification for any already-mounted observer.
    static func dispatch(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        pendingServiceText = trimmed

        NSApp.activate(ignoringOtherApps: true)
        CommandPanelManager.shared.showAll()

        NotificationCenter.default.post(
            name: askResolveServiceNotification,
            object: nil,
            userInfo: ["text": trimmed]
        )
    }

    /// Synthesizes ⌘C in whatever app is frontmost, waits a beat for
    /// the pasteboard to update, then dispatches the captured text
    /// into a new Resolve chat. The previous pasteboard contents are
    /// restored so the user's clipboard isn't clobbered. Requires
    /// Accessibility permission on first invocation — macOS will
    /// prompt automatically.
    ///
    /// If nothing was selected (or no app responds to ⌘C), this is a
    /// quiet no-op aside from showing the panel — the user can type a
    /// prompt manually.
    static func grabSelectionAndDispatch() {
        let pasteboard = NSPasteboard.general
        let priorChangeCount = pasteboard.changeCount
        let priorContents = pasteboard.string(forType: .string)

        // Synthesize ⌘C. Virtual key codes: 0x08 = "c". The flag mask
        // is set on the keyDown event so the receiving app sees a
        // proper Cmd-modified C, identical to a real ⌘C.
        let source = CGEventSource(stateID: .combinedSessionState)
        guard
            let cDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true),
            let cUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
        else {
            // CGEvent creation failed (no Accessibility permission, most
            // likely). Surface the panel so the user can type their
            // question manually.
            NSApp.activate(ignoringOtherApps: true)
            CommandPanelManager.shared.showAll()
            return
        }
        cDown.flags = .maskCommand
        cUp.flags = .maskCommand
        cDown.post(tap: .cgAnnotatedSessionEventTap)
        cUp.post(tap: .cgAnnotatedSessionEventTap)

        // Give the frontmost app a tick to handle ⌘C before we read
        // the pasteboard. 120ms covers the slow path on most apps.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { @MainActor in
            let copied: String? = pasteboard.string(forType: .string)
            let captured = pasteboard.changeCount > priorChangeCount
                ? copied?.trimmingCharacters(in: .whitespacesAndNewlines)
                : nil

            // Restore the user's previous clipboard contents so this
            // gesture is non-destructive.
            if let priorContents {
                pasteboard.clearContents()
                pasteboard.setString(priorContents, forType: .string)
            }

            if let captured, !captured.isEmpty {
                dispatch(text: captured)
            } else {
                // Nothing was selected — just show the panel and let
                // the user type. Equivalent to ⌘N from anywhere.
                NSApp.activate(ignoringOtherApps: true)
                CommandPanelManager.shared.showAll()
            }
        }
    }

    /// Selector signature is dictated by the Services architecture.
    /// `@objc` is required so AppKit can find this method by name
    /// (`NSMessage = "askResolve"` in Info.plist resolves to the
    /// selector `askResolve:userData:error:`).
    @objc func askResolve(
        _ pasteboard: NSPasteboard,
        userData: String?,
        error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        guard let raw = pasteboard.string(forType: .string) else {
            error.pointee = "No text available on the pasteboard." as NSString
            return
        }

        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            error.pointee = "Selected text is empty." as NSString
            return
        }

        Self.dispatch(text: trimmed)
    }
}
