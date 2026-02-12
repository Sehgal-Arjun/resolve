import Foundation
import ClerkKit

@MainActor
final class AuthManager: ObservableObject {
    struct ClerkUser: Equatable {
        let id: String
        let name: String
        let email: String
    }

    enum AuthState: Equatable {
        case signedOut
        case signingIn
        case signUpNeedsDetails(SignUpRequirements)
        case signUpNeedsPhoneCode(SignUpRequirements)
        case signedIn(ClerkUser)
    }

    struct SignUpRequirements: Equatable {
        let missingFields: [String]
        let requiredFields: [String]
        let phoneNumber: String?
    }

    static let shared = AuthManager()

    @Published private(set) var state: AuthState = .signedOut
    @Published private(set) var currentUser: ClerkUser?

    private var isClerkConfigured = false

    private init() {}

    func configureIfNeeded() {
        guard !isClerkConfigured else {
            syncFromClerk()
            return
        }

        let key = ClerkConfig.publishableKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            print("Clerk auth misconfigured: set ClerkConfig.publishableKey")
            return
        }

        let redirectConfig = Clerk.Options.RedirectConfig(
            redirectUrl: ClerkConfig.redirectUrl,
            callbackUrlScheme: ClerkConfig.callbackUrlScheme
        )

        #if DEBUG
        let options = Clerk.Options(
            logLevel: .debug,
            telemetryEnabled: false,
            redirectConfig: redirectConfig,
            loggerHandler: { entry in
                // Surfaces ClerkKit errors with trace IDs during local debugging.
                print(entry.formattedMessage)
            }
        )
        #else
        let options = Clerk.Options(redirectConfig: redirectConfig)
        #endif

