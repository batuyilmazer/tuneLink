import Foundation
import CryptoKit
import AuthenticationServices

@MainActor
final class SpotifyAuthManager: NSObject, ObservableObject {

    private let clientId = Bundle.main.object(forInfoDictionaryKey: "SPOTIFY_CLIENT_ID") as? String ?? ""
    private let redirectURI = "tunelinkapp://auth/callback"
    private let scopes = "user-read-currently-playing user-read-playback-state"
    private let baseURL: String = {
        Bundle.main.object(forInfoDictionaryKey: "BASE_URL") as? String ?? "http://localhost:3000"
    }()

    private var codeVerifier: String = ""
    private var session: ASWebAuthenticationSession?

    // 10.1 — PKCE helpers
    private func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 64)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func codeChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return Data(hash)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // 10.2 — Open Spotify authorize URL
    func authenticate(presentationAnchor: ASPresentationAnchor) async throws {
        codeVerifier = generateCodeVerifier()
        let challenge = codeChallenge(from: codeVerifier)

        var components = URLComponents(string: "https://accounts.spotify.com/authorize")!
        components.queryItems = [
            .init(name: "client_id", value: clientId),
            .init(name: "response_type", value: "code"),
            .init(name: "redirect_uri", value: redirectURI),
            .init(name: "scope", value: scopes),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "code_challenge", value: challenge),
        ]

        let code = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            let s = ASWebAuthenticationSession(
                url: components.url!,
                callbackURLScheme: "tunelinkapp"
            ) { callbackURL, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard
                    let url = callbackURL,
                    let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
                    let code = items.first(where: { $0.name == "code" })?.value
                else {
                    continuation.resume(throwing: URLError(.badURL))
                    return
                }
                continuation.resume(returning: code)
            }
            s.presentationContextProvider = self
            s.prefersEphemeralWebBrowserSession = true
            self.session = s
            s.start()
        }

        try await exchangeCode(code)
    }

    // 10.3 — POST { code, code_verifier } to backend
    private func exchangeCode(_ code: String) async throws {
        let url = URL(string: "\(baseURL)/auth/callback")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["code": code, "code_verifier": codeVerifier])

        let (data, response) = try await URLSession.shared.data(for: request)
        let body = try JSONDecoder().decode([String: String].self, from: data)

        if let errorMsg = body["error"] {
            throw NSError(domain: "tuneLink", code: (response as? HTTPURLResponse)?.statusCode ?? 500, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }

        guard let userId = body["userId"] else { throw URLError(.cannotParseResponse) }

        let defaults = UserDefaults(suiteName: AppGroup.suiteName)
        defaults?.set(userId, forKey: AppGroup.Keys.userId)
        if let sessionToken = body["sessionToken"] {
            defaults?.set(sessionToken, forKey: AppGroup.Keys.sessionToken)
        }

        // Device token may have arrived before login — retry sending it now
        if let cachedToken = defaults?.string(forKey: AppGroup.Keys.deviceToken) {
            try? await postDeviceToken(cachedToken, userId: userId)
        }
    }

    private func postDeviceToken(_ token: String, userId: String) async throws {
        guard let url = URL(string: "\(baseURL)/device-token") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["userId": userId, "deviceToken": token])
        _ = try await URLSession.shared.data(for: request)
    }
}

extension SpotifyAuthManager: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated { ASPresentationAnchor() }
    }
}
