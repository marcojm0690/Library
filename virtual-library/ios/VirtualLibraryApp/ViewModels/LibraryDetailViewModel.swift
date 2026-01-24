import SwiftUI

/// ViewModel for library detail view
@MainActor
class LibraryDetailViewModel: ObservableObject {
    @Published var books: [Book] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private let libraryId: UUID
    private let apiService: BookApiService
    
    init(libraryId: UUID, apiService: BookApiService = BookApiService()) {
        self.libraryId = libraryId
        self.apiService = apiService
    }
    
    /// Load books in the library
    func loadBooks() async {
        isLoading = true
        error = nil
        
        do {
            books = try await apiService.getBooksInLibrary(libraryId: libraryId)
            print("✅ Loaded \(books.count) books for library: \(libraryId.uuidString)")
        } catch {
            self.error = error.localizedDescription
            print("❌ Failed to load books: \(error)")
        }
        
        isLoading = false
    }
    
    /// Refresh books
    func refresh() async {
        await loadBooks()
    }
}
