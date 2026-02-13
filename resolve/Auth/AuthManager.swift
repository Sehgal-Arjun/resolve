import Foundation
import AppKit
import AuthenticationServices
import CryptoKit
import Security

@MainActor
final class AuthManager: NSObject, ObservableObject {
    struct ClerkUser: Equatable {
        let id: String
        let name: String
        let email: String
    }

    enum AuthState: Equatable {
        case signedOut
        case signingIn
        case signedIn(ClerkUser)
    }

    static let shared = AuthManager()

    @Published private(set) var state: AuthState = .signedOut
    @Published private(set) var currentUser: ClerkUser?
    @Published private(set) var isAuthenticated: Bool = false
    @Published private(set) var isLoadingAuth: Bool = false
    @Published private(set) var userId: String?

    private let clientID = "vTNy0mSOUipeN01x"
    private let authorizeURL = URL(string: "https://oriented-antelope-57.clerk.accounts.dev/oauth/authorize")!
    private let tokenURL = URL(string: "https://oriented-antelope-57.clerk.accounts.dev/oauth/token")!
    private let userInfoURL = URL(string: "https://oriented-antelope-57.clerk.accounts.dev/oauth/userinfo")!
    private let redirectURI = "resolve://auth-callback"
    private let callbackScheme = "resolve"

    private var authSession: ASWebAuthenticationSession?
    private var currentState: String?
    private var currentVerifier: String?
    private var isRefreshingAuth = false
    private var fallbackAnchorWindow: NSWindow?

    private override init() {}

    func login() {
        guard !isLoadingAuth else { return }

        let verifier = randomString(length: 64)
        let challenge = codeChallenge(for: verifier)
        let oauthState = randomString(length: 32)

        currentState = oauthState
        currentVerifier = verifier

        var components = URLComponents(url: authorizeURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: "openid email profile"),
            URLQueryItem(name: "state", value: oauthState),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]

        guard let authURL = components?.url else { return }

        isLoadingAuth = true
        self.state = .signingIn

        authSession = ASWebAuthenticationSession(url: authURL, callbackURLScheme: callbackScheme) { [weak self] url, error in
            Task { @MainActor in
                guard let self else { return }
                self.isLoadingAuth = false

                if let error {
                    print("Auth session error:", error.localizedDescription)
                    self.signOutLocal()
                    return
                }

                guard let url else { return }
                await self.handleRedirect(url)
            }
        }

        authSession?.presentationContextProvider = self

        // Turn this off while debugging to reduce weird session/cookie edge cases.
        authSession?.prefersEphemeralWebBrowserSession = false

        print("Auth URL:", authURL.absoluteString)

