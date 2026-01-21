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
        
        // Step 2: Clean and prepare search query
        let searchQuery = cleanTextForSearch(text)
        print("🔍 Cleaned search query: \(searchQuery)")
        
        // Step 3: Search for books using the cleaned text
        do {
            let books = try await apiService.searchByCover(searchQuery)
            searchResults = books
            
            if books.isEmpty {
                error = "No books found matching the cover text"
            }
        } catch {
            self.error = error.localizedDescription
        }
        
        isProcessing = false
    }
    
    /// Clean extracted OCR text to create a better search query
    /// Removes common non-essential words and focuses on title and author
    private func cleanTextForSearch(_ text: String) -> String {
        // Split into lines and clean each
        var lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        // Words to filter out (common book cover text that's not the title/author)
        let filterWords = ["novela", "novel", "traducción", "translation", 
                          "prólogo", "prologue", "edición", "edition",
                          "introducción", "introduction", "ensayo", "essay"]
        
        // Filter out lines that are just noise words or very short
        lines = lines.filter { line in
            let lowercased = line.lowercased()
            // Keep lines that are substantial (longer than 3 chars) and not just filter words
            if line.count <= 3 { return false }
            for filterWord in filterWords {
                if lowercased == filterWord || lowercased.hasPrefix(filterWord + " ") || lowercased.hasSuffix(" " + filterWord) {
                    return false
                }
            }
            return true
        }
        
        // Look for capitalized names (likely author or title)
        let capitalizedLines = lines.filter { line in
            // Check if line has multiple capital letters (suggests proper nouns)
            let capitals = line.filter { $0.isUppercase }.count
            return capitals >= 2
        }
        
        // Prioritize capitalized content, take first 2-3 lines
        let searchLines: [String]
        if !capitalizedLines.isEmpty {
            searchLines = Array(capitalizedLines.prefix(3))
        } else {
            searchLines = Array(lines.prefix(3))
        }
        
        // Remove common separators and clean up
        let searchQuery = searchLines.joined(separator: " ")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespaces)
        
        // If we got nothing useful, fall back to original first few lines
        if searchQuery.isEmpty {
            return lines.prefix(2).joined(separator: " ")
        }
        
        return searchQuery
    }
    
    /// Reset the view model state
    func reset() {
        searchResults = []
        extractedText = nil
        error = nil
        isProcessing = false
    }
}
