import SwiftUI
import AVFoundation

@MainActor
class MultiBookScanViewModel: ObservableObject {
    @Published var detectedBooks: [DetectedBook] = []
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var rectangleOverlays: [(rect: CGRect, hasBook: Bool)] = []
    
    private let cameraManager = CameraSessionManager()
    private let detectionService: MultiBookDetectionService
    private var lastProcessTime: Date = .distantPast
    private let processingInterval: TimeInterval = 2.0 // Process every 2 seconds
    
    init(apiService: BookApiService) {
        self.detectionService = MultiBookDetectionService(apiService: apiService)
        setupCamera()
    }
    
    private func setupCamera() {
        cameraManager.onFrameCaptured = { [weak self] pixelBuffer in
            Task { @MainActor in
                await self?.processFrame(pixelBuffer)
            }
        }
    }
    
    func startScanning() {
        cameraManager.startSession()
    }
    
    func stopScanning() {
        cameraManager.stopSession()
    }
    
    func getCameraSession() -> AVCaptureSession {
        return cameraManager.session
    }
    
    private func processFrame(_ pixelBuffer: CVPixelBuffer) async {
        // Throttle processing
        guard Date().timeIntervalSince(lastProcessTime) >= processingInterval else { return }
        guard !isProcessing else { return }
        
        isProcessing = true
        lastProcessTime = Date()
        
        let newDetections = await detectionService.detectBooks(in: pixelBuffer)
        
        // Update rectangles with their status
        var overlays: [(rect: CGRect, hasBook: Bool)] = []
        var updatedBooks = detectedBooks // Start with existing books
        
        for detection in newDetections {
            // Check if we already have this rectangle confirmed (by text similarity)
            if let existingBook = detectedBooks.first(where: { 
                $0.isConfirmed && similarity(between: $0.detectedText, and: detection.detectedText) > 0.7 
            }) {
                // Already confirmed - keep showing green rectangle and don't re-fetch
                overlays.append((rect: detection.boundingBox, hasBook: true))
                continue
            }
            
            // Check if we're already fetching this detection
            if let existingUnconfirmed = detectedBooks.first(where: {
                !$0.isConfirmed && similarity(between: $0.detectedText, and: detection.detectedText) > 0.7
            }) {
                // Already processing - show red while waiting
                overlays.append((rect: detection.boundingBox, hasBook: false))
                continue
            }
            
            // New detection - fetch details
            overlays.append((rect: detection.boundingBox, hasBook: false))
            let books = await detectionService.fetchBookDetails(for: detection)
            
            if !books.isEmpty {
                // Create a DetectedBook for each result
                for book in books {
                    var confirmedDetection = detection
                    confirmedDetection.book = book
                    confirmedDetection.isConfirmed = true
                    updatedBooks.append(confirmedDetection)
                }
                
                // Update overlay to green for this rectangle
                if let index = overlays.firstIndex(where: { $0.rect == detection.boundingBox }) {
                    overlays[index] = (rect: detection.boundingBox, hasBook: true)
                }
            }
        }
        
        detectedBooks = updatedBooks
        rectangleOverlays = overlays
        isProcessing = false
    }
    
    func removeDetection(_ detectedBook: DetectedBook) {
        detectedBooks.removeAll { $0.id == detectedBook.id }
    }
    
    func addBookToLibrary(_ detectedBook: DetectedBook, libraryId: UUID) async {
        guard let book = detectedBook.book else { 
            errorMessage = "Book details not available"
            return 
        }
        
        guard let bookId = book.id else {
            errorMessage = "ID del libro no disponible"
            return
        }
        
        do {
            try await detectionService.apiService.addBooksToLibrary(libraryId: libraryId, bookIds: [bookId])
            // Remove from detected books after adding
            detectedBooks.removeAll { $0.id == detectedBook.id }
        } catch {
            errorMessage = "Error al agregar el libro: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Helper Methods
    
    private func similarity(between text1: String, and text2: String) -> Double {
        let set1 = Set(text1.lowercased().split(separator: " "))
        let set2 = Set(text2.lowercased().split(separator: " "))
        let intersection = set1.intersection(set2).count
        let union = set1.union(set2).count
        return union > 0 ? Double(intersection) / Double(union) : 0
    }
}