        let started = authSession?.start() ?? false
        if !started {
            print("Auth session failed to start (start() returned false)")
            self.isLoadingAuth = false
            self.signOutLocal()
        }
    }

    func signIn() {
        login()
    }

    func startSignIn() {
        login()
    }

    func signOut() {
        signOutLocal()
    }

    func handleClerkCallback(url: URL) async {
        await handleRedirect(url)
    }

    func refreshAuthState() async {
        guard !isRefreshingAuth else { return }
        isRefreshingAuth = true
        isLoadingAuth = true

        defer {
            isRefreshingAuth = false
            isLoadingAuth = false
        }

        guard let accessToken = KeychainHelper.load(service: "resolve.auth", account: "access_token") else {
            signOutLocal()
            return
        }

        do {
            let profile = try await fetchUserProfile(accessToken: accessToken)
            currentUser = profile
            userId = profile.id
            isAuthenticated = true
            state = .signedIn(profile)
        } catch {
            signOutLocal()
        }
    }

    func exchangeCode(code: String) async throws -> TokenResponse {
        guard let verifier = currentVerifier else {
            throw AuthError.missingVerifier
        }
        return try await exchangeCode(code: code, verifier: verifier)
    }

    func fetchUserProfile() async throws -> ClerkUser {
        guard let accessToken = KeychainHelper.load(service: "resolve.auth", account: "access_token") else {
            throw AuthError.missingAccessToken
        }
        return try await fetchUserProfile(accessToken: accessToken)
    }

    // MARK: - OAuth internals

    private func handleRedirect(_ url: URL) async {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        let items = components.queryItems ?? []
        let code = items.first { $0.name == "code" }?.value
        let state = items.first { $0.name == "state" }?.value

        guard let code, let state, state == currentState else {
            return
        }

        guard let verifier = currentVerifier else { return }

        do {
            let tokenResponse = try await exchangeCode(code: code, verifier: verifier)
            storeTokens(tokenResponse)

            let profile = try await fetchUserProfile(accessToken: tokenResponse.accessToken)
            currentUser = profile
            userId = profile.id
            isAuthenticated = true
            self.state = .signedIn(profile)
        } catch {
            signOutLocal()
        }
    }

    private func exchangeCode(code: String, verifier: String) async throws -> TokenResponse {
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "code_verifier", value: verifier)
        ]

        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AuthError.tokenExchangeFailed
        }

        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    private func fetchUserProfile(accessToken: String) async throws -> ClerkUser {
        var request = URLRequest(url: userInfoURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AuthError.userInfoFailed
        }

        let profile = try JSONDecoder().decode(UserInfoResponse.self, from: data)
        let fullName = [profile.givenName, profile.familyName]
            .compactMap { $0 }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let email = profile.email ?? ""
        let name = fullName.isEmpty ? (email.isEmpty ? "Signed in" : email) : fullName

        return ClerkUser(id: profile.sub, name: name, email: email)
    }

    private func storeTokens(_ response: TokenResponse) {
        KeychainHelper.save(service: "resolve.auth", account: "access_token", value: response.accessToken)
        if let refresh = response.refreshToken {
            KeychainHelper.save(service: "resolve.auth", account: "refresh_token", value: refresh)
        }
        if let idToken = response.idToken {
            KeychainHelper.save(service: "resolve.auth", account: "id_token", value: idToken)
        }
    }

    private func signOutLocal() {
        KeychainHelper.delete(service: "resolve.auth", account: "access_token")
        KeychainHelper.delete(service: "resolve.auth", account: "refresh_token")
        KeychainHelper.delete(service: "resolve.auth", account: "id_token")
        currentUser = nil
        userId = nil
        isAuthenticated = false
        isLoadingAuth = false
        state = .signedOut
    }

    // MARK: - PKCE helpers

    private func randomString(length: Int) -> String {
        let charset = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        var result = ""
        result.reserveCapacity(length)

        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)

        for byte in bytes {
            result.append(charset[Int(byte) % charset.count])
        }

        return result
    }

    private func codeChallenge(for verifier: String) -> String {
        let data = Data(verifier.utf8)
        let digest = SHA256.hash(data: data)
        return base64urlEncode(Data(digest))
    }

    private func base64urlEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private enum AuthError: Error {
        case tokenExchangeFailed
        case userInfoFailed
        case missingVerifier
        case missingAccessToken
    }
}

struct TokenResponse: Decodable {
    let accessToken: String
    let idToken: String?
    let refreshToken: String?
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case idToken = "id_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

private struct UserInfoResponse: Decodable {
    let sub: String
    let email: String?
    let givenName: String?
    let familyName: String?

    enum CodingKeys: String, CodingKey {
        case sub
        case email
        case givenName = "given_name"
        case familyName = "family_name"
    }
}

private enum KeychainHelper {
    static func save(service: String, account: String, value: String) {
        let data = Data(value.utf8)
        delete(service: service, account: account)

        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock
        ]

        SecItemAdd(query as CFDictionary, nil)
    }

    static func load(service: String, account: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(service: String, account: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]

        SecItemDelete(query as CFDictionary)
    }
}

extension AuthManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        if let key = NSApp.keyWindow { return key }
        if let main = NSApp.mainWindow { return main }
        if let visible = NSApp.windows.first(where: { $0.isVisible }) { return visible }

        // Fallback: create a tiny hidden window so ASWebAuthenticationSession always has an anchor.
        if fallbackAnchorWindow == nil {
            let w = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
                styleMask: [.titled],
                backing: .buffered,
                defer: false
            )
            w.isReleasedWhenClosed = false
            w.level = .floating
            w.orderOut(nil) // keep hidden
            fallbackAnchorWindow = w
        }
        return fallbackAnchorWindow!
    }
}
