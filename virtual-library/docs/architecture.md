# Architecture Documentation

## Overview

The Virtual Library is a mono-repository containing two independent applications that work together:

1. **.NET 8 Web API** - Backend service for book data lookup and management
2. **iOS SwiftUI App** - Mobile client for scanning and identifying books

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         iOS App                             │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Views     │  │  ViewModels  │  │   Services   │      │
│  │  (SwiftUI)  │─→│    (MVVM)    │─→│  - Camera    │      │
│  │             │  │              │  │  - OCR       │      │
│  └─────────────┘  └──────────────┘  │  - API       │      │
│                                      └──────┬───────┘      │
└─────────────────────────────────────────────┼──────────────┘
                                              │ HTTP/JSON
                                              ↓
┌─────────────────────────────────────────────┼──────────────┐
│                      .NET API               │              │
│  ┌─────────────────────────────────────────┼──────────┐   │
│  │            Controllers Layer            │          │   │
│  │              (BooksController)          │          │   │
│  └────────────────────┬────────────────────┘          │   │
│                       ↓                                │   │
│  ┌─────────────────────────────────────────────────┐  │   │
│  │         Application Layer                       │  │   │
│  │  ┌──────────────────┐  ┌──────────────────┐    │  │   │
│  │  │  SearchByIsbn    │  │  SearchByCover   │    │  │   │
│  │  │    Service       │  │     Service      │    │  │   │
│  │  └──────────────────┘  └──────────────────┘    │  │   │
│  └────────────────────┬────────────────────────────┘  │   │
│                       ↓                                │   │
│  ┌─────────────────────────────────────────────────┐  │   │
│  │         Infrastructure Layer                    │  │   │
│  │  ┌──────────────┐  ┌─────────────────────────┐ │  │   │
│  │  │ Repository   │  │  External Providers     │ │  │   │
│  │  │ (In-Memory)  │  │  - GoogleBooks          │ │  │   │
│  │  │              │  │  - OpenLibrary          │ │  │   │
│  │  └──────────────┘  └─────────────────────────┘ │  │   │
│  └─────────────────────────────────────────────────┘  │   │
│                                                        │   │
│  ┌─────────────────────────────────────────────────┐  │   │
│  │              Domain Layer                       │  │   │
│  │                 (Book Entity)                   │  │   │
│  └─────────────────────────────────────────────────┘  │   │
└────────────────────────────────────────────────────────────┘
```

## Backend Architecture (.NET 8 API)

### Clean Architecture Principles

The API follows Clean Architecture with clear separation of concerns:

#### 1. Domain Layer
- **Responsibility**: Core business entities
- **Dependencies**: None (independent)
- **Contents**: `Book` entity with all book properties

#### 2. Application Layer
- **Responsibility**: Business logic and use cases
- **Dependencies**: Domain layer
- **Contents**:
  - Services for ISBN and cover search
  - DTOs for request/response mapping
  - Abstractions/interfaces for external dependencies

#### 3. Infrastructure Layer
- **Responsibility**: External concerns (data access, external APIs)
- **Dependencies**: Application abstractions
- **Contents**:
  - `InMemoryBookRepository` (placeholder for database)
  - External book provider implementations (Google Books, Open Library)

#### 4. Controllers Layer
- **Responsibility**: HTTP endpoint handling
- **Dependencies**: Application services
- **Contents**: `BooksController` with REST endpoints

### Design Decisions

1. **Minimal Hosting**: Uses .NET 8's minimal hosting model for cleaner Program.cs
2. **Dependency Injection**: All services registered in DI container for testability
3. **Interface-based Design**: External providers implement `IBookProvider` for easy extensibility
4. **Stub Implementations**: External APIs are stubbed with TODOs for actual implementation
5. **In-Memory Storage**: Repository uses in-memory dictionary; replace with EF Core for production
6. **Multiple Providers**: Architecture supports multiple book data sources simultaneously

### API Endpoints

- `POST /api/books/lookup` - ISBN barcode lookup
- `POST /api/books/search-by-cover` - OCR text-based search

## iOS App Architecture (SwiftUI)

### MVVM Pattern

The iOS app follows the Model-View-ViewModel pattern:

#### 1. Views
- **Responsibility**: UI presentation only
- **Dependencies**: ViewModels
- **No Business Logic**: Views only display data and forward user actions

#### 2. ViewModels
- **Responsibility**: Presentation logic and state management
- **Dependencies**: Services
- **Platform-Independent**: No UIKit dependencies (except where necessary for camera/OCR)

#### 3. Services
- **Responsibility**: Platform-specific and external integrations
- **Contents**:
  - `CameraService`: AVFoundation barcode scanning
  - `OCRService`: Vision framework text extraction
  - `BookApiService`: HTTP communication with backend

#### 4. Models
- **Responsibility**: Data structures
- **Contents**: `Book`, request/response DTOs matching API contract

### Design Decisions

1. **SwiftUI + Combine**: Modern reactive UI with `@Published` properties
2. **Async/Await**: All async operations use Swift concurrency
3. **Service Abstraction**: ViewModels depend on service protocols for testability
4. **No Storyboards**: Pure SwiftUI declarative UI
5. **Platform Isolation**: Platform-specific code isolated in services layer

### View Hierarchy

```
HomeView
├── ScanIsbnView
│   └── BookResultView
└── ScanCoverView
    ├── BookRowView
    └── BookResultView
