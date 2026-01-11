# Virtual Library - Mono-Repo

A mono-repository containing a .NET 8 Web API backend and an iOS SwiftUI frontend for book identification by ISBN barcode scanning or cover image OCR.

## 📚 Project Overview

Virtual Library is a cross-platform solution that allows users to identify books through:
- **ISBN Barcode Scanning**: Scan physical barcodes on books
- **Cover Image OCR**: Take photos of book covers for identification

## 🏗️ Repository Structure

```
virtual-library/
├── backend/                  # .NET 8 Web API with Clean Architecture
│   ├── VirtualLibrary.API/           # Web API controllers and endpoints
│   ├── VirtualLibrary.Application/   # Business logic, DTOs, interfaces
│   ├── VirtualLibrary.Domain/        # Domain entities
│   ├── VirtualLibrary.Infrastructure/# External service implementations
│   └── README.md
├── ios/                      # iOS SwiftUI Application
│   ├── VirtualLibrary/               # Swift source files
│   │   ├── Models/                   # Data models
│   │   ├── ViewModels/               # MVVM view models
│   │   ├── Views/                    # SwiftUI views (no storyboards)
│   │   └── Services/                 # Barcode, OCR, and API services
│   ├── VirtualLibrary.xcodeproj/     # Xcode project
│   └── README.md
└── README.md                 # This file
```

## 🚀 Quick Start

### Backend (.NET 8 Web API)

```bash
cd backend
dotnet build
cd VirtualLibrary.API
dotnet run
```

The API will be available at:
- HTTP: http://localhost:5000
- HTTPS: https://localhost:5001
- Swagger: https://localhost:5001/swagger

**API Endpoints:**
- `POST /api/books/lookup` - Look up book by ISBN
- `POST /api/books/search-by-cover` - Search books by cover image

### iOS App (SwiftUI)

1. Open `ios/VirtualLibrary.xcodeproj` in Xcode
2. Update the API base URL in `Services/APIService.swift`
3. Run on a physical device (recommended for camera features)

## 🛠️ Technologies

### Backend
- **.NET 8**: Modern web API framework
- **Clean Architecture**: Separation of concerns with Domain, Application, Infrastructure, and API layers
- **ASP.NET Core**: Web API with Swagger/OpenAPI documentation
- **Dependency Injection**: Built-in DI container
- **Async/Await**: Modern async programming patterns

### iOS
- **SwiftUI**: Declarative UI framework (no storyboards)
- **MVVM**: Model-View-ViewModel architecture
- **AVFoundation**: Barcode scanning with device camera
- **Vision Framework**: OCR for text recognition from images
- **Combine**: Reactive programming for data binding
- **URLSession**: Async/await HTTP networking

## 📖 Documentation

Detailed documentation for each component:

- [Backend Documentation](./backend/README.md) - API architecture, endpoints, and development guide
- [iOS Documentation](./ios/README.md) - App architecture, features, and development guide

## 🔧 Development Setup

### Prerequisites

**Backend:**
- .NET 8 SDK or later
- Any IDE (Visual Studio, VS Code, Rider)

**iOS:**
- macOS with Xcode 14.0 or later
- iOS 15.0 or later (target device)
- Apple Developer account (for device testing)

### Building from Source

1. **Clone the repository:**
   ```bash
   git clone <repository-url>
   cd Library
   ```

2. **Build backend:**
   ```bash
   cd backend
   dotnet build
   ```

3. **Build iOS app:**
   - Open `ios/VirtualLibrary.xcodeproj` in Xcode
   - Build (⌘ + B)

## 🎯 Features

### Current Implementation (Stub Services)

- ✅ Clean Architecture backend with .NET 8
- ✅ RESTful API with two endpoints
- ✅ iOS app with barcode scanning (AVFoundation)
- ✅ iOS app with OCR capability (Vision)
- ✅ Async/await networking in iOS
- ✅ MVVM architecture in iOS
- ✅ Swagger/OpenAPI documentation
- ✅ CORS configured for cross-origin requests

### Stub Services

Both backend services currently return mock data for demonstration purposes:

- **StubBookLookupService**: Returns sample book data for any ISBN
- **StubImageRecognitionService**: Returns a list of sample books for any image

### Future Enhancements

To make this production-ready, replace stub implementations with:

**Backend:**
- Integration with book APIs (Google Books, Open Library, etc.)
- Real OCR/Vision AI services (Google Vision API, Azure Computer Vision)
- Database for caching and user libraries
- Authentication and user management
- Rate limiting and API key management

**iOS:**
- Offline book storage with Core Data
- User authentication
- Book collections and reading lists
- Social features (sharing, recommendations)
- iPad and Mac support (Catalyst)

## 📝 API Examples

### Look up a book by ISBN

```bash
curl -X POST https://localhost:5001/api/books/lookup \
  -H "Content-Type: application/json" \
  -d '{"isbn": "9780134685991"}'
```

### Search by cover image

```bash
curl -X POST https://localhost:5001/api/books/search-by-cover \
  -H "Content-Type: application/json" \
  -d '{"imageBase64": "<base64-encoded-image>"}'
```

## 🤝 Contributing

This is a mono-repo project. When contributing:

1. Backend changes go in the `backend/` directory
2. iOS changes go in the `ios/` directory
3. Follow the existing architecture patterns
4. Update relevant documentation

## 📄 License

[Specify your license here]

## 🔗 Additional Resources

- [.NET Documentation](https://docs.microsoft.com/en-us/dotnet/)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui/)
- [Clean Architecture by Robert C. Martin](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [MVVM Pattern](https://en.wikipedia.org/wiki/Model%E2%80%93view%E2%80%93viewmodel)