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
    /// - Parameter baseURL: The API base URL (default: localhost for development)
    init(baseURL: String = "http://localhost:5000") {
        self.baseURL = baseURL
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
    
    /// Search for books by cover text (OCR results)
    /// - Parameter extractedText: Text extracted from the book cover
    /// - Returns: List of potential book matches
    func searchByCover(_ extractedText: String) async throws -> [Book] {
        let url = URL(string: "\(baseURL)/api/books/search-by-cover")!
        
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
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw APIError.serverError(httpResponse.statusCode)
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
