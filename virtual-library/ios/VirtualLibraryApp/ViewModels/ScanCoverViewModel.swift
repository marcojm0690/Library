import Foundation
import UIKit

/// ViewModel for cover scanning and book search.
/// Coordinates between OCRService and BookApiService.
@MainActor
class ScanCoverViewModel: ObservableObject {
    @Published var searchResults: [Book] = []
    @Published var extractedText: String?
    @Published var isProcessing = false
    @Published var error: String?
    
    private let apiService: BookApiService
    private let ocrService: OCRService
    
    init(apiService: BookApiService = BookApiService(), ocrService: OCRService = OCRService()) {
        self.apiService = apiService
        self.ocrService = ocrService
    }
    
    /// Process an image: extract text via OCR and search for books
    /// - Parameter image: The cover image to process
    func processImage(_ image: UIImage) async {
        isProcessing = true
        error = nil
        extractedText = nil
        searchResults = []
        
        // Step 1: Extract text from image using OCR
        guard let text = await ocrService.extractText(from: image) else {
            error = "Failed to extract text from image"
            isProcessing = false
            return
        }
        
        extractedText = text
        
        // Step 2: Search for books using the extracted text
        do {
            let books = try await apiService.searchByCover(text)
            searchResults = books
            
            if books.isEmpty {
                error = "No books found matching the cover text"
            }
        } catch {
            self.error = error.localizedDescription
        }
        
        isProcessing = false
    }
    
    /// Reset the view model state
    func reset() {
        searchResults = []
        extractedText = nil
        error = nil
        isProcessing = false
    }
}
