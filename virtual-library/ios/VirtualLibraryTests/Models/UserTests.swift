import XCTest
@testable import VirtualLibrary

final class UserTests: XCTestCase {
    
    func testUserInitialization_WithAllProperties() {
        // Arrange
        let id = "test-id"
        let fullName = "John Doe"
        let email = "john@example.com"
        let photoUrl = "data:image/jpeg;base64,..."
        
        // Act
        let user = User(
            id: id,
            fullName: fullName,
            email: email,
            profilePictureUrl: photoUrl
        )
        
        // Assert
        XCTAssertEqual(user.id, id)
        XCTAssertEqual(user.fullName, fullName)
        XCTAssertEqual(user.email, email)
        XCTAssertEqual(user.profilePictureUrl, photoUrl)
    }
    
    func testUserInitialization_WithoutPhotoUrl() {
        // Arrange
        let id = "test-id"
        let fullName = "John Doe"
        let email = "john@example.com"
        
        // Act
        let user = User(
            id: id,
            fullName: fullName,
            email: email
        )
        
        // Assert
        XCTAssertNil(user.profilePictureUrl)
    }
    
    func testUserEquality() {
        // Arrange
        let user1 = User(id: "1", fullName: "John", email: "john@test.com")
        let user2 = User(id: "1", fullName: "John", email: "john@test.com")
        let user3 = User(id: "2", fullName: "Jane", email: "jane@test.com")
        
        // Assert
        XCTAssertEqual(user1, user2)
        XCTAssertNotEqual(user1, user3)
    }
}
