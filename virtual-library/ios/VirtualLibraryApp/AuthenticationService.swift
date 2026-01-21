import Foundation
import Combine

/// Simple in-memory authentication service.
/// Manages authentication state and current user.
final class AuthenticationService: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var user: User? = nil

    /// Perform a simple sign-in by setting a user and toggling authentication.
    /// In a real app, replace this with proper authentication.
    func signIn(fullName: String) {
        let trimmed = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        user = User(fullName: trimmed)
        isAuthenticated = true
    }

    /// Sign out and clear user state.
    func signOut() {
        user = nil
        isAuthenticated = false
    }
}