        Clerk.configure(publishableKey: key, options: options)
        isClerkConfigured = true
        syncFromClerk()
    }

    // MARK: - Public API

    /// Starts the Clerk sign-in flow by opening the system browser.
    /// The app will receive a callback URL when authentication completes.
    func startSignIn() {
        guard state != .signingIn else { return }
        configureIfNeeded()
        guard isClerkConfigured else { return }

        state = .signingIn
        Task {
            do {
                let provider = OAuthProvider(strategy: ClerkConfig.oauthStrategy)
                let result = try await Clerk.shared.auth.signInWithOAuth(
                    provider: provider,
                    transferable: ClerkConfig.allowSignUpTransfer
                )
                handleTransferFlowResult(result)
            } catch {
                handleFailure(error)
            }
        }
    }

    /// Signs out the current Clerk session.
    func signOut() {
        configureIfNeeded()
        guard isClerkConfigured else { return }

        state = .signingIn
        Task {
            do {
                try await Clerk.shared.auth.signOut()
                currentUser = nil
                state = .signedOut
            } catch {
                handleFailure(error)
            }
        }
    }

    /// Completes an in-progress Clerk sign-up by supplying missing required fields.
    func submitSignUpDetails(phoneNumber: String, password: String) {
        guard isClerkConfigured else { return }

        Task {
            do {
                guard var signUp = Clerk.shared.auth.currentSignUp else {
                    throw AuthError.incompleteFlow("No active sign-up. Please try again.")
                }

                state = .signingIn

                // Supply missing fields.
                signUp = try await signUp.update(
                    password: password,
                    phoneNumber: phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
                )

                // If phone is required, Clerk will typically require SMS verification.
                if signUp.unverifiedFields.contains(.phoneNumber) {
                    _ = try await signUp.sendPhoneCode()
                    state = .signUpNeedsPhoneCode(requirements(from: signUp))
                    return
                }

                if signUp.status == .complete {
                    transitionToSignedInAfterAuth()
                    return
                }

                if signUp.status == .missingRequirements {
                    state = .signUpNeedsDetails(requirements(from: signUp))
                    return
                }

                throw AuthError.incompleteFlow("Sign-up not complete (status: \(signUp.status.rawValue))")
            } catch {
                handleFailure(error)
            }
        }
    }

    /// Verifies the SMS code for the in-progress Clerk sign-up.
    func verifySignUpPhoneCode(_ code: String) {
        guard isClerkConfigured else { return }

        Task {
            do {
                guard var signUp = Clerk.shared.auth.currentSignUp else {
                    throw AuthError.incompleteFlow("No active sign-up. Please try again.")
                }

                state = .signingIn
                signUp = try await signUp.verifyPhoneCode(code.trimmingCharacters(in: .whitespacesAndNewlines))

                if signUp.status == .complete {
                    transitionToSignedInAfterAuth()
                    return
                }

                if signUp.status == .missingRequirements {
                    // Could still need other fields after verification.
                    state = .signUpNeedsDetails(requirements(from: signUp))
                    return
                }

                throw AuthError.incompleteFlow("Sign-up not complete (status: \(signUp.status.rawValue))")
            } catch {
                handleFailure(error)
            }
        }
    }

    /// Handles the callback URL from Clerk (custom scheme).
    func handleCallback(url: URL) {
        #if DEBUG
        print("Clerk callback URL:", url.absoluteString)
        #endif
        // ClerkKit uses `ASWebAuthenticationSession`, which handles the callback URL internally.
        // If this app is opened with a matching URL anyway, just attempt a state sync.
        transitionToSignedInAfterAuth()
    }

    // MARK: - Internals

    private func transitionToSignedInAfterAuth(timeoutSeconds: TimeInterval = 5.0) {
        state = .signingIn

        Task {
            let didSync = await waitForUserAndSync(timeoutSeconds: timeoutSeconds)
            if !didSync {
                print("Clerk sign-in completed but user was not available after \(timeoutSeconds)s")
                currentUser = nil
                state = .signedOut
            }
        }
    }

    private func waitForUserAndSync(timeoutSeconds: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeoutSeconds)

        while Date() < deadline {
            if let user = Clerk.shared.user {
                let mapped = mapUser(user)
                currentUser = mapped
                state = .signedIn(mapped)
                return true
            }

            do {
                try await Task.sleep(nanoseconds: 150_000_000)
            } catch {
                return false
            }
        }

        if let user = Clerk.shared.user {
            let mapped = mapUser(user)
            currentUser = mapped
            state = .signedIn(mapped)
            return true
        }

        return false
    }

    private func handleFailure(_ error: Error) {
        if let apiError = error as? ClerkAPIError {
            print(
                "Clerk auth error:",
                "code=\(apiError.code)",
                "message=\(apiError.message ?? "")",
                "long=\(apiError.longMessage ?? "")",
                "trace=\(apiError.clerkTraceId ?? "")"
            )

            if apiError.code == "session_exists" {
                // Not a real failure: user is already authenticated.
                transitionToSignedInAfterAuth()
                return
            }

            if apiError.code == "external_account_not_found" {
                print(
                    "Hint: This usually means there is no existing Clerk user linked to this Google account yet. " +
                    "Set ClerkConfig.allowSignUpTransfer=true to allow sign-up, or create/link the user in Clerk Dashboard."
                )
            }
        } else {
            print("Clerk auth error:", error)
        }
        currentUser = nil
        state = .signedOut
    }

    // MARK: - Internals

    private enum AuthError: LocalizedError {
        case incompleteFlow(String)

        var errorDescription: String? {
            switch self {
            case .incompleteFlow(let message):
                return message
            }
        }
    }

    private func validateCompletion(_ result: TransferFlowResult) throws {
        switch result {
        case .signIn(let signIn):
            guard signIn.status == .complete else {
                throw AuthError.incompleteFlow("Sign-in not complete (status: \(signIn.status.rawValue))")
            }
        case .signUp(let signUp):
            if signUp.status == .missingRequirements {
                let missing = signUp.missingFields.map(\.rawValue).joined(separator: ", ")
                let required = signUp.requiredFields.map(\.rawValue).joined(separator: ", ")
                throw AuthError.incompleteFlow(
                    "Sign-up requires more steps (missing_requirements). " +
                    "Missing fields: [\(missing)]. Required fields: [\(required)]. " +
                    "Fix: in Clerk Dashboard, make those fields optional (or complete sign-up in a hosted UI)."
                )
            }

            guard signUp.status == .complete else {
                throw AuthError.incompleteFlow("Sign-up not complete (status: \(signUp.status.rawValue))")
            }
        }
    }

    private func handleTransferFlowResult(_ result: TransferFlowResult) {
        switch result {
        case .signIn(let signIn):
            if signIn.status == .complete {
                transitionToSignedInAfterAuth()
            } else {
                handleFailure(AuthError.incompleteFlow("Sign-in not complete (status: \(signIn.status.rawValue))"))
            }

        case .signUp(let signUp):
            if signUp.status == .complete {
                transitionToSignedInAfterAuth()
                return
            }

            if signUp.status == .missingRequirements {
                state = .signUpNeedsDetails(requirements(from: signUp))
                return
            }

            handleFailure(AuthError.incompleteFlow("Sign-up not complete (status: \(signUp.status.rawValue))"))
        }
    }

    private func requirements(from signUp: SignUp) -> SignUpRequirements {
        SignUpRequirements(
            missingFields: signUp.missingFields.map(\.rawValue),
            requiredFields: signUp.requiredFields.map(\.rawValue),
            phoneNumber: signUp.phoneNumber
        )
    }

    private func syncFromClerk() {
        guard isClerkConfigured else { return }

        if let user = Clerk.shared.user {
            let mapped = mapUser(user)
            currentUser = mapped
            state = .signedIn(mapped)
        } else {
            currentUser = nil
            state = .signedOut
        }
    }

    private func mapUser(_ user: ClerkKit.User) -> ClerkUser {
        let name = [user.firstName, user.lastName]
            .compactMap { $0 }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let email = user.primaryEmailAddress?.emailAddress
            ?? user.emailAddresses.first?.emailAddress
            ?? ""

        return ClerkUser(
            id: user.id,
            name: name.isEmpty ? "Unknown" : name,
            email: email
        )
    }
}
