import Vision
import CoreImage
import UIKit

class MultiBookDetectionService {
    let apiService: BookApiService
    
    init(apiService: BookApiService) {
        self.apiService = apiService
    }
    
    /// Detect books using rectangle detection, then extract text from detected regions
    func detectBooks(in pixelBuffer: CVPixelBuffer) async -> [DetectedBook] {
        print("🔍 Starting book detection...")
        
        // Step 1: Detect rectangles (book shapes)
        let rectangles = await detectRectangles(in: pixelBuffer)
        print("📐 Found \(rectangles.count) rectangles")
        
        guard !rectangles.isEmpty else {
            return []
        }
        
        // Step 2: Extract text from each rectangle
        var detectedBooks: [DetectedBook] = []
        
        for (index, rectangle) in rectangles.enumerated() {
            print("📖 Processing rectangle \(index + 1)/\(rectangles.count)")
            
            if let text = await extractText(from: pixelBuffer, in: rectangle) {
                // Clean and normalize extracted text
                let cleanedText = cleanExtractedText(text)
                print("✍️ Original text (\(text.count) chars): \(text.prefix(100))...")
                print("🧹 Cleaned text (\(cleanedText.count) chars): \(cleanedText)")
                
                // Only use if we have meaningful text
                guard !cleanedText.isEmpty, cleanedText.count >= 5 else {
                    print("⚠️ Skipping - text too short or empty after cleaning")
                    continue
                }
                
                let detectedBook = DetectedBook(
                    detectedText: cleanedText,
                    isbn: nil,
                    boundingBox: rectangle
                )
                detectedBooks.append(detectedBook)
            }
        }
        
        print("✅ Detection complete: \(detectedBooks.count) books with text detected")
        return detectedBooks
    }
    
    /// Clean and normalize OCR text for better API matching
    private func cleanExtractedText(_ text: String) -> String {
        // Remove excessive whitespace and normalize
        var cleaned = text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        
        // Remove common OCR noise characters
        cleaned = cleaned.replacingOccurrences(of: "|", with: "")
        cleaned = cleaned.replacingOccurrences(of: "_", with: "")
        cleaned = cleaned.replacingOccurrences(of: "~", with: "")
        
        // Limit to reasonable length (first 200 chars)
        if cleaned.count > 200 {
            cleaned = String(cleaned.prefix(200))
        }
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Detect rectangular shapes (potential books) in the frame
    private func detectRectangles(in pixelBuffer: CVPixelBuffer) async -> [CGRect] {
        return await withCheckedContinuation { continuation in
            let request = VNDetectRectanglesRequest { request, error in
                if let error = error {
                    print("❌ Rectangle detection error: \(error)")
                    continuation.resume(returning: [])
                    return
                }
                
                guard let observations = request.results as? [VNRectangleObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                
                // Filter and sort rectangles
                let rectangles = observations
                    .filter { observation in
                        // Filter by confidence and size
                        observation.confidence > 0.3 &&
                        observation.boundingBox.width > 0.1 &&
                        observation.boundingBox.height > 0.1
                    }
                    .sorted { $0.boundingBox.width * $0.boundingBox.height > $1.boundingBox.width * $1.boundingBox.height }
                    .prefix(3) // Take top 3 largest rectangles
                    .map { $0.boundingBox }
                
                print("📦 Filtered to \(rectangles.count) valid rectangles")
                continuation.resume(returning: Array(rectangles))
            }
            
            // Configure rectangle detection
            request.minimumAspectRatio = 0.3
            request.maximumAspectRatio = 1.5
            request.minimumSize = 0.1
            request.maximumObservations = 5
            
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                print("❌ Failed to perform rectangle detection: \(error)")
                continuation.resume(returning: [])
            }
        }
    }
    
    /// Extract text from a specific region of the frame
    private func extractText(from pixelBuffer: CVPixelBuffer, in boundingBox: CGRect) async -> String? {
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    print("❌ Text recognition error: \(error)")
                    continuation.resume(returning: nil)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: nil)
                    return
                }
                
                // Filter observations that intersect with the bounding box
                let expandedBox = boundingBox.insetBy(dx: -0.05, dy: -0.05) // Expand box slightly
                
                let relevantText = observations
                    .filter { observation in
                        expandedBox.intersects(observation.boundingBox)
                    }
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: " ")
                
                print("  📝 Extracted \(relevantText.count) chars from region")
                
                if relevantText.isEmpty {
                    continuation.resume(returning: nil)
                } else {
                    continuation.resume(returning: relevantText)
                }
            }
            
            // Configure text recognition
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US", "es-ES"]
            
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                print("❌ Failed to perform text recognition: \(error)")
                continuation.resume(returning: nil)
            }
        }
    }
    
    /// Fetch book details from API using the full extracted text
    /// Returns array of books that match the detected text
    func fetchBookDetails(for detectedBook: DetectedBook) async -> [Book] {
        print("📡 fetchBookDetails called for detection: \(detectedBook.id)")
        print("   Full text: '\(detectedBook.detectedText)'")
        print("   Text length: \(detectedBook.detectedText.count) chars")
        
        // Use the full extracted text for API search
        let searchText = detectedBook.detectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !searchText.isEmpty else {
            print("⚠️ No text available for search")
            return []
        }
        
        print("🔍 Searching by full OCR text...")
        print("   Search query: '\(searchText)'")
        
        do {
            let books = try await apiService.searchByCover(searchText)
            print("📊 API returned \(books.count) books")
            return books
        } catch {
            print("❌ Search API error: \(error)")
            print("   Full error: \(String(describing: error))")
            return []
        }
    }
}