```

## Data Flow

### ISBN Scanning Flow
1. User opens `ScanIsbnView`
2. `CameraService` captures barcode using AVFoundation
3. `ScanIsbnViewModel` receives ISBN from camera
4. `BookApiService` sends POST request to API
5. API searches providers for book data
6. Response mapped to `Book` model
7. `BookResultView` displays book information

### Cover Scanning Flow
1. User opens `ScanCoverView` and takes photo
2. `OCRService` extracts text using Vision framework
3. `ScanCoverViewModel` receives extracted text
4. `BookApiService` sends POST request to API
5. API searches providers using text
6. Multiple results returned as list
7. User selects book to view details in `BookResultView`

## External Dependencies

### Backend
- **ASP.NET Core 8.0**: Web framework
- **Swashbuckle**: Swagger/OpenAPI documentation
- **Future**: Entity Framework Core (when adding database)

### iOS
- **SwiftUI**: UI framework
- **AVFoundation**: Camera and barcode scanning
- **Vision**: OCR text recognition
- **Combine**: Reactive programming

## Security Considerations

1. **CORS**: Currently allows all origins (development only)
2. **HTTPS**: Enforced in production
3. **Input Validation**: API validates all incoming requests
4. **No Secrets in Code**: API keys should be in configuration
5. **Camera Permissions**: iOS app requests permissions properly

## Extensibility Points

### Backend
- **Add Database**: Replace `InMemoryBookRepository` with EF Core
- **Implement Providers**: Complete Google Books and Open Library integrations
- **Add Authentication**: Integrate JWT or OAuth
- **Add Caching**: Implement response caching for performance
- **Add Logging**: Integrate Serilog or similar

### iOS
- **Add ML**: Integrate Core ML for cover image recognition
- **Add Library Management**: Store user's personal library
- **Add Offline Mode**: Cache book data locally
- **Add Social Features**: Share books, recommendations
- **Add Barcode Types**: Support more barcode formats

## Development Setup

### Backend
```bash
cd virtual-library/api/VirtualLibrary.Api
dotnet restore
dotnet build
dotnet run
```

### iOS
```bash
cd virtual-library/ios/VirtualLibraryApp
# Open in Xcode or build with xcodebuild
```

## Testing Strategy

### Backend
- Unit tests for services using mocked dependencies
- Integration tests for controllers
- Repository tests with in-memory data

### iOS
- Unit tests for ViewModels with mocked services
- UI tests for critical flows
- Service tests with mocked network responses

## Deployment

### Backend
- Docker containerization recommended
- Deploy to Azure App Service, AWS ECS, or similar
- Configure environment variables for API keys

### iOS
- TestFlight for beta testing
- App Store deployment following Apple guidelines
- Configure Info.plist for camera/photo permissions

## Future Enhancements

1. **Book Library Management**: User accounts and personal libraries
2. **Wishlist Feature**: Save books to read later
3. **Barcode Generation**: Generate barcodes for personal books
4. **Export/Import**: Backup and restore library data
5. **Analytics**: Track scanning usage and success rates
6. **Recommendation Engine**: Suggest books based on library
7. **Social Sharing**: Share book discoveries with friends
8. **Advanced Search**: Filter by genre, rating, etc.
