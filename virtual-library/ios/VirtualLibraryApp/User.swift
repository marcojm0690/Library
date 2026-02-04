import Foundation

/// User model for authenticated users
struct User: Codable, Equatable, Identifiable {
    let id: String
    let fullName: String
    let email: String
    let profilePictureUrl: String?

    init(id: String = UUID().uuidString, fullName: String, email: String, profilePictureUrl: String? = nil) {
        self.id = id
        self.fullName = fullName
        self.email = email
        self.profilePictureUrl = profilePictureUrl
    }
}
