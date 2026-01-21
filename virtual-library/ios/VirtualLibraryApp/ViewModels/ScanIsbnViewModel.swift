import Foundation

/// ViewModel for ISBN scanning and book lookup.
/// Coordinates between CameraService and BookApiService.
@MainActor
class ScanIsbnViewModel: ObservableObject {
    @Published var scannedBook: Book?
    @Published var isScanning = false
    @Published var error: String?
    @Published var isLoading = false
    
    private let apiService: BookApiService
    
    init(apiService: BookApiService = BookApiService()) {
        self.apiService = apiService
    }
    
    /// Start scanning for ISBN barcode
    func startScanning() {
        isScanning = true
        error = nil
    }
    
    /// Stop scanning
    func stopScanning() {
        isScanning = false
    }
    
    /// Look up book by ISBN
    /// - Parameter isbn: The ISBN to search for
    func lookupBook(isbn: String) async {
        isLoading = true
        error = nil
        stopScanning() // Stop camera when looking up
        
        do {
            let book = try await apiService.lookupByIsbn(isbn)
            
            if let book = book {
                scannedBook = book
            } else {
                error = "Book not found for ISBN: \(isbn)"
            }
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    /// Reset the view model state
    func reset() {
        scannedBook = nil
        error = nil
        isLoading = false
        isScanning = false
    }
}
