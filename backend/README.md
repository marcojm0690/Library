# Virtual Library - Backend API

A .NET 8 Web API implementing Clean Architecture for book identification by ISBN barcode or cover image OCR.

## Architecture

The backend follows Clean Architecture principles with the following layers:

### Projects

- **VirtualLibrary.API**: Web API layer with controllers and endpoints
- **VirtualLibrary.Application**: Business logic, DTOs, and service interfaces
- **VirtualLibrary.Domain**: Domain entities (Book)
- **VirtualLibrary.Infrastructure**: External service implementations (stub implementations)

### Project Dependencies

```
VirtualLibrary.API
├── VirtualLibrary.Application
│   └── VirtualLibrary.Domain
└── VirtualLibrary.Infrastructure
    ├── VirtualLibrary.Application
    └── VirtualLibrary.Domain
```

## API Endpoints

### POST /api/books/lookup
Look up a book by ISBN barcode.

**Request:**
```json
{
  "isbn": "9780134685991"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Book found successfully",
  "book": {
    "isbn": "9780134685991",
    "title": "Sample Book Title",
    "author": "Sample Author",
    "publisher": "Sample Publisher",
    "publicationYear": 2024,
    "description": "Book description...",
    "coverImageUrl": "https://example.com/cover.jpg",
    "categories": ["Fiction", "Technology"]
  }
}
```

### POST /api/books/search-by-cover
Search for books by analyzing a cover image using OCR.

**Request:**
```json
{
  "imageBase64": "base64_encoded_image_data"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Found 2 book(s)",
  "books": [
    {
      "isbn": "9780134685991",
      "title": "Effective Java",
      "author": "Joshua Bloch",
      "publisher": "Addison-Wesley",
      "publicationYear": 2018,
      "description": "Book description...",
      "coverImageUrl": "https://example.com/cover.jpg",
      "categories": ["Programming", "Java"]
    }
  ]
}
```

## Building and Running

### Prerequisites
- .NET 8 SDK or later

### Build
```bash
cd backend
dotnet build
```

### Run
```bash
cd backend/VirtualLibrary.API
dotnet run
```

The API will be available at:
- HTTP: http://localhost:5000
- HTTPS: https://localhost:5001
- Swagger UI: https://localhost:5001/swagger

## Development

### Project Structure
```
backend/
├── VirtualLibrary.API/
│   ├── Controllers/
│   │   └── BooksController.cs
│   ├── Program.cs
│   └── appsettings.json
├── VirtualLibrary.Application/
│   ├── DTOs/
│   │   ├── BookDto.cs
│   │   ├── BookLookupRequest.cs
│   │   ├── BookLookupResponse.cs
│   │   ├── SearchByCoverRequest.cs
│   │   └── SearchByCoverResponse.cs
│   └── Interfaces/
│       ├── IBookLookupService.cs
│       └── IImageRecognitionService.cs
├── VirtualLibrary.Domain/
│   └── Entities/
│       └── Book.cs
├── VirtualLibrary.Infrastructure/
│   └── Services/
│       ├── StubBookLookupService.cs
│       └── StubImageRecognitionService.cs
└── VirtualLibrary.sln
```

### Stub Implementations

The current implementation uses stub services that return mock data:

- **StubBookLookupService**: Returns sample book data for any ISBN
- **StubImageRecognitionService**: Returns a list of sample books for any image

To implement real functionality, create new service classes that implement the same interfaces and integrate with external APIs such as:
- Google Books API
- Open Library API
- Vision AI services for OCR

## CORS Configuration

CORS is configured to allow all origins for development. For production, update the CORS policy in `Program.cs` to restrict access to specific origins.

## Future Enhancements

- Database integration for book storage and caching
- Authentication and authorization
- Integration with real book lookup APIs (Google Books, Open Library)
- Integration with OCR/Vision services (Google Vision, Azure Computer Vision)
- Rate limiting and API key management
- Unit and integration tests
