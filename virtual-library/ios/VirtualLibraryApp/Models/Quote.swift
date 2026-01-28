import Foundation

// MARK: - Quote Verification Models

/// Input method for quote verification
enum QuoteInputMethod: String, Codable {
    case text = "text"
    case voice = "voice"
    case photo = "photo"
}

/// Request model for verifying a quote
struct QuoteVerificationRequest: Codable {
    let quoteText: String
    let claimedAuthor: String?
    let userId: String?
    let inputMethod: String
    
    enum CodingKeys: String, CodingKey {
        case quoteText
        case claimedAuthor
        case userId
        case inputMethod
    }
}

/// Response model for quote verification
struct QuoteVerificationResponse: Codable {
    let originalQuote: String
    let claimedAuthor: String?
    let isVerified: Bool
    let authorVerified: Bool
    let overallConfidence: Double
    let inputMethod: String
    let possibleSources: [QuoteSource]
    let context: String?
    let recommendedBook: Book?
    
    enum CodingKeys: String, CodingKey {
        case originalQuote
        case claimedAuthor
        case isVerified
        case authorVerified
        case overallConfidence
        case inputMethod
        case possibleSources
        case context
        case recommendedBook
    }
}

/// Source book information for a quote
struct QuoteSource: Codable, Identifiable {
    let book: Book
    let confidence: Double
    let matchType: String
    let source: String
    
    var id: UUID {
        book.id ?? UUID()
    }
    
    enum CodingKeys: String, CodingKey {
        case book
        case confidence
        case matchType
        case source
    }
}
