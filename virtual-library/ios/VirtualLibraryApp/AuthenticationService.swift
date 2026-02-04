import Foundation
import Combine
import AuthenticationServices

/// OAuth authentication service for Microsoft
final class AuthenticationService: NSObject, ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var user: User? = nil
    @Published var jwtToken: String? = nil
    
    private var webAuthSession: ASWebAuthenticationSession?
    private let apiBaseURL = "YOUR_API_URL_HERE" // Replace with actual API URL
    
    override init() {
        super.init()
        loadStoredAuth()
    }
    
    /// Sign in with Microsoft OAuth
    func signInWithMicrosoft() async throws {
        // Get OAuth configuration from API
        guard let configURL = URL(string: "\(apiBaseURL)/api/auth/config") else {
            throw AuthError.invalidURL
        }
        
        let (configData, _) = try await URLSession.shared.data(from: configURL)
        let config = try JSONDecoder().decode(OAuthConfig.self, from: configData)
        
        // Build authorization URL
        var components = URLComponents(string: config.microsoft.authorizeUrl)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: config.microsoft.clientId),
            URLQueryItem(name: "redirect_uri", value: config.microsoft.redirectUri),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: config.microsoft.scope),
            URLQueryItem(name: "response_mode", value: "query")
        ]
        
        guard let authURL = components.url else {
            throw AuthError.invalidURL
        }
        
        // Perform web authentication
        let code = try await performWebAuth(url: authURL, redirectUri: config.microsoft.redirectUri)
        
        // Exchange code for JWT token
        try await exchangeCodeForToken(code: code)
    }
    
    private func performWebAuth(url: URL, redirectUri: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async { [weak self] in
                self?.webAuthSession = ASWebAuthenticationSession(
                    url: url,
                    callbackURLScheme: URL(string: redirectUri)!.scheme
                ) { callbackURL, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    guard let callbackURL = callbackURL,
                          let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                          let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                        continuation.resume(throwing: AuthError.noAuthorizationCode)
                        return
                    }
                    
                    continuation.resume(returning: code)
                }
                
                self?.webAuthSession?.presentationContextProvider = self
                self?.webAuthSession?.start()
            }
        }
    }
    
    private func exchangeCodeForToken(code: String) async throws {
        guard let url = URL(string: "\(apiBaseURL)/api/auth/oauth/microsoft") else {
            throw AuthError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["code": code]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(AuthResponse.self, from: data)
        
        // Store token and user
        await MainActor.run {
            self.jwtToken = response.token
            self.user = User(
                id: response.user.id,
                fullName: response.user.displayName ?? response.user.email,
                email: response.user.email
            )
            self.isAuthenticated = true
        }
        
        // Save to keychain
        saveAuthToKeychain(token: response.token, userId: response.user.id)
    }
    
    private func loadStoredAuth() {
        if let token = loadTokenFromKeychain() {
            jwtToken = token
            // Validate token and load user info
            Task {
                await validateAndLoadUser()
            }
        }
    }
    
    private func validateAndLoadUser() async {
        guard let token = jwtToken,
              let url = URL(string: "\(apiBaseURL)/api/auth/me") else {
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let userInfo = try JSONDecoder().decode(UserInfo.self, from: data)
            
            await MainActor.run {
                self.user = User(
                    id: userInfo.id,
                    fullName: userInfo.displayName ?? userInfo.email,
                    email: userInfo.email
                )
                self.isAuthenticated = true
            }
        } catch {
            // Token invalid, clear auth
            await MainActor.run {
                signOut()
            }
        }
    }
    
    /// Sign out and clear user state
    func signOut() {
        user = nil
        jwtToken = nil
        isAuthenticated = false
        clearKeychainAuth()
    }
    
    // MARK: - Keychain helpers
    private func saveAuthToKeychain(token: String, userId: String) {
        let tokenData = token.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "jwtToken",
            kSecValueData as String: tokenData
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    private func loadTokenFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "jwtToken",
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return token
    }
    
    private func clearKeychainAuth() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "jwtToken"
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding
extension AuthenticationService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return ASPresentationAnchor()
    }
}

// MARK: - Models
struct OAuthConfig: Codable {
    let microsoft: MicrosoftConfig
    
    struct MicrosoftConfig: Codable {
        let clientId: String
        let redirectUri: String
        let authorizeUrl: String
        let scope: String
    }
}

struct AuthResponse: Codable {
    let token: String
    let user: UserInfo
}

struct UserInfo: Codable {
    let id: String
    let email: String
    let displayName: String?
    let profilePictureUrl: String?
}

enum AuthError: Error {
    case invalidURL
    case noAuthorizationCode
}
