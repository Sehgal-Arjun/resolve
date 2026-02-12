import Foundation

/// ClerkKit configuration for this app.
///
/// ClerkKit handles the browser flow + token exchange. You only need:
/// - a Clerk **publishable key**
/// - a callback URL scheme registered in `Info.plist`
enum ClerkConfig {
    /// From Clerk Dashboard → API keys.
    static let publishableKey = "pk_test_b3JpZW50ZWQtYW50ZWxvcGUtNTcuY2xlcmsuYWNjb3VudHMuZGV2JA"

    /// Must match the callback URL scheme registered in `Info.plist`.
    /// This repo already registers the `resolve` scheme.
    static let callbackUrlScheme = "resolve"

    /// Must be allowed in Clerk Dashboard → Redirect URLs.
    static let redirectUrl = "resolve://clerk/oauth-callback"

    /// Clerk OAuth strategy (examples: "oauth_google", "oauth_github", "oauth_apple").
    static let oauthStrategy = "oauth_google"

    /// If `true`, Clerk may transfer a failed sign-in into a sign-up for new users.
    /// If `false`, only existing users can sign in (new users will see errors like
    /// `external_account_not_found`).
    static let allowSignUpTransfer = true
}
