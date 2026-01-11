# Virtual Library

A mono-repository containing a .NET 8 Web API and iOS SwiftUI app for identifying books through ISBN barcode scanning and cover image analysis (OCR).

## 🎯 Purpose

Virtual Library helps users quickly identify and catalog books using two methods:
1. **ISBN Barcode Scanning** - Point your camera at a book's barcode for instant lookup
2. **Cover Image Analysis** - Take a photo of the cover and extract text via OCR to search for the book

The system provides a clean, extensible architecture for book identification without requiring heavy machine learning models.

## 📁 Repository Structure

```
virtual-library/
│
├── README.md                    # This file
├── docs/
│   └── architecture.md          # Detailed architecture documentation
│
├── api/                         # .NET 8 Web API
│   └── VirtualLibrary.Api/
│       ├── Controllers/         # REST API endpoints
│       ├── Application/         # Business logic and services
│       ├── Domain/              # Core entities
│       ├── Infrastructure/      # External integrations and persistence
│       ├── Program.cs           # Application entry point
│       └── VirtualLibrary.Api.csproj
│
├── ios/                         # iOS SwiftUI App
│   └── VirtualLibraryApp/
│       ├── Views/               # SwiftUI views
│       ├── ViewModels/          # MVVM view models
│       ├── Services/            # Platform services (Camera, OCR, API)
│       ├── Models/              # Data models
│       └── VirtualLibraryApp.swift
│
└── shared/
    └── contracts/
        └── book-contracts.md    # API contract documentation
```

## 🏗️ Architecture

### Backend (.NET 8 API)

Built using **Clean Architecture** principles:

- **Domain Layer**: Core business entities (`Book`)
- **Application Layer**: Business logic, services, DTOs
- **Infrastructure Layer**: Data access and external API integrations
- **Controllers Layer**: REST API endpoints

**Key Features:**
- Minimal hosting model (.NET 8)
- Dependency injection throughout
- Interface-based design for extensibility
- Multiple book provider support (Google Books, Open Library)
- In-memory repository (ready for database integration)

**API Endpoints:**
- `POST /api/books/lookup` - Look up book by ISBN
- `POST /api/books/search-by-cover` - Search books by OCR text

### iOS App (SwiftUI)

Built using **MVVM** pattern with SwiftUI:

- **Views**: Pure SwiftUI declarative UI
- **ViewModels**: Presentation logic and state management
- **Services**: Platform-specific integrations
- **Models**: Data structures matching API contracts

**Key Features:**
- SwiftUI with no storyboards
- AVFoundation for barcode scanning
- Vision framework for OCR
- Async/await networking
- Clear separation of concerns

**Views:**
- `HomeView` - Main navigation
- `ScanIsbnView` - Camera-based ISBN scanning
- `ScanCoverView` - Photo capture and OCR processing
- `BookResultView` - Detailed book information display

## 🔄 How They Communicate

The iOS app communicates with the .NET API via RESTful HTTP requests:

1. **ISBN Lookup Flow:**
   - iOS camera scans barcode → extracts ISBN
   - App sends POST to `/api/books/lookup` with ISBN
   - API searches external providers (Google Books, Open Library)
   - Returns book metadata as JSON
   - iOS displays results

2. **Cover Search Flow:**
   - iOS captures photo → OCR extracts text
   - App sends POST to `/api/books/search-by-cover` with text
   - API searches providers using text query
   - Returns list of matching books
   - iOS displays results for user selection

See [`shared/contracts/book-contracts.md`](shared/contracts/book-contracts.md) for detailed API contract.

## 🚀 Getting Started

### Prerequisites

**Backend:**
- [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)

**iOS:**
- macOS with Xcode 15+
- iOS 16+ device or simulator

### Running the Backend

```bash
cd virtual-library/api/VirtualLibrary.Api
dotnet restore
dotnet build
dotnet run
```

The API will start at `http://localhost:5000` (or `https://localhost:5001`).

Access Swagger UI at: `http://localhost:5000/swagger`

### Running the iOS App

1. Open Xcode
2. Open `virtual-library/ios/VirtualLibraryApp/` directory
3. Update `BookApiService.swift` to point to your API URL
4. Build and run on device or simulator

**Note:** Camera and OCR features require a physical iOS device.

### Configuration

**Backend:**
- Update `appsettings.json` for configuration
- Add API keys for Google Books if needed
- Configure CORS for production

**iOS:**
- Update `BookApiService` base URL for your API endpoint
- Add required Info.plist entries for camera permissions:
  - `NSCameraUsageDescription`
  - `NSPhotoLibraryUsageDescription`

## 📋 Current State

### ✅ Implemented
- Complete folder structure following best practices
- .NET API with Clean Architecture
- iOS app with MVVM pattern
- All views and navigation
- Service abstractions and interfaces
- Camera barcode scanning setup
- OCR text extraction setup
- API communication layer
- Documentation

### 🚧 To Implement
- **External Book Providers**: Complete Google Books and Open Library API integrations
- **Database**: Replace in-memory repository with Entity Framework Core
- **Authentication**: Add user authentication and authorization
- **Error Handling**: Enhanced error handling and retry logic
- **Caching**: Implement response caching
- **Testing**: Unit and integration tests
- **ML Enhancement**: Add cover image recognition using Core ML

## 🧪 Testing

The code is structured for testability:

**Backend:**
```bash
# Create and run tests
dotnet test
```

**iOS:**
- Use XCTest for unit and UI tests
- Mock services for ViewModel testing

## 📖 Documentation

- [`docs/architecture.md`](docs/architecture.md) - Detailed architecture decisions and design patterns
- [`shared/contracts/book-contracts.md`](shared/contracts/book-contracts.md) - API contract specification

## 🛡️ Security Considerations

- **API Keys**: Store in configuration, never in code
- **CORS**: Configure appropriately for production
- **HTTPS**: Enforce in production
- **Input Validation**: All API inputs are validated
- **Permissions**: iOS app properly requests camera/photo permissions

## 🔧 Development Notes

### Adding a New Book Provider

1. Create new class in `Infrastructure/External/`
2. Implement `IBookProvider` interface
3. Register in `Program.cs` DI container
4. Provider will automatically be used in search operations

### Adding New Features

- Backend: Follow Clean Architecture layers
- iOS: Follow MVVM pattern with services for platform code
- Update contracts documentation for API changes

## 📝 License

This project is for demonstration purposes. Add your license as needed.

## 🤝 Contributing

1. Create feature branch
2. Follow existing code patterns and architecture
3. Update documentation
4. Submit pull request

## 📞 Support

For issues or questions, please open an issue in the repository.

---

**Built with Clean Architecture and MVVM for maintainability and testability.**
