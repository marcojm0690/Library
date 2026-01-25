import SwiftUI
import AVFoundation

@MainActor
class MultiBookScanViewModel: ObservableObject {
    @Published var detectedBooks: [DetectedBook] = []
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var rectangleOverlays: [(rect: CGRect, hasBook: Bool)] = []
    
    private let cameraManager = CameraSessionManager()
    let detectionService: MultiBookDetectionService
    private var lastProcessTime: Date = .distantPast
    private let processingInterval: TimeInterval = 2.0 // Process every 2 seconds
    private let maxDetectedBooks = 3 // Limit to reduce API calls
    
    // Track books added per library (library-specific, not session-wide)
    private var booksInCurrentLibrary: Set<UUID> = [] // Book IDs already in the library
    private var currentLibraryId: UUID? // Currently selected library
    
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
    
    /// Set the current library and load its books to avoid duplicates
    func setCurrentLibrary(_ libraryId: UUID) async {
        guard currentLibraryId != libraryId else { return }
        
        currentLibraryId = libraryId
        booksInCurrentLibrary.removeAll()
        
        // Load books already in this library
        do {
            let existingBooks = try await detectionService.apiService.getBooksInLibrary(libraryId: libraryId)
            booksInCurrentLibrary = Set(existingBooks.compactMap { $0.id })
            print("📚 [ViewModel] Library \(libraryId) has \(booksInCurrentLibrary.count) existing books")
        } catch {
            print("⚠️ [ViewModel] Could not load library books: \(error)")
        }
    }
    /// Check if a book is already in the current library
    private func isBookInCurrentLibrary(_ bookId: UUID?) -> Bool {
        guard let bookId = bookId else { return false }
        return booksInCurrentLibrary.contains(bookId)
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
                
                // Check if book is already in current library
                if isBookInCurrentLibrary(bestMatch.id) {
                    print("⏭️ [ViewModel] Skipping - book already in current library")
                    continue
                }
                
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
            
            // Step 2:current library's book list to prevent re-detection
            booksInCurrentLibrary.insert(bookId)
            print("   Added to library's book list: \(bookId)")
            
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
            
            print("✅ [addBookToLibrary] Complete - Book added and won't be detected again in this library")
        } catch {
            print("❌ [addBookToLibrary] Error: \(error)")
            errorMessage = "Error al agregar el libro: \(error.localizedDescription)"
        }
    }
    
    func clearIgnoredBooks() {
        // Reset library-specific tracking (useful when switching libraries or restarting)
        booksInCurrentLibrary.removeAll()
        currentLibraryId = nil
        print("🔄 Cleared library book tracking")
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
