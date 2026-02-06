import SwiftUI

/// ViewModel for libraries list
@MainActor
class LibrariesListViewModel: ObservableObject {
    @Published var libraries: [LibraryModel] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private let apiService: BookApiService
    
    init(apiService: BookApiService = BookApiService.shared) {
        self.apiService = apiService
    }
    
    /// Set the authentication token for API requests (optional if using shared service)
    func setAuthToken(_ token: String?) {
        apiService.authToken = token
    }
    
    /// Load libraries for the current user
    func loadLibraries(for userId: String) async {
        print("🔵 [LibrariesListViewModel] loadLibraries called for: \(userId)")
        
        isLoading = true
        error = nil
        
        do {
            let result = try await apiService.getLibrariesByOwner(userId)
            print("🔵 [LibrariesListViewModel] Got \(result.count) libraries, updating UI")
            libraries = result
            print("🔵 [LibrariesListViewModel] libraries array now has \(libraries.count) items")
        } catch let urlError as URLError where urlError.code == .cancelled {
            // Request was cancelled (view dismissed), ignore
            print("🔵 [LibrariesListViewModel] URL request cancelled")
        } catch {
            print("❌ [LibrariesListViewModel] Error: \(error)")
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    /// Refresh libraries
    func refresh(for userId: String) async {
        await loadLibraries(for: userId)
    }
    
    /// Delete a library
    func deleteLibrary(_ library: LibraryModel) async throws {
        do {
            try await apiService.deleteLibrary(libraryId: library.id)
            // Remove from local array on success
            libraries.removeAll { $0.id == library.id }
        } catch {
            throw error
        }
    }
}
