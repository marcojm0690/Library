import Foundation

// MARK: - Library Type

/// Type of library for organizing books
enum LibraryType: Int, Codable, CaseIterable, Identifiable {
    case read = 0
    case toRead = 1
    case reading = 2
    case wishlist = 3
    case favorites = 4
    
    var id: Int { rawValue }
    
    var displayName: String {
        switch self {
        case .read: return "Leídos"
        case .toRead: return "Por Leer"
        case .reading: return "Leyendo"
        case .wishlist: return "Lista de Deseos"
        case .favorites: return "Favoritos"
        }
    }
    
    var icon: String {
        switch self {
        case .read: return "checkmark.circle.fill"
        case .toRead: return "book.closed"
        case .reading: return "book.circle"
        case .wishlist: return "star"
        case .favorites: return "heart.fill"
        }
    }
    
    var color: String {
        switch self {
        case .read: return "green"
        case .toRead: return "blue"
        case .reading: return "orange"
        case .wishlist: return "purple"
        case .favorites: return "red"
        }
    }
}

// MARK: - Library Model

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
    let type: LibraryType
    
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
        case type
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        owner = try container.decode(String.self, forKey: .owner)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        bookIds = try container.decode([UUID].self, forKey: .bookIds)
        bookCount = try container.decode(Int.self, forKey: .bookCount)
        tags = try container.decode([String].self, forKey: .tags)
        isPublic = try container.decode(Bool.self, forKey: .isPublic)
        type = try container.decodeIfPresent(LibraryType.self, forKey: .type) ?? .read
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encode(owner, forKey: .owner)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(bookIds, forKey: .bookIds)
        try container.encode(bookCount, forKey: .bookCount)
        try container.encode(tags, forKey: .tags)
        try container.encode(isPublic, forKey: .isPublic)
        try container.encode(type, forKey: .type)
    }
}

/// Request model for creating a library
struct CreateLibraryRequest: Codable {
    let name: String
    let description: String?
    let owner: String
    let tags: [String]?
    let isPublic: Bool
    let type: LibraryType
    
    enum CodingKeys: String, CodingKey {
        case name
        case description
        case owner
        case tags
        case isPublic
        case type
    }
}

/// Request model for updating a library
struct UpdateLibraryRequest: Codable {
    let name: String?
    let description: String?
    let tags: [String]?
    let isPublic: Bool?
}

/// Response model for vocabulary hints used in speech recognition
struct VocabularyHintsResponse: Codable {
    /// List of vocabulary hints (authors, titles, publishers, etc.)
    let hints: [String]
    
    /// Tags from the user's libraries
    let tags: [String]
    
    /// Total number of books in user's libraries
    let bookCount: Int
    
    /// Whether the hints are personalized based on user's library or general
    let isPersonalized: Bool
}
