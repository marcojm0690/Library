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
    
    // MARK: - Properties
    
    var userId: String?
    
    // MARK: - Dependencies
    
    let speechService: SpeechRecognitionService
    private let apiService: BookApiService
    
    // Current vocabulary hints
    private var currentVocabularyHints: [String] = []
    
    // MARK: - Initialization
    
    init(
        userId: String? = nil,
        speechService: SpeechRecognitionService? = nil,
        apiService: BookApiService? = nil
    ) {
        self.userId = userId
        // Construct defaults on the main actor to avoid calling actor-isolated initializers
        // from a nonisolated default parameter context.
        self.speechService = speechService ?? SpeechRecognitionService()
        self.apiService = apiService ?? BookApiService.shared
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
        
        Task {
            print("🎤 Starting voice search...")
            
            // Load vocabulary hints before starting speech recognition
            await loadVocabularyHints()
            
            // Start observing speech service transcription updates in real-time
            startObservingSpeechUpdates()
            
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
    }
    
    /// Observe real-time updates from speech service and sync to viewModel
    private func startObservingSpeechUpdates() {
        Task {
            // Continuously monitor speechService.transcribedText changes
            for await _ in NotificationCenter.default.notifications(named: .speechTranscriptionUpdated) {
                await MainActor.run {
                    if speechService.isListening {
                        self.transcribedText = speechService.transcribedText
                    }
                }
            }
        }
    }
    
    /// Load vocabulary hints from the user's library to improve speech recognition
    /// Uses contextualStrings - Apple's ML already handles phonetic variations
    private func loadVocabularyHints() async {
        // Get user ID from property or fallback to UserDefaults
        let userId = self.userId ?? UserDefaults.standard.string(forKey: "currentUserId")
        
        guard let userId = userId else {
            print("⚠️ No user ID found, using default vocabulary")
            return
        }
        
        do {
            let hints = try await apiService.getVocabularyHints(forOwner: userId, booksOnly: true)
            
            print("📚 Loaded \(hints.hints.count) vocabulary hints (books only)")
            print("📚 Personalized: \(hints.isPersonalized)")
            print("📚 Sample hints: \(hints.hints.prefix(10).joined(separator: ", "))")
            
            // Check for specific author
            if hints.hints.contains(where: { $0.lowercased().contains("kant") }) {
                print("   ✅ Found 'Kant' in API response")
            } else {
                print("   ⚠️ 'Kant' NOT in API response - check backend")
            }
            
            // Store hints
            currentVocabularyHints = hints.hints
            
            // Prioritize author names (single and multi-word) and limit to most important hints
            // Speech recognition works better with focused, high-quality hints (max 100-200)
            let optimizedHints = optimizeHintsForSpeech(hints.hints)
            
            print("📚 Optimized to \(optimizedHints.count) high-priority hints for speech recognition")
            
            // Set vocabulary hints using contextualStrings
            await MainActor.run {
                speechService.vocabularyHints = optimizedHints
            }
            
            print("✅ Vocabulary hints loaded for improved recognition")
            
        } catch {
            print("⚠️ Failed to load vocabulary hints: \(error)")
            print("⚠️ Continuing without personalized vocabulary")
            // Continue without vocabulary hints - it's not critical
        }
    }
    
    /// Optimize hints for speech recognition - prioritize likely search terms
    private func optimizeHintsForSpeech(_ allHints: [String]) -> [String] {
        var prioritized: [String] = []
        var secondary: [String] = []
        
        for hint in allHints {
            let wordCount = hint.split(separator: " ").count
            
            // Priority 1: Author names (1-3 words, likely names)
            if wordCount >= 1 && wordCount <= 3 && hint.contains(where: { $0.isUppercase }) {
                prioritized.append(hint)
            }
            // Priority 2: Short phrases (titles, subjects)
            else if wordCount >= 1 && wordCount <= 4 {
                secondary.append(hint)
            }
        }
        
        // Limit to top 100 prioritized + 50 secondary (Apple recommends keeping it small)
        let result = Array(prioritized.prefix(100)) + Array(secondary.prefix(50))
        return result
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
            
            guard let bookId = savedBook.id else {
                throw NSError(
                    domain: "VoiceSearch",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to save book - no ID returned"]
                )
            }
            
            // Add the book to the library
            try await apiService.addBooksToLibrary(libraryId: libraryId, bookIds: [bookId])
            
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
    
    // MARK: - Dynamic Vocabulary
    
    /// Load book titles and author names from the library to improve speech recognition
    private func loadLibraryVocabulary() async {
        var hints: [String] = []
        
        // Fetch all libraries to get books
        do {
            let libraries = try await apiService.getAllLibraries()
            
            for library in libraries {
                // Get books in each library
                if let books = try? await apiService.getBooksInLibrary(libraryId: library.id) {
                    for book in books {
                        // Add book title
                        hints.append(book.title)
                        
                        // Add author names
                        for author in book.authors {
                            hints.append(author)
                        }
                        
                        // Add title + author combo for better recognition
                        if let firstAuthor = book.authors.first {
                            hints.append("\(book.title) by \(firstAuthor)")
                        }
                    }
                }
            }
            
            // Set the vocabulary hints
            await MainActor.run {
                speechService.vocabularyHints = hints
                print("📚 Loaded \(hints.count) vocabulary hints from library")
            }
        } catch {
            print("⚠️ Could not load library vocabulary: \(error)")
            // Continue without custom hints
        }
    }
}
