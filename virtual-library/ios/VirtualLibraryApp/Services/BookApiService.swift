import Foundation
import UIKit

/// Service responsible for communicating with the Virtual Library API.
/// Handles all network requests using async/await pattern.
class BookApiService: ObservableObject {
    /// Base URL for the API - configure this to point to your backend
    private let baseURL: String
    
    /// Published error message
    @Published var error: String?
    
    /// Published loading state
    @Published var isLoading = false
    
    /// Initialize with custom base URL
    /// - Parameter baseURL: The API base URL (defaults to Azure production endpoint)
    init(baseURL: String? = nil) {
        // Default to Azure production endpoint
        // For local development, pass "http://localhost:5001" when initializing
        self.baseURL = baseURL ?? "https://virtual-library-api-web.azurewebsites.net"
    }
    
    /// Look up a book by ISBN
    /// - Parameter isbn: The ISBN to search for
    /// - Returns: Book information if found, nil otherwise
    func lookupByIsbn(_ isbn: String) async throws -> Book? {
        let url = URL(string: "\(baseURL)/api/books/lookup")!
        
        print("📡 API Request: POST \(url)")
        print("📦 Request Body: {\"isbn\": \"\(isbn)\"}")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = LookupByIsbnRequest(isbn: isbn)
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        await MainActor.run { isLoading = true }
        defer { Task { await MainActor.run { isLoading = false } } }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            print("📥 Response Status: \(httpResponse.statusCode)")
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 Response Body: \(responseString)")
            }
            
            if httpResponse.statusCode == 404 {
                print("⚠️ Book not found for ISBN: \(isbn)")
                return nil // Book not found
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw APIError.serverError(httpResponse.statusCode)
            }
            
