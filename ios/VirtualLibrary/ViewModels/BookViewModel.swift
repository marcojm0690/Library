import Foundation
import SwiftUI
import Combine

@MainActor
class BookViewModel: ObservableObject {
    @Published var books: [Book] = []
    @Published var currentBook: Book?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService: APIService
    private let barcodeScannerService: BarcodeScannerService
    private let ocrService: OCRService
    
    private var cancellables = Set<AnyCancellable>()
    
    init(apiService: APIService = APIService(),
         barcodeScannerService: BarcodeScannerService = BarcodeScannerService(),
         ocrService: OCRService = OCRService()) {
        self.apiService = apiService
        self.barcodeScannerService = barcodeScannerService
        self.ocrService = ocrService
        
        setupBindings()
    }
    
    private func setupBindings() {
        // Listen to scanned barcode
        barcodeScannerService.$scannedCode
            .compactMap { $0 }
            .sink { [weak self] isbn in
                Task {
                    await self?.lookupBook(isbn: isbn)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Book Lookup
    
    func lookupBook(isbn: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            if let book = try await apiService.lookupBook(isbn: isbn) {
                currentBook = book
                if !books.contains(where: { $0.isbn == book.isbn }) {
                    books.append(book)
                }
            } else {
                errorMessage = "Book not found"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Search by Cover
    
    func searchByCover(image: UIImage) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // First, try OCR to extract text from the image
            let ocrText = try await ocrService.recognizeText(from: image)
            print("OCR Text: \(ocrText)")
            
            // Then search using the cover image
            let foundBooks = try await apiService.searchByCover(image: image)
            books = foundBooks
            
            if foundBooks.isEmpty {
                errorMessage = "No books found"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Barcode Scanner Access
    
    var scanner: BarcodeScannerService {
        barcodeScannerService
    }
}
