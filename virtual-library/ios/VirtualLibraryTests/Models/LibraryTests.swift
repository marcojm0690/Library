import XCTest
@testable import VirtualLibrary

final class LibraryTests: XCTestCase {
    
    func testLibraryInitialization() {
        // Arrange
        let id = "lib-123"
        let name = "My Library"
        let description = "Test library"
        let owner = "test@example.com"
        
        // Act
        let library = Library(
            id: id,
            name: name,
            description: description,
            owner: owner,
            books: []
        )
        
        // Assert
        XCTAssertEqual(library.id, id)
        XCTAssertEqual(library.name, name)
        XCTAssertEqual(library.description, description)
        XCTAssertEqual(library.owner, owner)
        XCTAssertTrue(library.books.isEmpty)
    }
    
    func testLibraryEquality() {
        // Arrange
        let library1 = Library(id: "1", name: "Lib", description: "", owner: "owner", books: [])
        let library2 = Library(id: "1", name: "Lib", description: "", owner: "owner", books: [])
        let library3 = Library(id: "2", name: "Lib", description: "", owner: "owner", books: [])
        
        // Assert
        XCTAssertEqual(library1, library2)
        XCTAssertNotEqual(library1, library3)
    }
}
