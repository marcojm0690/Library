import Foundation
import Combine
import AuthenticationServices

/// OAuth authentication service for Microsoft
class AuthenticationService: NSObject, ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var user: User? = nil
    @Published var jwtToken: String? = nil
    
    private var webAuthSession: ASWebAuthenticationSession?
    private let apiBaseURL = "https://virtual-library-api-web.azurewebsites.net"
    private let customScheme = "virtuallibrary"
    
    override init() {
        super.init()
        loadStoredAuth()
    }
    
    /// Sign in with Microsoft OAuth
    func signInWithMicrosoft() async throws {
        // Build Microsoft authorization URL
        let clientId = "bdf237d4-29e4-44fb-9927-822f24961766"
        let redirectUri = "\(apiBaseURL)/api/auth/callback/microsoft/mobile"
        let state = UUID().uuidString
        
        var components = URLComponents(string: "https://login.microsoftonline.com/common/oauth2/v2.0/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "response_mode", value: "query"),
            URLQueryItem(name: "scope", value: "openid profile email User.Read"),
            URLQueryItem(name: "state", value: state)
        ]
        
        guard let authURL = components.url else {
            throw AuthError.invalidURL
        }
        
        // Start web authentication session
        let token = try await performWebAuth(url: authURL, callbackScheme: customScheme)
        
        // Parse JWT to get user info
        try await processToken(token)
    }
    
    private func performWebAuth(url: URL, callbackScheme: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async { [weak self] in
                self?.webAuthSession = ASWebAuthenticationSession(
                    url: url,
                    callbackURLScheme: callbackScheme
                ) { callbackURL, error in
                    if let error = error {
                        print("❌ ASWebAuthenticationSession error: \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    guard let callbackURL = callbackURL else {
                        print("❌ No callback URL received")
                        continuation.resume(throwing: AuthError.noToken)
                        return
                    }
                    
                    print("✅ Callback URL received: \(callbackURL.absoluteString)")
                    
                    guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) else {
                        print("❌ Failed to parse callback URL")
                        continuation.resume(throwing: AuthError.noToken)
                        return
                    }
                    
                    // Check for error parameter
                    if let errorParam = components.queryItems?.first(where: { $0.name == "error" })?.value {
                        let details = components.queryItems?.first(where: { $0.name == "details" })?.value ?? "no details"
                        print("❌ Server returned error: \(errorParam)")
                        print("❌ Error details: \(details)")
                        continuation.resume(throwing: AuthError.serverError("\(errorParam): \(details)"))
                        return
                    }
                    
                    // Get token parameter
                    guard let token = components.queryItems?.first(where: { $0.name == "token" })?.value else {
                        print("❌ No token in callback URL. Query items: \(components.queryItems ?? [])")
                        continuation.resume(throwing: AuthError.noToken)
                        return
                    }
                    
                    print("✅ Token received successfully")
                    continuation.resume(returning: token)
                }
                
                self?.webAuthSession?.presentationContextProvider = self
                self?.webAuthSession?.prefersEphemeralWebBrowserSession = false
                self?.webAuthSession?.start()
            }
        }
    }
    
    private func processToken(_ token: String) async throws {
        // Decode JWT to get user info (basic decode without verification for display)
        let parts = token.split(separator: ".")
        guard parts.count == 3 else {
            throw AuthError.invalidToken
        }
        
        // Decode payload (second part)
        var payload = String(parts[1])
        // Add padding if needed
        let remainder = payload.count % 4
        if remainder > 0 {
            payload += String(repeating: "=", count: 4 - remainder)
        }
        
        guard let data = Data(base64Encoded: payload.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let userId = json["http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier"] as? String,
              let email = json["http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress"] as? String else {
            throw AuthError.invalidToken
        }
        
        let displayName = json["http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name"] as? String
        
        // Store token and user info
        await MainActor.run {
            self.jwtToken = token
            self.user = User(
                id: userId,
                fullName: displayName ?? email,
                email: email
            )
            self.isAuthenticated = true
        }
        
        // Save to keychain
        saveAuthToKeychain(token: token, userId: userId)
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

enum AuthError: Error {
    case invalidURL
    case noToken
    case invalidToken
    case serverError(String)
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noToken:
            return "No token received from server"
        case .invalidToken:
            return "Invalid token format"
        case .serverError(let message):
            return "Server error: \(message)"
        }
    }
}
