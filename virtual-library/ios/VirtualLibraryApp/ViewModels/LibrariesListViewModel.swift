import SwiftUI

/// ViewModel for libraries list
@MainActor
class LibrariesListViewModel: ObservableObject {
    @Published var libraries: [LibraryModel] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private let apiService: BookApiService
    
    init(apiService: BookApiService = BookApiService()) {
        self.apiService = apiService
    }
    
    /// Load libraries for the current user
    func loadLibraries(for userId: String) async {
        isLoading = true
        error = nil
        
        do {
            libraries = try await apiService.getLibrariesByOwner(userId)
            print("✅ Loaded \(libraries.count) libraries for user: \(userId)")
        } catch let urlError as URLError where urlError.code == .cancelled {
            // Request was cancelled (view dismissed), ignore
            print("ℹ️ Library load cancelled")
        } catch {
            self.error = error.localizedDescription
            print("❌ Failed to load libraries: \(error)")
        }
        
        isLoading = false
    }
    
    /// Refresh libraries
    func refresh(for userId: String) async {
        await loadLibraries(for: userId)
    }
}
