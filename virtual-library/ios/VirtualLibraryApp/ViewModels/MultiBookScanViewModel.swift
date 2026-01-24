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
        var updatedBooks: [DetectedBook] = []
        
        for detection in newDetections {
            // Check if we already have this book (by text similarity)
            if let existingBook = detectedBooks.first(where: { 
                similarity(between: $0.detectedText, and: detection.detectedText) > 0.7 
            }) {
                updatedBooks.append(existingBook)
                overlays.append((rect: detection.boundingBox, hasBook: existingBook.book != nil))
            } else {
                // Fetch details for new detection
                if let book = await detectionService.fetchBookDetails(for: detection) {
                    var updatedDetection = detection
                    updatedDetection.book = book
                    updatedBooks.append(updatedDetection)
                    overlays.append((rect: detection.boundingBox, hasBook: true))
                } else {
                    updatedBooks.append(detection)
                    overlays.append((rect: detection.boundingBox, hasBook: false))
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
            errorMessage = "Book ID not available"
            return
        }
        
        do {
            try await detectionService.apiService.addBooksToLibrary(libraryId: libraryId, bookIds: [bookId])
            // Remove from detected books after adding
            detectedBooks.removeAll { $0.id == detectedBook.id }
        } catch {
            errorMessage = "Failed to add book: \(error.localizedDescription)"
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
