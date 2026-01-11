import Foundation

struct BookLookupRequest: Codable {
    let isbn: String
}

struct BookLookupResponse: Codable {
    let success: Bool
    let message: String
    let book: Book?
}

struct SearchByCoverRequest: Codable {
    let imageBase64: String
}

struct SearchByCoverResponse: Codable {
    let success: Bool
    let message: String
    let books: [Book]
}
