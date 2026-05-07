import Foundation
import UserNotifications

/// Thin wrapper around `UNUserNotificationCenter` for Resolve's
/// background "stage complete" notifications. Authorization is
/// requested lazily on the first send attempt; subsequent calls reuse
/// the cached authorization result.
@MainActor
final class ResolveNotifications: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ResolveNotifications()

    private let center = UNUserNotificationCenter.current()
    /// Tracks whether we've already asked the system for authorization
    /// in this app session. Without it we'd ask repeatedly and spam the
    /// user (and the system silently denies after the first prompt).
    private var hasRequestedAuthorization = false

    private override init() {
        super.init()
        // Setting ourselves as the delegate is what lets us override
        // `willPresent` and force the banner to display even when
        // Resolve is the foregrounded app — without this, macOS
        // silently swallows notifications coming from the active app
        // and the user sees nothing.
        center.delegate = self
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    /// Posts a "stage complete" notification. Caller is responsible for
    /// gating on the user setting and on panel visibility — this method
    /// only handles the platform side.
    ///
    /// - Parameters:
    ///   - stage: Short descriptor of which stage just finished
    ///     (e.g. "Initial response", "Round 2"). Becomes the title
    ///     prefix.
    ///   - bodyPreview: Optional body text. Truncated to ~160 chars so
    ///     the system banner stays compact.
    func postStageComplete(stage: String, bodyPreview: String?) {
        Task { @MainActor in
            let authorized = await ensureAuthorized()
            print("ResolveNotifications: postStageComplete stage=\(stage) authorized=\(authorized)")
            guard authorized else { return }

            let content = UNMutableNotificationContent()
            content.title = "Resolve · \(stage)"
            if let bodyPreview, !bodyPreview.isEmpty {
                content.body = Self.trimForNotification(bodyPreview)
            } else {
                content.body = "\(stage) is ready to view."
            }
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )
            do {
                try await center.add(request)
                print("ResolveNotifications: posted \(stage)")
            } catch {
                print("ResolveNotifications: post failed — \(error.localizedDescription)")
            }
        }
    }

    /// Returns true if we already have authorization, or if the user
    /// just granted it. Returns false if the user has denied or hasn't
    /// answered the prompt and we couldn't elevate.
    private func ensureAuthorized() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            guard !hasRequestedAuthorization else { return false }
            hasRequestedAuthorization = true
            do {
                return try await center.requestAuthorization(options: [.alert, .badge, .sound])
            } catch {
                print("ResolveNotifications: authorization request failed — \(error.localizedDescription)")
                return false
            }
        @unknown default:
            return false
        }
    }

    private static func trimForNotification(_ value: String) -> String {
        let collapsed = value
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let limit = 160
        guard collapsed.count > limit else { return collapsed }
        let idx = collapsed.index(collapsed.startIndex, offsetBy: limit)
        return String(collapsed[..<idx]) + "…"
    }
}
