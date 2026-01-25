import Foundation
import SwiftUI

/// ViewModel for voice-based book search
/// Orchestrates speech recognition, API search, and result management
@MainActor
class VoiceSearchViewModel: ObservableObject {
    
    // MARK: - Search State
    
    enum SearchState {
        case idle
        case listening
        case processing
        case results([Book])
        case error(String)
        
        var isActive: Bool {
            switch self {
            case .idle, .error:
                return false
            case .listening, .processing, .results:
                return true
            }
        }
    }
    
    // MARK: - Published Properties
    
    @Published var searchState: SearchState = .idle
    @Published var transcribedText: String = ""
    @Published var selectedBook: Book?
    
    // MARK: - Dependencies
    
    private let speechService: SpeechRecognitionService
    private let apiService: BookApiService
    
    // MARK: - Initialization
    
    init(
        speechService: SpeechRecognitionService? = nil,
        apiService: BookApiService? = nil
    ) {
        // Construct defaults on the main actor to avoid calling actor-isolated initializers
        // from a nonisolated default parameter context.
        self.speechService = speechService ?? SpeechRecognitionService()
        self.apiService = apiService ?? BookApiService()
    }
    
    // MARK: - Voice Search Flow
    
    /// Start listening for voice input
    func startVoiceSearch() {
        guard speechService.isAvailable else {
            searchState = .error("Speech recognition is not available. Please check permissions in Settings.")
            return
        }
        
        // Reset state
        transcribedText = ""
        searchState = .listening
        
        print("🎤 Starting voice search...")
        
        // Start listening with timeout
        speechService.startListening { [weak self] result in
            guard let self = self else { return }
            
            Task { @MainActor in
                switch result {
                case .success(let text):
                    print("✅ Voice input received: \(text)")
                    self.transcribedText = text
                    
                    // Automatically search when speech ends
                    if !text.isEmpty {
                        await self.searchBooks(query: text)
                    } else {
                        self.searchState = .error("No speech detected. Please try again.")
                    }
                    
                case .failure(let error):
                    print("❌ Speech recognition failed: \(error)")
                    self.searchState = .error("Speech recognition failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Stop listening manually
    func stopListening() {
        print("🛑 Stopping voice search manually...")
        speechService.stopListening()
        
        // Search with current transcription if available
        if !transcribedText.isEmpty {
            Task {
                await searchBooks(query: transcribedText)
            }
        } else {
            searchState = .idle
        }
    }
    
    /// Cancel voice search
    func cancelVoiceSearch() {
        print("❌ Cancelling voice search...")
        speechService.cancelListening()
        searchState = .idle
        transcribedText = ""
    }
    
    // MARK: - Book Search
    
    /// Search for books using the transcribed text
    /// - Parameter query: The book title/author from voice input
    private func searchBooks(query: String) async {
        searchState = .processing
        
        print("🔍 Searching for books with query: \(query)")
        
        do {
            // Use the existing search-by-cover endpoint (it accepts any text, not just OCR)
            let books = try await apiService.searchByCover(query)
            
            if books.isEmpty {
                searchState = .error("No books found for '\(query)'. Try being more specific.")
                print("⚠️ No results found")
            } else {
                searchState = .results(books)
                print("✅ Found \(books.count) books")
            }
            
        } catch {
            print("❌ Search failed: \(error)")
            searchState = .error("Search failed: \(error.localizedDescription)")
        }
    }
    
    /// Manually trigger search with text (for testing or manual input)
    func searchWithText(_ text: String) async {
        transcribedText = text
        await searchBooks(query: text)
    }
    
    // MARK: - Add to Library
    
    /// Add a book to the specified library
    /// - Parameters:
    ///   - book: The book to add
    ///   - libraryId: The library ID to add the book to
    func addBookToLibrary(_ book: Book, libraryId: UUID) async throws {
        print("➕ Adding book to library: \(book.title)")
        
        do {
            // Save the book to the database
            let savedBook = try await apiService.saveBook(book)
            
            guard savedBook.id != nil else {
                throw NSError(
                    domain: "VoiceSearch",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to save book - no ID returned"]
                )
            }
            
            print("✅ Book added successfully to library \(libraryId)")
            
        } catch {
            print("❌ Failed to add book: \(error)")
            throw error
        }
    }
    
    // MARK: - State Management
    
    /// Reset to idle state
    func reset() {
        searchState = .idle
        transcribedText = ""
        selectedBook = nil
    }
    
    /// Get current search results
    var searchResults: [Book] {
        if case .results(let books) = searchState {
            return books
        }
        return []
    }
    
    /// Check if currently listening
    var isListening: Bool {
        if case .listening = searchState {
            return true
        }
        return false
    }
    
    /// Check if processing search
    var isProcessing: Bool {
        if case .processing = searchState {
            return true
        }
        return false
    }
    
    /// Get error message if in error state
    var errorMessage: String? {
        if case .error(let message) = searchState {
            return message
        }
        return nil
    }
}
