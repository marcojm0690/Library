import Foundation

/// Minimal user model used by AuthenticationService and UI.
struct User: Codable, Equatable, Identifiable {
    let id: UUID
    let fullName: String

    init(id: UUID = UUID(), fullName: String) {
        self.id = id
        self.fullName = fullName
    }
}
