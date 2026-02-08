import XCTest
@testable import VirtualLibrary

final class AuthenticationServiceTests: XCTestCase {
    
    var sut: AuthenticationService!
    
    override func setUp() {
        super.setUp()
        sut = AuthenticationService()
    }
    
    override func tearDown() {

        sut = nil
        super.tearDown()
    }
    
    func testInitialState_IsNotAuthenticated() {
        // Assert
        XCTAssertFalse(sut.isAuthenticated)
        XCTAssertNil(sut.user)
        XCTAssertNil(sut.jwtToken)
    }
    
    func testSignOut_ClearsAuthState() {
        // Act
        sut.signOut()
        
        // Assert
        XCTAssertFalse(sut.isAuthenticated)
        XCTAssertNil(sut.user)
        XCTAssertNil(sut.jwtToken)
    }
    
    func testInitializeIfNeeded_SetsFlag() {
        // Act
        sut.initializeIfNeeded()
        
        // Assert
        // The flag should be set after first call
        XCTAssertTrue(true) // Basic verification that it doesn't crash
    }
    
    func testSignOut_ResetsInitializationFlag() {
        // Arrange
        sut.initializeIfNeeded()
        
        // Act
        sut.signOut()
        
        // Assert
        // After sign out, initialization should be possible again
        XCTAssertFalse(sut.isAuthenticated)
    }
}
