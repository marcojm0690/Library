import Foundation

/// Library model matching the API structure
struct LibraryModel: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let description: String?
    let owner: String
    let createdAt: Date
    let updatedAt: Date
    let bookIds: [UUID]
    let bookCount: Int
    let tags: [String]
    let isPublic: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case owner
        case createdAt
        case updatedAt
        case bookIds
        case bookCount
        case tags
        case isPublic
    }
}

/// Request model for creating a library
struct CreateLibraryRequest: Codable {
    let name: String
    let description: String?
    let owner: String
    let tags: [String]?
    let isPublic: Bool
}

/// Request model for updating a library
struct UpdateLibraryRequest: Codable {
    let name: String?
    let description: String?
    let tags: [String]?
    let isPublic: Bool?
}
