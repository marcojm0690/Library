import Foundation
import UIKit

class APIService: ObservableObject {
    private let baseURL: String
    
    init(baseURL: String = "https://localhost:5001/api") {
        self.baseURL = baseURL
    }
    
    // MARK: - Book Lookup by ISBN
    
    func lookupBook(isbn: String) async throws -> Book? {
        let url = URL(string: "\(baseURL)/books/lookup")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = BookLookupRequest(isbn: isbn)
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        let lookupResponse = try decoder.decode(BookLookupResponse.self, from: data)
        
        if lookupResponse.success {
            return lookupResponse.book
        } else {
            throw APIError.bookNotFound(message: lookupResponse.message)
        }
    }
    
    // MARK: - Search by Cover Image
    
    func searchByCover(image: UIImage) async throws -> [Book] {
        let url = URL(string: "\(baseURL)/books/search-by-cover")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Convert image to base64
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw APIError.imageConversionFailed
        }
        
        let base64String = imageData.base64EncodedString()
        
        let requestBody = SearchByCoverRequest(imageBase64: base64String)
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        let searchResponse = try decoder.decode(SearchByCoverResponse.self, from: data)
        
        if searchResponse.success {
            return searchResponse.books
        } else {
            throw APIError.searchFailed(message: searchResponse.message)
        }
    }
    
    // MARK: - Error Types
    
    enum APIError: Error, LocalizedError {
        case invalidResponse
        case serverError(statusCode: Int)
        case bookNotFound(message: String)
        case searchFailed(message: String)
        case imageConversionFailed
        
        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "Invalid response from server"
            case .serverError(let statusCode):
                return "Server error: \(statusCode)"
            case .bookNotFound(let message):
                return message
            case .searchFailed(let message):
                return message
            case .imageConversionFailed:
                return "Failed to convert image"
            }
        }
    }
}
