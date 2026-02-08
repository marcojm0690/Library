import XCTest
@testable import VirtualLibrary

final class QuoteTests: XCTestCase {
    
    func testQuoteInitialization() {
        // Arrange
        let id = "quote-123"
        let text = "Test quote"
        let bookTitle = "Test Book"
        let author = "Test Author"
        
        // Act
        let quote = Quote(
            id: id,
            text: text,
            bookTitle: bookTitle,
            author: author,
            userId: "user-123",
            libraryId: "lib-123",
            createdAt: Date()
        )
        
        // Assert
        XCTAssertEqual(quote.id, id)
        XCTAssertEqual(quote.text, text)
        XCTAssertEqual(quote.bookTitle, bookTitle)
        XCTAssertEqual(quote.author, author)
    }
    
    func testQuoteEquality() {
        // Arrange
        let quote1 = Quote(id: "1", text: "Text", bookTitle: "Book", author: "Author", userId: "user", libraryId: "lib", createdAt: Date())
        let quote2 = Quote(id: "1", text: "Text", bookTitle: "Book", author: "Author", userId: "user", libraryId: "lib", createdAt: Date())
        let quote3 = Quote(id: "2", text: "Text", bookTitle: "Book", author: "Author", userId: "user", libraryId: "lib", createdAt: Date())
        
        // Assert
        XCTAssertEqual(quote1.id, quote2.id)
        XCTAssertNotEqual(quote1.id, quote3.id)
    }
}
