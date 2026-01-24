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
    private var lastDetectionTime: Date = .distantPast
    private let detectionPersistDuration: TimeInterval = 30.0 // Keep detections for 30 seconds
    
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
        
        // Clear previous detections only if enough time has passed since last detection
        let timeSinceLastDetection = Date().timeIntervalSince(lastDetectionTime)
        if !newDetections.isEmpty && timeSinceLastDetection > detectionPersistDuration {
            print("🧹 [ViewModel] Clearing previous detections - \(String(format: "%.1f", timeSinceLastDetection))s elapsed")
            detectedBooks.removeAll()
            ignoredTexts.removeAll()
            lastDetectionTime = Date()
        } else if !newDetections.isEmpty && !detectedBooks.isEmpty {
            // If we have existing detections and time hasn't elapsed, keep them
            print("⏰ [ViewModel] Keeping existing detections - only \(String(format: "%.1f", timeSinceLastDetection))s elapsed")
            isProcessing = false
            return
        } else if !newDetections.isEmpty {
            // First detection
            lastDetectionTime = Date()
        }
        
        // Update rectangles with their status
        var overlays: [(rect: CGRect, hasBook: Bool)] = []
        var updatedBooks: [DetectedBook] = [] // Start fresh
        
        for detection in newDetections {
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
        print("📚 [addBookToLibrary] Starting...")
        print("   Library ID: \(libraryId.uuidString)")
        
        guard let book = detectedBook.book else { 
            print("❌ [addBookToLibrary] No book details available")
            errorMessage = "Book details not available"
            return 
        }
        
        print("   Book: \(book.title) by \(book.authors.joined(separator: ", "))")
        
        do {
            // Step 1: Save book to database first
            print("🔄 [addBookToLibrary] Step 1: Saving book to database...")
            let savedBook = try await detectionService.apiService.saveBook(book)
            
            guard let bookId = savedBook.id else {
                print("❌ [addBookToLibrary] Saved book has no ID")
                errorMessage = "Error al guardar el libro"
                return
            }
            
            print("   Saved Book ID: \(bookId.uuidString)")
            
            // Step 2: Add book to library
            print("🔄 [addBookToLibrary] Step 2: Adding book to library...")
            try await detectionService.apiService.addBooksToLibrary(libraryId: libraryId, bookIds: [bookId])
            print("✅ [addBookToLibrary] Book successfully added to library")
            
            // Add to ignored texts so we don't detect this book again
            ignoredTexts.insert(detectedBook.detectedText)
            print("   Added to ignored list: \(detectedBook.detectedText)")
            
            // Remove from detected books and overlays
            let beforeCount = detectedBooks.count
            detectedBooks.removeAll { $0.id == detectedBook.id }
            print("   Removed from list (\(beforeCount) → \(detectedBooks.count))")
            
            // Remove the overlay for this specific book
            let beforeOverlays = rectangleOverlays.count
            rectangleOverlays.removeAll { overlay in
                overlay.rect == detectedBook.boundingBox
            }
            print("   Removed overlay (\(beforeOverlays) → \(rectangleOverlays.count))")
            
            print("✅ [addBookToLibrary] Complete - Book added and ignored for future scans")
        } catch {
            print("❌ [addBookToLibrary] Error: \(error)")
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
