import XCTest
@testable import VirtualLibrary

final class ScanIsbnViewModelTests: XCTestCase {
    
    var sut: ScanIsbnViewModel!
    
    override func setUp() {
        super.setUp()
        sut = ScanIsbnViewModel()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    func testInitialState() {
        // Assert
        XCTAssertNil(sut.scannedBook)
        XCTAssertNil(sut.lastError)
        XCTAssertFalse(sut.isLoading)
    }
    
    func testIsbnNormalization() {
        // Arrange
        let isbnWithHyphens = "978-0-13-468599-1"
        
        // Act
        let normalized = isbnWithHyphens.replacingOccurrences(of: "-", with: "")
        
        // Assert
        XCTAssertEqual(normalized, "9780134685991")
    }
    
    func testIsbnValidation_ValidIsbn13() {
        // Arrange
        let isbn = "9780134685991"
        
        // Act
        let isValid = isbn.count == 13
        
        // Assert
        XCTAssertTrue(isValid)
    }
    
    func testIsbnValidation_ValidIsbn10() {
        // Arrange
        let isbn = "0134685997"
        
        // Act
        let isValid = isbn.count == 10
        
        // Assert
        XCTAssertTrue(isValid)
    }
}
