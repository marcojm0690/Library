import Foundation

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
    
    /// Search for books by cover text (OCR results)
    /// - Parameter extractedText: Text extracted from the book cover
    /// - Returns: List of potential book matches
    func searchByCover(_ extractedText: String) async throws -> [Book] {
        let url = URL(string: "\(baseURL)/api/books/search-by-cover")!
        
        print("📡 API Request: POST \(url)")
        print("📦 Extracted Text: \(extractedText)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = SearchByCoverRequest(extractedText: extractedText, imageData: nil)
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
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw APIError.serverError(httpResponse.statusCode)
            }
            
            let searchResponse = try JSONDecoder().decode(SearchBooksResponse.self, from: data)
            print("✅ Found \(searchResponse.books.count) books")
            return searchResponse.books.map { $0.toBook() }
            
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
    
    // MARK: - Library Management
    
    /// Get all libraries
    func getAllLibraries() async throws -> [Library] {
        let url = URL(string: "\(baseURL)/api/libraries")!
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Library].self, from: data)
    }
    
    /// Create a new library
    func createLibrary(_ request: CreateLibraryRequest) async throws -> Library {
        let url = URL(string: "\(baseURL)/api/libraries")!
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Library.self, from: data)
    }
    
    /// Get libraries by owner
    func getLibrariesByOwner(_ owner: String) async throws -> [Library] {
        let encodedOwner = owner.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? owner
        let url = URL(string: "\(baseURL)/api/libraries/owner/\(encodedOwner)")!
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Library].self, from: data)
    }
    
    /// Add books to a library
    func addBooksToLibrary(libraryId: UUID, bookIds: [UUID]) async throws {
        let url = URL(string: "\(baseURL)/api/libraries/\(libraryId.uuidString)/books")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = ["bookIds": bookIds.map { $0.uuidString }]
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
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
