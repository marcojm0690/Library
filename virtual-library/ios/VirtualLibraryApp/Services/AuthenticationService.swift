import Foundation
import SwiftUI

/// User model for authenticated users
struct User: Codable, Identifiable {
    let id: String
    let email: String?
    let fullName: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case fullName
    }
}

/// Authentication service managing local user authentication (no Sign in with Apple required)
@MainActor
class AuthenticationService: ObservableObject {
    @Published var user: User?
    @Published var isAuthenticated = false
    @Published var error: String?
    
    private let userDefaultsKey = "authenticatedUser"
    
    init() {
        loadSavedUser()
    }
    
    /// Load saved user from UserDefaults
    private func loadSavedUser() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let savedUser = try? JSONDecoder().decode(User.self, from: data) else {
            return
        }
        
        user = savedUser
        isAuthenticated = true
        print("✅ Loaded saved user: \(savedUser.id)")
    }
    
    /// Save user to UserDefaults
    private func saveUser(_ user: User) {
        guard let data = try? JSONEncoder().encode(user) else { return }
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }
    
    /// Simple local sign in (no Apple account required)
    func signIn(fullName: String, email: String?) {
        let userId = UUID().uuidString
        let newUser = User(
            id: userId,
            email: email,
            fullName: fullName
        )
        
        user = newUser
        isAuthenticated = true
        saveUser(newUser)
        print("✅ Signed in: \(userId) - \(fullName)")
    }
    
    /// Sign out
    func signOut() {
        user = nil
        isAuthenticated = false
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        print("🚪 User signed out")
    }
}
