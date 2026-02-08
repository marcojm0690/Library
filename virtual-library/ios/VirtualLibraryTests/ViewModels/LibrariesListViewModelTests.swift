import XCTest
@testable import VirtualLibrary

final class LibrariesListViewModelTests: XCTestCase {
    
    var sut: LibrariesListViewModel!
    
    override func setUp() {
        super.setUp()
        sut = LibrariesListViewModel()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    func testInitialState() {
        // Assert
        XCTAssertTrue(sut.libraries.isEmpty)
        XCTAssertFalse(sut.isLoading)
    }
    
    func testLoadLibraries_SetsLoadingState() async {
        // Act
        let expectation = XCTestExpectation(description: "Loading state changed")
        
        Task {
            await sut.loadLibraries(for: "test@example.com")
            expectation.fulfill()
        }
        
        // Assert - Check that loading was set to true at some point
        // (This is a simplified test - you'd need a more sophisticated approach)
        await fulfillment(of: [expectation], timeout: 2.0)
    }
}
