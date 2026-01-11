# API Contracts

This document defines the contract between the iOS app and the .NET API.

## Base URL
- Development: `http://localhost:5000`
- Production: `https://your-api-domain.com`

## Endpoints

### 1. Lookup Book by ISBN

**Endpoint:** `POST /api/books/lookup`

**Request:**
```json
{
  "isbn": "978-0-123456-78-9"
}
```

**Response (200 OK):**
```json
{
  "id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
  "isbn": "978-0-123456-78-9",
  "title": "Sample Book Title",
  "authors": ["Author Name"],
  "publisher": "Publisher Name",
  "publishYear": 2024,
  "coverImageUrl": "https://example.com/cover.jpg",
  "description": "Book description",
  "pageCount": 350,
  "source": "GoogleBooks"
}
```

**Response (404 Not Found):**
```json
{
  "error": "Book not found",
  "isbn": "978-0-123456-78-9"
}
```

**Response (400 Bad Request):**
```json
{
  "error": "ISBN is required"
}
```

### 2. Search Books by Cover Text

**Endpoint:** `POST /api/books/search-by-cover`

**Request:**
```json
{
  "extractedText": "The Great Gatsby\nF. Scott Fitzgerald",
  "imageData": null
}
```

**Response (200 OK):**
```json
{
  "books": [
    {
      "id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
      "isbn": "978-0-123456-78-9",
      "title": "The Great Gatsby",
      "authors": ["F. Scott Fitzgerald"],
      "publisher": "Scribner",
      "publishYear": 1925,
      "coverImageUrl": "https://example.com/cover.jpg",
      "description": "A novel about the American Dream",
      "pageCount": 180,
      "source": "OpenLibrary"
    }
  ],
  "totalResults": 1
}
```

**Response (400 Bad Request):**
```json
{
  "error": "Extracted text is required"
}
```

## Data Types

### Book
- `id`: UUID (nullable) - Internal system identifier
- `isbn`: string (nullable) - ISBN-10 or ISBN-13
- `title`: string - Book title
- `authors`: string[] - List of author names
- `publisher`: string (nullable) - Publisher name
- `publishYear`: integer (nullable) - Year of publication
- `coverImageUrl`: string (nullable) - URL to cover image
- `description`: string (nullable) - Book synopsis
- `pageCount`: integer (nullable) - Number of pages
- `source`: string (nullable) - Provider name (e.g., "GoogleBooks", "OpenLibrary")

## Error Handling

All errors follow a consistent format:
```json
{
  "error": "Description of the error"
}
```

HTTP Status Codes:
- `200 OK` - Request successful
- `400 Bad Request` - Invalid request parameters
- `404 Not Found` - Resource not found
- `500 Internal Server Error` - Server error

## Notes

1. **ISBN Format**: The API accepts both ISBN-10 and ISBN-13 formats with or without dashes
2. **OCR Text**: The extracted text should be the raw OCR output; the API handles parsing
3. **Image Data**: Currently optional; reserved for future ML enhancements
4. **CORS**: The API is configured to accept requests from any origin in development
5. **Authentication**: Not implemented in this version; add as needed for production
