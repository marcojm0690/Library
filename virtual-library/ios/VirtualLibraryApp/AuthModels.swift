import Foundation

/// App-level authenticated user model
struct User: Identifiable, Codable, Equatable {
    let id: String
    let fullName: String
    let email: String
}

/// API response model for /api/auth/me
struct UserInfo: Decodable {
    let id: String
    let email: String
    let displayName: String?
}
