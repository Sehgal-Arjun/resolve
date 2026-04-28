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
    static let redirectUrl = "resolve://auth-callback"
}
