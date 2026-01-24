import Foundation

struct DetectedBook: Identifiable, Equatable {
    let id: UUID
    let detectedText: String
    let isbn: String?
    let boundingBox: CGRect
    var book: Book?
    var isConfirmed: Bool // True when book has been successfully fetched from API
    
    init(id: UUID = UUID(), detectedText: String, isbn: String? = nil, boundingBox: CGRect, book: Book? = nil, isConfirmed: Bool = false) {
        self.id = id
        self.detectedText = detectedText
        self.isbn = isbn
        self.boundingBox = boundingBox
        self.book = book
        self.isConfirmed = isConfirmed
    }
    
    static func == (lhs: DetectedBook, rhs: DetectedBook) -> Bool {
        lhs.id == rhs.id &&
        lhs.detectedText == rhs.detectedText &&
        lhs.isbn == rhs.isbn &&
        lhs.boundingBox == rhs.boundingBox
    }
}
