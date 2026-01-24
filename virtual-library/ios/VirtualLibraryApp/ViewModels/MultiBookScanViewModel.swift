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
    private let maxDetectedBooks = 3 // Limit to reduce API calls
    private var ignoredTexts: Set<String> = [] // Track books that have been added to ignore them
    private var scanMode: ScanMode = .imageBased
    
    init(apiService: BookApiService) {
        self.detectionService = MultiBookDetectionService(apiService: apiService)
        setupCamera()
    }
    
    func setScanMode(_ mode: ScanMode) {
        scanMode = mode
        detectionService.setScanMode(mode)
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
            // Check if this book was already added and should be ignored
            if ignoredTexts.contains(where: { similarity(between: $0, and: detection.detectedText) > 0.7 }) {
                // Skip this detection - book was already added
                continue
            }
            
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
            
            // Check if we've reached the max limit
            let confirmedCount = updatedBooks.filter { $0.isConfirmed }.count
            guard confirmedCount < maxDetectedBooks else {
                // Don't fetch more books if we've reached the limit
                continue
            }
            
            // New detection - fetch details
            overlays.append((rect: detection.boundingBox, hasBook: false))
            print("🔍 [ViewModel] Fetching book details for detection: \(detection.id)")
            print("   Detection text: '\(detection.detectedText)'")
            print("   Has cover image: \(detection.coverImage != nil)")
            
            let books = await detectionService.fetchBookDetails(for: detection)
            
            print("📚 [ViewModel] Received \(books.count) books from API")
            if !books.isEmpty {
                let bestMatch = books.first!
                print("✅ [ViewModel] Best match: '\(bestMatch.title)' by \(bestMatch.authors.joined(separator: ", "))")
                print("   Book details - ID: \(bestMatch.id?.uuidString ?? "nil"), ISBN: \(bestMatch.isbn ?? "nil")")
                print("   Cover URL: \(bestMatch.coverImageUrl ?? "nil")")
                print("   Source: \(bestMatch.source ?? "nil")")
                
                // Only take the first (best match) book to avoid cluttering UI
                var confirmedDetection = detection
                confirmedDetection.book = bestMatch
                confirmedDetection.isConfirmed = true
                updatedBooks.append(confirmedDetection)
                
                print("✅ [ViewModel] Added confirmed detection with book to list")
                
                // Update overlay to green for this rectangle
                if let index = overlays.firstIndex(where: { $0.rect == detection.boundingBox }) {
                    overlays[index] = (rect: detection.boundingBox, hasBook: true)
                }
            } else {
                print("⚠️ [ViewModel] No books found for this detection")
            }
        }
        
        detectedBooks = updatedBooks
        rectangleOverlays = overlays
        isProcessing = false
    }
    
    func removeDetection(_ detectedBook: DetectedBook) {
        // Just remove from list - does NOT add to ignored list
        // This allows the same book to be detected again if user wants
        detectedBooks.removeAll { $0.id == detectedBook.id }
        
        // Also remove its overlay
        rectangleOverlays.removeAll { overlay in
            overlay.rect == detectedBook.boundingBox
        }
        
        print("🗑️ Removed detection - book can be scanned again")
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
            
            // Add to ignored texts so we don't detect this book again
            ignoredTexts.insert(detectedBook.detectedText)
            
            // Remove from detected books and overlays
            detectedBooks.removeAll { $0.id == detectedBook.id }
            
            // Remove the overlay for this specific book
            rectangleOverlays.removeAll { overlay in
                // Check if overlay matches this detection's bounding box
                overlay.rect == detectedBook.boundingBox
            }
            
            print("✅ Book added and ignored for future scans")
        } catch {
            errorMessage = "Error al agregar el libro: \(error.localizedDescription)"
        }
    }
    
    func clearIgnoredBooks() {
        // Reset ignored books list (useful when restarting scan session)
        ignoredTexts.removeAll()
        print("🔄 Cleared ignored books list")
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
