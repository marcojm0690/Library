import Foundation
import UIKit

/// Protocol for providing authentication tokens
protocol AuthTokenProvider: AnyObject {
    var jwtToken: String? { get }
}

/// Service responsible for communicating with the Virtual Library API.
/// Handles all network requests using async/await pattern.
class BookApiService: ObservableObject {
    /// Base URL for the API - configure this to point to your backend
    private let baseURL: String
    
    /// JWT token for authentication - can be set directly or via tokenProvider
    var authToken: String? {
        get { _authToken ?? tokenProvider?.jwtToken }
        set { _authToken = newValue }
    }
    private var _authToken: String?
    
    /// Weak reference to a shared token provider (like AuthenticationService)
    weak var tokenProvider: AuthTokenProvider?
    
    /// Shared instance with token provider for convenience
    static let shared = BookApiService()
    
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
    
    /// Create an authenticated URLRequest
    private func createRequest(url: URL, method: String = "GET") -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }
    
    /// Look up a book by ISBN
    /// - Parameter isbn: The ISBN to search for
    /// - Returns: Book information if found, nil otherwise
    func lookupByIsbn(_ isbn: String) async throws -> Book? {
        let url = URL(string: "\(baseURL)/api/books/lookup")!
        
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
            
            if httpResponse.statusCode == 404 {
                return nil // Book not found
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw APIError.serverError(httpResponse.statusCode)
            }
            
            let bookResponse = try JSONDecoder().decode(BookResponse.self, from: data)
            return bookResponse.toBook()
            
        } catch let error as APIError {
            await MainActor.run { self.error = error.localizedDescription }
            throw error
        } catch {
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
        
        // Convert image to base64 if provided
        var imageDataBase64: String? = nil
        if let image = coverImage {
            // Resize image to reduce payload size
            let maxDimension: CGFloat = 800
            let resizedImage = resizeImage(image, maxDimension: maxDimension)
            
            if let imageData = resizedImage.jpegData(compressionQuality: 0.7) {
                imageDataBase64 = imageData.base64EncodedString()
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
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw APIError.invalidResponse
            }
            
            let searchResponse = try JSONDecoder().decode(SearchBooksResponse.self, from: data)
            return searchResponse.books.map { $0.toBook() }
            
        } catch let error as APIError {
            await MainActor.run { self.error = error.localizedDescription }
            throw error
        } catch {
            await MainActor.run { self.error = "Network error: \(error.localizedDescription)" }
            throw APIError.networkError(error)
        }
    }
    
    /// Save a book to the database
    /// - Parameter book: Book to save
    /// - Returns: Saved book with ID
    func saveBook(_ book: Book) async throws -> Book {
        let url = URL(string: "\(baseURL)/api/books")!
        
        var request = createRequest(url: url, method: "POST")
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
        
        request.httpBody = try JSONEncoder().encode(saveRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        let bookResponse = try decoder.decode(BookResponse.self, from: data)
        return bookResponse.toBook()
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
        
        print("🔵 [API] createLibrary called")
        print("🔵 [API] URL: \(url)")
        print("🔵 [API] Auth token present: \(authToken != nil)")
        if let token = authToken {
            print("🔵 [API] Token prefix: \(String(token.prefix(20)))...")
        }
        
        var urlRequest = createRequest(url: url, method: "POST")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)
        
        if let body = urlRequest.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            print("🔵 [API] Request body: \(bodyString)")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [API] Invalid response (not HTTP)")
                throw APIError.invalidResponse
            }
            
            print("🔵 [API] Response status: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("🔵 [API] Response body: \(responseString)")
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("❌ [API] Error status code: \(httpResponse.statusCode)")
                throw APIError.serverError(httpResponse.statusCode)
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let library = try decoder.decode(LibraryModel.self, from: data)
            print("✅ [API] Library created: \(library.name) (ID: \(library.id))")
            return library
        } catch {
            print("❌ [API] Error: \(error)")
            throw error
        }
    }
    
    /// Delete a library
    func deleteLibrary(libraryId: UUID) async throws {
        let url = URL(string: "\(baseURL)/api/libraries/\(libraryId.uuidString)")!
        let request = createRequest(url: url, method: "DELETE")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        // 204 No Content is the expected success response
        guard httpResponse.statusCode == 204 || (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
    }
    
    /// Get libraries by owner
    func getLibrariesByOwner(_ owner: String) async throws -> [LibraryModel] {
        let encodedOwner = owner.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? owner
        let url = URL(string: "\(baseURL)/api/libraries/owner/\(encodedOwner)")!
        
        print("🔵 [API] getLibrariesByOwner called")
        print("🔵 [API] Owner: \(owner)")
        print("🔵 [API] URL: \(url)")
        print("🔵 [API] Auth token present: \(authToken != nil)")
        
        let request = createRequest(url: url)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [API] Invalid response (not HTTP)")
                throw APIError.invalidResponse
            }
            
            print("🔵 [API] Response status: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("🔵 [API] Response body: \(responseString)")
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("❌ [API] Error status code: \(httpResponse.statusCode)")
                throw APIError.serverError(httpResponse.statusCode)
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let libraries = try decoder.decode([LibraryModel].self, from: data)
            print("✅ [API] Loaded \(libraries.count) libraries")
            return libraries
        } catch {
            print("❌ [API] Error loading libraries: \(error)")
            throw error
        }
    }
    
    /// Get vocabulary hints for speech recognition based on user's library content
    func getVocabularyHints(forOwner owner: String, booksOnly: Bool = false) async throws -> VocabularyHintsResponse {
        let encodedOwner = owner.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? owner
        var urlComponents = URLComponents(string: "\(baseURL)/api/libraries/owner/\(encodedOwner)/vocabulary-hints")!
        
        if booksOnly {
            urlComponents.queryItems = [URLQueryItem(name: "booksOnly", value: "true")]
        }
        
        guard let url = urlComponents.url else {
            throw APIError.invalidResponse
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
        
        return try JSONDecoder().decode(VocabularyHintsResponse.self, from: data)
    }
    
    /// Get books in a library
    func getBooksInLibrary(libraryId: UUID) async throws -> [Book] {
        let url = URL(string: "\(baseURL)/api/libraries/\(libraryId.uuidString)/books")!
        
        let request = createRequest(url: url)
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let bookResponses = try decoder.decode([BookResponse].self, from: data)
        return bookResponses.map { $0.toBook() }
    }
    
    /// Add books to a library
    func addBooksToLibrary(libraryId: UUID, bookIds: [UUID]) async throws {
        let url = URL(string: "\(baseURL)/api/libraries/\(libraryId.uuidString)/books")!
        
        var request = createRequest(url: url, method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Create properly structured request matching backend expectations
        struct AddBooksRequest: Codable {
            let bookIds: [UUID]
        }
        let requestBody = AddBooksRequest(bookIds: bookIds)
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
    }
    
    /// Remove books from a library
    func removeBooksFromLibrary(libraryId: UUID, bookIds: [UUID]) async throws {
        let url = URL(string: "\(baseURL)/api/libraries/\(libraryId.uuidString)/books")!
        
        var request = createRequest(url: url, method: "DELETE")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        struct RemoveBooksRequest: Codable {
            let bookIds: [UUID]
        }
        let requestBody = RemoveBooksRequest(bookIds: bookIds)
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
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

extension BookApiService {
    // MARK: - Quote Verification
    
    /// Verify a quote and its attribution
    /// - Parameter request: Quote verification request with text, author, and input method
    /// - Returns: Verification result with confidence score and possible sources
    func verifyQuote(_ request: QuoteVerificationRequest) async throws -> QuoteVerificationResponse {
        let url = URL(string: "\(baseURL)/api/quotes/verify")!
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        await MainActor.run { isLoading = true }
        defer { Task { await MainActor.run { isLoading = false } } }
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        return try decoder.decode(QuoteVerificationResponse.self, from: data)
    }
}
