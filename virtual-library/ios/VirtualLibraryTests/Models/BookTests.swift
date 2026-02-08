import XCTest
@testable import VirtualLibrary

final class BookTests: XCTestCase {
    
    func testBookInitialization_WithAllProperties() {
        // Arrange
        let isbn = "9780134685991"
        let title = "Effective Java"
        let author = "Joshua Bloch"
        
        // Act
        let book = Book(
            isbn: isbn,
            title: title,
            author: author,
            publisher: "Addison-Wesley",
            publishedDate: "2018",
            description: "Test description",
            pageCount: 416,
            categories: ["Programming"],
            thumbnail: "https://example.com/cover.jpg",
            language: "en"
        )
        
        // Assert
        XCTAssertEqual(book.isbn, isbn)
        XCTAssertEqual(book.title, title)
        XCTAssertEqual(book.author, author)
        XCTAssertEqual(book.pageCount, 416)
    }
    
    func testBookEquality() {
        // Arrange
        let book1 = Book(isbn: "123", title: "Book", author: "Author")
        let book2 = Book(isbn: "123", title: "Book", author: "Author")
        let book3 = Book(isbn: "456", title: "Book", author: "Author")
        
        // Assert
        XCTAssertEqual(book1.isbn, book2.isbn)
        XCTAssertNotEqual(book1.isbn, book3.isbn)
    }
}
