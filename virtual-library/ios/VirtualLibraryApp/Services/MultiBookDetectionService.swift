import Vision
import CoreImage
import UIKit

class MultiBookDetectionService {
    let apiService: BookApiService
    private var scanMode: ScanMode = .imageBased
    
    init(apiService: BookApiService) {
        self.apiService = apiService
    }
    
    func setScanMode(_ mode: ScanMode) {
        scanMode = mode
        print("📋 Scan mode changed to: \(mode == .imageBased ? "Image-based" : "Text-based")")
    }
    
    /// Detect books using rectangle detection, then extract text from detected regions
    func detectBooks(in pixelBuffer: CVPixelBuffer) async -> [DetectedBook] {
        print("🔍 Starting book detection in \(scanMode == .imageBased ? "image" : "text") mode...")
        
        // Step 1: Detect rectangles (book shapes)
        let rectangles = await detectRectangles(in: pixelBuffer)
        print("📐 Found \(rectangles.count) rectangles")
        
        guard !rectangles.isEmpty else {
            return []
        }
        
        // Step 2: Process based on scan mode
        var detectedBooks: [DetectedBook] = []
        
        for (index, rectangle) in rectangles.enumerated() {
            print("📖 Processing rectangle \(index + 1)/\(rectangles.count) in \(scanMode == .imageBased ? "image" : "text") mode")
            
            if scanMode == .imageBased {
                // Image-based: Capture cover image and use for recognition
                let coverImage = captureImage(from: pixelBuffer, in: rectangle)
                
                guard let image = coverImage else {
                    print("⚠️ Skipping - no valid image captured")
                    continue
                }
                
                let detectedBook = DetectedBook(
                    detectedText: "Image-based detection",
                    isbn: nil,
                    boundingBox: rectangle,
                    coverImage: image
                )
                detectedBooks.append(detectedBook)
                
            } else {
                // Text-based: Extract text using OCR
                let text = await extractText(from: pixelBuffer, in: rectangle)
                let cleanedText = text.map { cleanExtractedText($0) } ?? ""
                
                if let text = text {
                    print("✍️ Original text (\(text.count) chars): \(text.prefix(100))...")
                    print("🧹 Cleaned text (\(cleanedText.count) chars): \(cleanedText)")
                }
                
                let hasValidText = !cleanedText.isEmpty && cleanedText.count >= 5
                
                guard hasValidText else {
                    print("⚠️ Skipping - no valid text extracted")
                    continue
                }
                
                // Optionally capture image as supplementary data
                let coverImage = captureImage(from: pixelBuffer, in: rectangle)
                
                let detectedBook = DetectedBook(
                    detectedText: cleanedText,
                    isbn: nil,
                    boundingBox: rectangle,
                    coverImage: coverImage
                )
                detectedBooks.append(detectedBook)
            }
        }
        
        print("✅ Detection complete: \(detectedBooks.count) books detected")
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
    
    /// Capture an image from a specific region of the frame
    private func captureImage(from pixelBuffer: CVPixelBuffer, in boundingBox: CGRect) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        
        // Convert normalized coordinates to pixel coordinates
        let width = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let height = CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        
        // Vision coordinates have origin at bottom-left, need to flip Y
        let rect = CGRect(
            x: boundingBox.origin.x * width,
            y: (1 - boundingBox.origin.y - boundingBox.height) * height,
            width: boundingBox.width * width,
            height: boundingBox.height * height
        )
        
        // Crop the image to the bounding box
        let croppedCIImage = ciImage.cropped(to: rect)
        
        guard let cgImage = context.createCGImage(croppedCIImage, from: croppedCIImage.extent) else {
            print("⚠️ Failed to create CGImage from cropped image")
            return nil
        }
        
        let image = UIImage(cgImage: cgImage)
        print("📸 Captured cover image: \(Int(image.size.width))x\(Int(image.size.height))")
        return image
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
                    print("⚠️ No rectangle observations found")
                    continuation.resume(returning: [])
                    return
                }
                
                print("🔍 Raw rectangle observations: \(observations.count)")
                
                // Log all observations for debugging
                for (i, obs) in observations.enumerated() {
                    print("  Rectangle \(i+1): confidence=\(obs.confidence), size=\(obs.boundingBox.width)x\(obs.boundingBox.height), area=\(obs.boundingBox.width * obs.boundingBox.height)")
                }
                
                // Filter and sort rectangles - more lenient settings
                let rectangles = observations
                    .filter { observation in
                        // More lenient filtering
                        let minConfidence: Float = 0.2  // Lower confidence threshold
                        let minWidth: CGFloat = 0.08    // Smaller minimum width
                        let minHeight: CGFloat = 0.08   // Smaller minimum height
                        
                        let passes = observation.confidence > minConfidence &&
                                    observation.boundingBox.width > minWidth &&
                                    observation.boundingBox.height > minHeight
                        
                        if !passes {
                            print("  ❌ Filtered out: confidence=\(observation.confidence), size=\(observation.boundingBox.width)x\(observation.boundingBox.height)")
                        }
                        return passes
                    }
                    .sorted { $0.boundingBox.width * $0.boundingBox.height > $1.boundingBox.width * $1.boundingBox.height }
                    .prefix(5) // Take top 5 largest rectangles
                    .map { $0.boundingBox }
                
                print("📦 Filtered to \(rectangles.count) valid rectangles")
                continuation.resume(returning: Array(rectangles))
            }
            
            // Configure rectangle detection - more lenient settings
            request.minimumAspectRatio = 0.2   // Allow wider range (was 0.3)
            request.maximumAspectRatio = 2.0   // Allow taller rectangles (was 1.5)
            request.minimumSize = 0.05         // Smaller minimum size (was 0.1)
            request.minimumConfidence = 0.2    // Lower confidence threshold
            request.maximumObservations = 10   // More observations (was 5)
            
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
    
    /// Fetch book details from API using cover image (priority) and text (fallback)
    /// Returns array of books that match the detected image/text
    func fetchBookDetails(for detectedBook: DetectedBook) async -> [Book] {
        print("📡 fetchBookDetails called for detection: \(detectedBook.id)")
        print("   Has cover image: \(detectedBook.coverImage != nil)")
        print("   Text: '\(detectedBook.detectedText)'")
        print("   Text length: \(detectedBook.detectedText.count) chars")
        
        // Prioritize image search, use text as supplement
        if detectedBook.coverImage != nil {
            print("🖼️ Searching primarily by cover image...")
        } else {
            print("✍️ Searching by text only (no image available)...")
        }
        
        // Use text or placeholder if image-only
        let searchText = detectedBook.detectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        do {
            // Send both image (priority) and text (supplement) to API
            let books = try await apiService.searchByCover(searchText, coverImage: detectedBook.coverImage)
            print("📊 API returned \(books.count) books")
            return books
        } catch {
            print("❌ Search API error: \(error)")
            print("   Full error: \(String(describing: error))")
            return []
        }
    }
}
