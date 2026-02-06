import Foundation
import Combine
import AuthenticationServices

/// OAuth authentication service for Microsoft
class AuthenticationService: NSObject, ObservableObject, AuthTokenProvider {
    @Published var isAuthenticated: Bool = false
    @Published var user: User? = nil
    @Published var jwtToken: String? = nil
    
    private var webAuthSession: ASWebAuthenticationSession?
    private let apiBaseURL = "https://virtual-library-api-web.azurewebsites.net"
    private let customScheme = "virtuallibrary"
    private var hasLoadedStoredAuth = false
    
    override init() {
        super.init()
        print("⏱️ [Auth] init() called at \(Date())")
        // Don't do ANY work here - defer everything
    }
    
    /// Call this once the app is ready (e.g., in .task modifier)
    func initializeIfNeeded() {
        print("⏱️ [Auth] initializeIfNeeded() called at \(Date())")
        guard !hasLoadedStoredAuth else { 
            print("⏱️ [Auth] Already initialized, skipping")
            return 
        }
        hasLoadedStoredAuth = true
        
        // Set up shared API service to use this as token provider
        BookApiService.shared.tokenProvider = self
        print("⏱️ [Auth] Token provider set")
        
        // Load stored auth on background thread
        Task.detached(priority: .userInitiated) { [weak self] in
            print("⏱️ [Auth] Background task started at \(Date())")
            await self?.loadStoredAuthAsync()
            print("⏱️ [Auth] Background task finished at \(Date())")
        }
    }
    
    /// Check if the stored token has expired
    private func isTokenExpired(_ token: String) -> Bool {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return true }
        
        var payload = String(parts[1])
        let remainder = payload.count % 4
        if remainder > 0 {
            payload += String(repeating: "=", count: 4 - remainder)
        }
        
        guard let data = Data(base64Encoded: payload.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = json["exp"] as? TimeInterval else {
            return true
        }
        
        let expirationDate = Date(timeIntervalSince1970: exp)
        return expirationDate < Date()
    }
    
    /// Sign in with Microsoft OAuth
    func signInWithMicrosoft() async throws {
        // Ensure service is initialized
        await MainActor.run { initializeIfNeeded() }
        
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
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    guard let callbackURL = callbackURL else {
                        continuation.resume(throwing: AuthError.noToken)
                        return
                    }
                    
                    guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) else {
                        continuation.resume(throwing: AuthError.noToken)
                        return
                    }
                    
                    // Check for error parameter
                    if let errorParam = components.queryItems?.first(where: { $0.name == "error" })?.value {
                        let details = components.queryItems?.first(where: { $0.name == "details" })?.value ?? "no details"
                        continuation.resume(throwing: AuthError.serverError("\(errorParam): \(details)"))
                        return
                    }
                    
                    // Get token parameter
                    guard let token = components.queryItems?.first(where: { $0.name == "token" })?.value else {
                        continuation.resume(throwing: AuthError.noToken)
                        return
                    }
                    
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
            
            // Ensure BookApiService has the token directly
            BookApiService.shared.authToken = token
        }
        
        // Save to keychain
        saveAuthToKeychain(token: token, userId: userId)
    }
    
    /// Load stored auth asynchronously (Keychain access on background thread)
    private func loadStoredAuthAsync() async {
        print("⏱️ [Auth] loadStoredAuthAsync started at \(Date())")
        
        // Keychain access happens here (off main thread)
        print("⏱️ [Auth] Reading from Keychain...")
        guard let token = loadTokenFromKeychain() else { 
            print("⏱️ [Auth] No token in Keychain")
            return 
        }
        print("⏱️ [Auth] Token loaded from Keychain")
        
        // Check if token is expired locally first
        if isTokenExpired(token) {
            print("⏱️ [Auth] Token expired, clearing")
            clearKeychainAuth()
            return
        }
        print("⏱️ [Auth] Token is valid")
        
        // Decode user info from token (works offline - no server call needed)
        guard let user = decodeUserFromToken(token) else { 
            print("⏱️ [Auth] Failed to decode user from token")
            return 
        }
        print("⏱️ [Auth] User decoded: \(user.email)")
        
        // Update published properties on main actor
        print("⏱️ [Auth] Updating UI on main actor...")
        await MainActor.run {
            self.jwtToken = token
            self.user = user
            self.isAuthenticated = true
            
            // Ensure BookApiService has the token directly
            BookApiService.shared.authToken = token
            print("⏱️ [Auth] UI updated, isAuthenticated = true")
        }
    }
    
    private func loadStoredAuth() {
        if let token = loadTokenFromKeychain() {
            // Check if token is expired locally first
            if isTokenExpired(token) {
                clearKeychainAuth()
                return
            }
            
            jwtToken = token
            
            // Decode user info from token (works offline - no server call needed)
            if let user = decodeUserFromToken(token) {
                self.user = user
                self.isAuthenticated = true
            }
            
            // Skip server validation on startup to avoid slowness
            // The token will be validated on first API call anyway
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
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 401 {
                    // Token is invalid on server, clear auth
                    await MainActor.run {
                        signOut()
                    }
                    return
                }
            }
            
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
            // Network error - keep the local session (token was decoded successfully)
            // Don't sign out - the token might still be valid, just network issue
        }
    }
    
    /// Decode user information directly from JWT token (works offline)
    private func decodeUserFromToken(_ token: String) -> User? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }
        
        var payload = String(parts[1])
        let remainder = payload.count % 4
        if remainder > 0 {
            payload += String(repeating: "=", count: 4 - remainder)
        }
        
        guard let data = Data(base64Encoded: payload.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let userId = json["http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier"] as? String,
              let email = json["http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress"] as? String else {
            return nil
        }
        
        let displayName = json["http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name"] as? String
        
        return User(
            id: userId,
            fullName: displayName ?? email,
            email: email
        )
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
    @MainActor
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Get the key window from the active scene - must be on main thread
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first {
            return window
        }
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
