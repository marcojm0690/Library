import XCTest
@testable import VirtualLibrary

final class CreateLibraryViewModelTests: XCTestCase {
    
    var sut: CreateLibraryViewModel!
    
    override func setUp() {
        super.setUp()
        sut = CreateLibraryViewModel()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    func testInitialState() {
        // Assert
        XCTAssertTrue(sut.name.isEmpty)
        XCTAssertTrue(sut.description.isEmpty)
        XCTAssertFalse(sut.isLoading)
    }
    
    func testNameValidation_EmptyName_IsInvalid() {
        // Arrange
        sut.name = ""
        
        // Act
        let isValid = !sut.name.trimmingCharacters(in: .whitespaces).isEmpty
        
        // Assert
        XCTAssertFalse(isValid)
    }
    
    func testNameValidation_ValidName_IsValid() {
        // Arrange
        sut.name = "My Library"
        
        // Act
        let isValid = !sut.name.trimmingCharacters(in: .whitespaces).isEmpty
        
        // Assert
        XCTAssertTrue(isValid)
    }
}
