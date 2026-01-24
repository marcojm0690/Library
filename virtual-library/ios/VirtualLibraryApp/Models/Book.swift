import Foundation

/// Domain model representing a book in the Virtual Library.
/// Matches the API contract from the backend.
struct Book: Identifiable, Codable {
    let id: UUID?
    let isbn: String?
    let title: String
    let authors: [String]
    let publisher: String?
    let publishYear: Int?
    let coverImageUrl: String?
    let description: String?
    let pageCount: Int?
    let source: String?
    
    /// Display-friendly author list
    var authorsDisplay: String {
        authors.isEmpty ? "Unknown Author" : authors.joined(separator: ", ")
    }
    
    /// Display-friendly year
    var yearDisplay: String {
        guard let year = publishYear else { return "Unknown" }
        return String(year)
    }
}

/// Response model for ISBN lookup
struct BookResponse: Codable {
    let id: UUID?
    let isbn: String?
    let title: String
    let authors: [String]
    let publisher: String?
    let publishYear: Int?
    let coverImageUrl: String?
    let description: String?
    let pageCount: Int?
    let source: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "id"
        case isbn = "isbn"
        case title = "title"
        case authors = "authors"
        case publisher = "publisher"
        case publishYear = "publishYear"
        case coverImageUrl = "coverImageUrl"
        case description = "description"
        case pageCount = "pageCount"
        case source = "source"
    }
    
    /// Convert to Book model
    func toBook() -> Book {
        Book(
            id: id,
            isbn: isbn,
            title: title,
            authors: authors,
            publisher: publisher,
            publishYear: publishYear,
            coverImageUrl: coverImageUrl,
            description: description,
            pageCount: pageCount,
            source: source
        )
    }
}

/// Response model for cover search containing multiple books
struct SearchBooksResponse: Codable {
    let books: [BookResponse]
    let totalResults: Int
    
    enum CodingKeys: String, CodingKey {
        case books = "books"
        case totalResults = "totalResults"
    }
}

/// Request model for ISBN lookup
struct LookupByIsbnRequest: Codable {
    let isbn: String
}

/// Request model for cover search
struct SearchByCoverRequest: Codable {
    let extractedText: String
    let imageData: String?
    
    enum CodingKeys: String, CodingKey {
        case extractedText = "ExtractedText"
        case imageData = "ImageData"
    }
}
