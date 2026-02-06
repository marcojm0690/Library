import SwiftUI

/// ViewModel for library detail view
@MainActor
class LibraryDetailViewModel: ObservableObject {
    @Published var books: [Book] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private let libraryId: UUID
    private let apiService: BookApiService
    private var loadTask: Task<Void, Never>?  // Track the task to prevent cancellation
    
    init(libraryId: UUID, apiService: BookApiService = BookApiService.shared) {
        self.libraryId = libraryId
        self.apiService = apiService
    }
    
    /// Load books in the library
    func loadBooks() async {
        // Cancel any existing load task
        loadTask?.cancel()
        
        loadTask = Task {
            isLoading = true
            error = nil
            
            do {
                books = try await apiService.getBooksInLibrary(libraryId: libraryId)
            } catch {
                self.error = error.localizedDescription
            }
            
            isLoading = false
        }
        
        await loadTask?.value
    }
    
    /// Refresh books
    func refresh() async {
        await loadBooks()
    }
    
    /// Remove a book from the library
    func removeBook(bookId: UUID) async throws {
        do {
            try await apiService.removeBooksFromLibrary(libraryId: libraryId, bookIds: [bookId])
            // Remove from local array on success
            books.removeAll { $0.id == bookId }
        } catch {
            throw error
        }
    }
}
