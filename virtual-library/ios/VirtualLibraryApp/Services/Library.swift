import Foundation

/// Domain model representing a user library in the Virtual Library.
struct Library: Identifiable, Codable {
    let id: UUID
    let name: String
    let owner: String
    let description: String?
    let createdAt: Date
    let updatedAt: Date?
    
    // Optional derived info often returned by APIs; make it optional to be resilient.
    let bookCount: Int?
    
    // Coding keys if your backend uses different casing; adjust as needed.
    // If your API already uses these names, you can remove CodingKeys entirely.
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case owner
        case description
        case createdAt
        case updatedAt
        case bookCount
    }
}

/// Request payload to create a new library.
struct CreateLibraryRequest: Codable {
    let name: String
    let owner: String
    let description: String?
}
