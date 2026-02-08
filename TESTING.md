# Testing Guide

This document covers comprehensive testing for both the .NET API and iOS app.

## Test Coverage Overview

### .NET API Tests (33 tests)

**Controllers (20 tests)**:
- **AuthControllerTests** (3 tests): OAuth config, authenticated user retrieval, unauthorized access
- **BooksControllerTests** (4 tests): ISBN normalization, validation, null handling
- **LibrariesControllerTests** (3 tests): Library validation, user IDs, timestamps
- **QuotesControllerTests** (3 tests): Quote matching, request DTOs, response initialization

**Domain Models (7 tests)**:
- **BookTests** (3 tests): Book initialization with Authors list, ISBN variations, empty authors
- **LibraryTests** (4 tests): Library initialization, BookIds management, tags collection

**Application Services**:
- **BookServiceTests** (6 tests): String validation, trimming, non-empty checks

### iOS Tests (8+ tests)

**Models**:
- **UserTests**: User initialization, equality comparisons
- **LibraryTests**: Library properties and equality
- **BookTests**: Book initialization with all properties
- **QuoteTests**: Quote model validation

**Services**:
- **AuthenticationServiceTests**: Auth state, sign out flow, initialization

**ViewModels**:
- **LibrariesListViewModelTests**: Loading state management
- **CreateLibraryViewModelTests**: Form validation logic
- **ScanIsbnViewModelTests**: ISBN processing and validation

## .NET API Unit Tests

### Running Tests

```bash
# Run all tests (from repository root)
cd virtual-library/api
dotnet test

# Run with detailed output (from repository root)
cd virtual-library/api
dotnet test --verbosity normal

# Run with coverage (from repository root)
cd virtual-library/api
dotnet test --collect:"XPlat Code Coverage"

# Run specific test class
dotnet test --filter "FullyQualifiedName~BookTests"

# Run specific test method
dotnet test --filter "FullyQualifiedName~Book_Initialization_SetsProperties"

# Run tests in watch mode
dotnet watch test
```

### Test Structure

Tests are organized to mirror the application structure:

```
VirtualLibrary.Api.Tests/
├── Controllers/              # API endpoint tests
│   ├── AuthControllerTests.cs        # OAuth, user auth
│   ├── BooksControllerTests.cs       # ISBN lookup, validation
│   ├── LibrariesControllerTests.cs   # Library management
│   └── QuotesControllerTests.cs      # Quote verification
├── Domain/                   # Domain model tests
│   ├── BookTests.cs                  # Book entity tests
│   └── LibraryTests.cs               # Library entity tests
└── Application/
    └── Services/             # Business logic tests
        └── BookServiceTests.cs       # Validation rules
```

### Writing Tests

We use:
- **xUnit** - Test framework
- **Moq** - Mocking library
- **FluentAssertions** - Assertion library
- **Microsoft.AspNetCore.Mvc.Testing** - Integration testing

Example test:

```csharp
[Fact]
public async Task LookupByIsbn_WithValidIsbn_ReturnsOkResult()
{
    // Arrange
    var isbn = "9780134685991";
    _bookServiceMock.Setup(x => x.LookupByIsbnAsync(isbn))
        .ReturnsAsync(new BookDto { Isbn = isbn, Title = "Test" });

    // Act
    var result = await _controller.LookupByIsbn(new IsbnLookupRequest { Isbn = isbn });

    // Assert
    result.Result.Should().BeOfType<OkObjectResult>();
}
```

## iOS SwiftUI Tests

### Setup Required

The test files have been created but need to be added to the Xcode project as a test target:

1. Open `VirtualLibrary.xcworkspace` in Xcode
2. **Add Test Target**:
   - File → New → Target
   - Select "Unit Testing Bundle"
   - Product Name: `VirtualLibraryTests`
   - Target to be Tested: `VirtualLibrary`
   - Click Finish
3. **Add Test Files**:
   - Select the `VirtualLibraryTests` folder in Finder
   - Drag all test files into the test target in Xcode
   - Ensure they're added to the `VirtualLibraryTests` target
4. **Configure Scheme**:
   - Product → Scheme → Edit Scheme (`Cmd + <`)
   - Select "Test" in left sidebar
   - Click "+" and add `VirtualLibraryTests`
   - Enable "Code Coverage"

### Running Tests

In Xcode (after setup):
- Press `Cmd + U` to run all tests
- Click the diamond next to a test to run individual tests
- View test results in the Test Navigator (`Cmd + 6`)

From command line (after setup):
```bash
cd virtual-library/ios
xcodebuild test \
  -workspace VirtualLibrary.xcworkspace \
  -scheme VirtualLibrary \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

### Test Structure

```
VirtualLibraryTests/
├── AuthenticationServiceTests.swift    # Auth state management
├── Models/
│   ├── UserTests.swift                 # User model
│   ├── LibraryTests.swift              # Library model
│   ├── BookTests.swift                 # Book model
│   └── QuoteTests.swift                # Quote model
└── ViewModels/
    ├── LibrariesListViewModelTests.swift
    ├── CreateLibraryViewModelTests.swift
    └── ScanIsbnViewModelTests.swift
```

### Writing Tests

We use XCTest framework with:
- Unit tests for ViewModels and Services
- UI tests for view interactions (create separate UITests target)

Example test:

```swift
func testUserInitialization_WithAllProperties() {
    // Arrange
    let id = "test-id"
    let fullName = "John Doe"
    let email = "john@example.com"
    
    // Act
    let user = User(id: id, fullName: fullName, email: email)
    
    // Assert
    XCTAssertEqual(user.id, id)
    XCTAssertEqual(user.fullName, fullName)
}
```

## Best Practices

### API Tests
1. **Arrange-Act-Assert** pattern for clarity
2. **Mock external dependencies** (repositories, HTTP clients)
3. **Test edge cases** with `[Theory]` and `[InlineData]`
4. **Use descriptive test names** that describe the scenario
5. **Keep tests isolated** - no shared state

### iOS Tests
1. **Setup and teardown** in `setUp()` and `tearDown()`
2. **Test one thing at a time**
3. **Use async/await** for asynchronous tests
4. **Mock network calls** using protocols
5. **Test view model logic**, not SwiftUI views directly

## CI/CD Integration

### GitHub Actions

Add to `.github/workflows/test.yml`:

```yaml
name: Tests

on: [push, pull_request]

jobs:
  api-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup .NET
        uses: actions/setup-dotnet@v3
        with:
          dotnet-version: '10.0.x'
      - name: Run tests
        run: dotnet test --configuration Release

  # iOS tests - Uncomment after adding test target to Xcode project
  # ios-tests:
  #   runs-on: macos-latest
  #   steps:
  #     - uses: actions/checkout@v3
  #     - name: Run tests
  #       run: |
  #         cd virtual-library/ios
  #         xcodebuild test \
  #           -workspace VirtualLibrary.xcworkspace \
  #           -scheme VirtualLibrary \
  #           -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

## Coverage Reports

### .NET
```bash
# Generate coverage report
dotnet test --collect:"XPlat Code Coverage"

# Install report generator
dotnet tool install -g dotnet-reportgenerator-globaltool

# Generate HTML report
reportgenerator \
  -reports:"**/coverage.cobertura.xml" \
  -targetdir:"coveragereport" \
  -reporttypes:Html
```

### iOS
Use Xcode's built-in code coverage:
1. Edit scheme (`Cmd + <`)
2. Enable "Code Coverage" under Test
3. View coverage in the Report Navigator after running tests
