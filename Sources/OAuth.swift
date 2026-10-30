import Foundation
import AppKit
import AuthenticationServices
import CryptoKit

// MARK: - OpenID Connect (auth.bexio.com) — replaces 60-day personal access tokens.
// Authorization code flow with PKCE; the refresh token is rotated on every renewal
// and the offline session stays alive as long as it is refreshed within a year.

enum OAuthConfig {
    static let issuer = "https://auth.bexio.com/realms/bexio"
    static let authEndpoint = URL(string: issuer + "/protocol/openid-connect/auth")!
    static let tokenEndpoint = URL(string: issuer + "/protocol/openid-connect/token")!
    static let redirectURI = "tyftrack://oauth-callback"
    static let callbackScheme = "tyftrack"
    static let scopes = "openid profile email company_profile offline_access monitoring_edit contact_show project_show"
}

struct OAuthTokens: Codable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
}

struct OAuthTokenResponse: Codable {
    let access_token: String
    let refresh_token: String?
    let expires_in: Int
}

actor OAuthManager {
    static let shared = OAuthManager()
    private static let keychainAccount = "bexio-oauth-tokens"

    private var tokens: OAuthTokens?
    private var loaded = false
    private var refreshTask: Task<String, Error>?

    private func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        if let json = Keychain.load(account: Self.keychainAccount),
           let data = json.data(using: .utf8),
           let t = try? JSONDecoder().decode(OAuthTokens.self, from: data) {
            tokens = t
        }
    }

    var isConnected: Bool {
        loadIfNeeded()
        return tokens != nil
    }

    func store(_ t: OAuthTokens) {
        tokens = t
        loaded = true
        if let data = try? JSONEncoder().encode(t), let s = String(data: data, encoding: .utf8) {
            Keychain.save(s, account: Self.keychainAccount)
        }
    }

    func disconnect() {
        tokens = nil
        loaded = true
        Keychain.save("", account: Self.keychainAccount)
    }

    /// Returns a valid access token, refreshing it first if (nearly) expired.
    /// Concurrent callers share one refresh request.
    func validAccessToken() async throws -> String {
        loadIfNeeded()
        guard let t = tokens else {
            throw BexioError(status: 0, message: L("err.notoken"))
        }
        if t.expiresAt > Date().addingTimeInterval(60) {
            return t.accessToken
        }
        if let task = refreshTask {
            return try await task.value
        }
        let task = Task<String, Error> { try await self.performRefresh() }
        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }

    private func performRefresh() async throws -> String {
        guard let t = tokens else {
            throw BexioError(status: 0, message: L("err.notoken"))
        }
        let clientId = UserDefaults.standard.string(forKey: "oidcClientId") ?? ""
        let secret = Keychain.load(account: "bexio-client-secret") ?? ""
        var params = [
            "grant_type": "refresh_token",
            "refresh_token": t.refreshToken,
            "client_id": clientId,
        ]
        if !secret.isEmpty { params["client_secret"] = secret }
        let resp = try await Self.tokenRequest(params)
        let newTokens = OAuthTokens(
            accessToken: resp.access_token,
            refreshToken: resp.refresh_token ?? t.refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(resp.expires_in)))
        store(newTokens)
        return newTokens.accessToken
    }

    static func tokenRequest(_ params: [String: String]) async throws -> OAuthTokenResponse {
        var req = URLRequest(url: OAuthConfig.tokenEndpoint)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = params
            .map { "\($0.key)=\(formEncode($0.value))" }
            .joined(separator: "&")
            .data(using: .utf8)
        let (data, resp) = try await URLSession.shared.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let msg = String(data: data, encoding: .utf8) ?? ""
            TyfLog.append("OIDC /token — HTTP \(status): \(String(msg.prefix(200)))")
            throw BexioError(status: status, message: String(msg.prefix(300)))
        }
        return try JSONDecoder().decode(OAuthTokenResponse.self, from: data)
    }

    static func formEncode(_ s: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s
    }
}

// MARK: - Interactive sign-in (native auth window)

@MainActor
final class OAuthFlow: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = OAuthFlow()
    private var session: ASWebAuthenticationSession?

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        NSApp.keyWindow ?? (NSApp.delegate as? AppDelegate)?.panel ?? ASPresentationAnchor()
    }

    func signIn(clientId: String, clientSecret: String) async throws {
        let verifier = Self.randomURLSafe(64)
        let challenge = Self.s256(verifier)
        let state = Self.randomURLSafe(16)

        var comps = URLComponents(url: OAuthConfig.authEndpoint, resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: OAuthConfig.redirectURI),
            URLQueryItem(name: "scope", value: OAuthConfig.scopes),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]

        let callbackURL: URL = try await withCheckedThrowingContinuation { cont in
            var resumed = false
            let s = ASWebAuthenticationSession(url: comps.url!,
                                               callbackURLScheme: OAuthConfig.callbackScheme) { url, error in
                guard !resumed else { return }
                resumed = true
                if let url {
                    cont.resume(returning: url)
                } else if let e = error as? ASWebAuthenticationSessionError, e.code == .canceledLogin {
                    cont.resume(throwing: BexioError(status: 0, message: L("err.oauth.cancel")))
                } else {
                    cont.resume(throwing: error ?? BexioError(status: 0, message: L("err.oauth.response")))
                }
            }
            s.presentationContextProvider = self
            s.prefersEphemeralWebBrowserSession = false
            self.session = s
            if !s.start() && !resumed {
                resumed = true
                cont.resume(throwing: BexioError(status: 0, message: L("err.oauth.window")))
            }
        }

        let items = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard items.first(where: { $0.name == "state" })?.value == state,
              let code = items.first(where: { $0.name == "code" })?.value else {
            throw BexioError(status: 0, message: L("err.oauth.response"))
        }

        var params = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": OAuthConfig.redirectURI,
            "client_id": clientId,
            "code_verifier": verifier,
        ]
        if !clientSecret.isEmpty { params["client_secret"] = clientSecret }
        let resp = try await OAuthManager.tokenRequest(params)
        guard let refresh = resp.refresh_token else {
            throw BexioError(status: 0, message: L("err.oauth.norefresh"))
        }
        await OAuthManager.shared.store(OAuthTokens(
            accessToken: resp.access_token,
            refreshToken: refresh,
            expiresAt: Date().addingTimeInterval(TimeInterval(resp.expires_in))))
        TyfLog.append("OIDC — connexion établie (access token \(resp.expires_in)s)")
    }

    static func randomURLSafe(_ count: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return Data(bytes).base64URLEncoded()
    }

    static func s256(_ verifier: String) -> String {
        Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncoded()
    }
}

extension Data {
    func base64URLEncoded() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