            let bookResponse = try JSONDecoder().decode(BookResponse.self, from: data)
            print("✅ Successfully decoded book: \(bookResponse.title)")
            return bookResponse.toBook()
            
        } catch let error as APIError {
            print("❌ API Error: \(error.localizedDescription)")
            await MainActor.run { self.error = error.localizedDescription }
            throw error
        } catch {
            print("❌ Network Error: \(error.localizedDescription)")
            await MainActor.run { self.error = "Network error: \(error.localizedDescription)" }
            throw APIError.networkError(error)
        }
    }
    
    /// Search for books by cover text (OCR results) and/or image
    /// - Parameters:
    ///   - extractedText: Text extracted from the book cover
    ///   - coverImage: Optional cover image for visual search
    /// - Returns: List of potential book matches
    func searchByCover(_ extractedText: String, coverImage: UIImage? = nil) async throws -> [Book] {
        let url = URL(string: "\(baseURL)/api/books/search-by-cover")!
        
        print("📡 API Request: POST \(url)")
        print("📦 Extracted Text: \(extractedText)")
        
        // Convert image to base64 if provided
        var imageDataBase64: String? = nil
        if let image = coverImage {
            // Resize image to reduce payload size
            let maxDimension: CGFloat = 800
            let resizedImage = resizeImage(image, maxDimension: maxDimension)
            
            if let imageData = resizedImage.jpegData(compressionQuality: 0.7) {
                imageDataBase64 = imageData.base64EncodedString()
                print("📸 Sending cover image: \(imageData.count) bytes (base64: \(imageDataBase64!.count) chars)")
            }
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = SearchByCoverRequest(extractedText: extractedText, imageData: imageDataBase64)
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        await MainActor.run { isLoading = true }
        defer { Task { await MainActor.run { isLoading = false } } }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            print("📥 Response Status: \(httpResponse.statusCode)")
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 Response Body (first 500 chars): \(responseString.prefix(500))")
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw APIError.serverError(httpResponse.statusCode)
            }
            
            let searchResponse = try JSONDecoder().decode(SearchBooksResponse.self, from: data)
            print("✅ Found \(searchResponse.books.count) books")
            
            for (index, bookResponse) in searchResponse.books.enumerated() {
                print("  📖 Book \(index + 1):")
                print("     Title: \(bookResponse.title)")
                print("     Authors: \(bookResponse.authors.joined(separator: ", "))")
                print("     ID: \(bookResponse.id?.uuidString ?? "nil")")
                print("     ISBN: \(bookResponse.isbn ?? "nil")")
                print("     Cover: \(bookResponse.coverImageUrl ?? "nil")")
                print("     Source: \(bookResponse.source ?? "nil")")
            }
            
            let books = searchResponse.books.map { $0.toBook() }
            print("✅ Converted to \(books.count) Book objects")
            return books
            
        } catch let error as APIError {
            print("❌ API Error: \(error.localizedDescription)")
            await MainActor.run { self.error = error.localizedDescription }
            throw error
        } catch {
            print("❌ Network Error: \(error.localizedDescription)")
            await MainActor.run { self.error = "Network error: \(error.localizedDescription)" }
            throw APIError.networkError(error)
        }
    }
    
    /// Save a book to the database
    /// - Parameter book: Book to save
    /// - Returns: Saved book with ID
    func saveBook(_ book: Book) async throws -> Book {
        let url = URL(string: "\(baseURL)/api/books")!
        
        print("🔵 [API] Saving book to database")
        print("   URL: \(url.absoluteString)")
        print("   Title: \(book.title)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Convert Book to SaveBookRequest
        let saveRequest = SaveBookRequest(
            id: book.id,
            title: book.title,
            authors: book.authors,
            isbn: book.isbn,
            publisher: book.publisher,
            publishYear: book.publishYear,
            pageCount: book.pageCount,
            description: book.description,
            coverImageUrl: book.coverImageUrl,
            source: book.source,
            externalId: nil
        )
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(saveRequest)
        
        if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            print("   Request body: \(bodyString)")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [API] Invalid response type")
                throw APIError.invalidResponse
            }
            
            print("🔵 [API] Response status: \(httpResponse.statusCode)")
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("🔵 [API] Response body: \(responseString)")
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("❌ [API] HTTP error: \(httpResponse.statusCode)")
                throw APIError.invalidResponse
            }
            
            let decoder = JSONDecoder()
            let bookResponse = try decoder.decode(BookResponse.self, from: data)
            let savedBook = bookResponse.toBook()
            
            print("✅ [API] Book saved with ID: \(savedBook.id?.uuidString ?? "nil")")
            return savedBook
        } catch {
            print("❌ [API] Error saving book: \(error)")
            throw error
        }
    }
    
    // MARK: - Library Management
    
    /// Get all libraries
    func getAllLibraries() async throws -> [LibraryModel] {
        let url = URL(string: "\(baseURL)/api/libraries")!
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([LibraryModel].self, from: data)
    }
    
    /// Create a new library
    func createLibrary(_ request: CreateLibraryRequest) async throws -> LibraryModel {
        let url = URL(string: "\(baseURL)/api/libraries")!
        
        print("🔵 Creating library at: \(url.absoluteString)")
        print("🔵 Request data: name=\(request.name), owner=\(request.owner), tags=\(request.tags ?? [])")
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)
        
        if let body = urlRequest.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            print("🔵 Request body: \(bodyString)")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type")
                throw APIError.invalidResponse
            }
            
            print("🔵 Response status: \(httpResponse.statusCode)")
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("🔵 Response body: \(responseString)")
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("❌ HTTP error: \(httpResponse.statusCode)")
                throw APIError.invalidResponse
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let library = try decoder.decode(LibraryModel.self, from: data)
            print("✅ Library created successfully: \(library.name)")
            return library
        } catch {
            print("❌ Error creating library: \(error)")
            throw error
        }
    }
    
    /// Get libraries by owner
    func getLibrariesByOwner(_ owner: String) async throws -> [LibraryModel] {
        let encodedOwner = owner.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? owner
        let url = URL(string: "\(baseURL)/api/libraries/owner/\(encodedOwner)")!
        
        print("🔵 Loading libraries for owner: \(owner)")
        print("🔵 Request URL: \(url.absoluteString)")
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type")
                throw APIError.invalidResponse
            }
            
            print("🔵 Response status: \(httpResponse.statusCode)")
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("🔵 Response body: \(responseString)")
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("❌ HTTP error: \(httpResponse.statusCode)")
                throw APIError.invalidResponse
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let libraries = try decoder.decode([LibraryModel].self, from: data)
            print("✅ Decoded \(libraries.count) libraries")
            return libraries
        } catch let urlError as URLError where urlError.code == .cancelled {
            // Request was cancelled, just rethrow without logging error
            throw urlError
        } catch {
            print("❌ Error loading libraries: \(error)")
            throw error
        }
    }
    
    /// Get books in a library
    func getBooksInLibrary(libraryId: UUID) async throws -> [Book] {
        let url = URL(string: "\(baseURL)/api/libraries/\(libraryId.uuidString)/books")!
        
        print("🔵 [API] Getting books in library")
        print("   URL: \(url.absoluteString)")
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [API] Invalid response type")
                throw APIError.invalidResponse
            }
            
            print("🔵 [API] Response status: \(httpResponse.statusCode)")
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("❌ [API] HTTP error: \(httpResponse.statusCode)")
                throw APIError.invalidResponse
            }
            
            // Log raw response
            if let responseString = String(data: data, encoding: .utf8) {
                print("🔵 [API] Raw response: \(responseString)")
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let bookResponses = try decoder.decode([BookResponse].self, from: data)
            let books = bookResponses.map { $0.toBook() }
            print("✅ [API] Loaded \(books.count) books")
            return books
        } catch {
            print("❌ [API] Error getting library books: \(error)")
            throw error
        }
    }
    
    /// Add books to a library
    func addBooksToLibrary(libraryId: UUID, bookIds: [UUID]) async throws {
        let url = URL(string: "\(baseURL)/api/libraries/\(libraryId.uuidString)/books")!
        
        print("🔵 [API] Adding books to library")
        print("   URL: \(url.absoluteString)")
        print("   Library ID: \(libraryId.uuidString)")
        print("   Book IDs: \(bookIds.map { $0.uuidString })")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Create properly structured request matching backend expectations
        struct AddBooksRequest: Codable {
            let bookIds: [UUID]
        }
        let requestBody = AddBooksRequest(bookIds: bookIds)
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            print("   Request body: \(bodyString)")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [API] Invalid response type")
                throw APIError.invalidResponse
            }
            
            print("🔵 [API] Response status: \(httpResponse.statusCode)")
            
            if let responseString = String(data: data, encoding: .utf8), !responseString.isEmpty {
                print("🔵 [API] Response body: \(responseString)")
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("❌ [API] HTTP error: \(httpResponse.statusCode)")
                throw APIError.invalidResponse
            }
            
            print("✅ [API] Books added successfully")
        } catch {
            print("❌ [API] Error adding books: \(error)")
            throw error
        }
    }
    
    /// Remove books from a library
    func removeBooksFromLibrary(libraryId: UUID, bookIds: [UUID]) async throws {
        let url = URL(string: "\(baseURL)/api/libraries/\(libraryId.uuidString)/books")!
        
        print("🔵 [API] Removing books from library")
        print("   URL: \(url.absoluteString)")
        print("   Library ID: \(libraryId.uuidString)")
        print("   Book IDs: \(bookIds.map { $0.uuidString })")
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        struct RemoveBooksRequest: Codable {
            let bookIds: [UUID]
        }
        let requestBody = RemoveBooksRequest(bookIds: bookIds)
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            print("   Request body: \(bodyString)")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [API] Invalid response type")
                throw APIError.invalidResponse
            }
            
            print("🔵 [API] Remove response status: \(httpResponse.statusCode)")
            
            if let responseString = String(data: data, encoding: .utf8), !responseString.isEmpty {
                print("🔵 [API] Response body: \(responseString)")
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("❌ [API] HTTP error: \(httpResponse.statusCode)")
                throw APIError.invalidResponse
            }
            
            print("✅ [API] Books removed successfully")
        } catch {
            print("❌ [API] Error removing books: \(error)")
            throw error
        }
    }
    
    // MARK: - Helper Methods
    
    /// Resize image to fit within max dimension while maintaining aspect ratio
    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let ratio = maxDimension / max(size.width, size.height)
        
        // If image is already smaller, return as-is
        guard ratio < 1 else { return image }
        
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return resizedImage ?? image
    }
}

// MARK: - API Errors
enum APIError: LocalizedError {
    case invalidResponse
    case serverError(Int)
    case networkError(Error)
    case decodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let code):
            return "Server error: \(code)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        }
    }
}
