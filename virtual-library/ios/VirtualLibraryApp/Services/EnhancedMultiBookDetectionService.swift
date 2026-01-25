import Vision
import CoreImage
import UIKit

/// Enhanced multi-book detection service with CNN capabilities
/// Combines traditional rectangle detection with ML-based object detection and quality assessment
class EnhancedMultiBookDetectionService {
    let apiService: BookApiService
    let objectDetector: BookObjectDetectionService
    let coverClassifier: BookCoverClassificationService
    let ocrService: OCRService
    
    // Configuration
    private var useMLDetection = true  // Toggle CNN detection
    private var qualityThreshold: Float = 0.6  // Minimum quality score
    
    init(apiService: BookApiService) {
        self.apiService = apiService
        self.objectDetector = BookObjectDetectionService()
        self.coverClassifier = BookCoverClassificationService()
        self.ocrService = OCRService()
    }
    
    // MARK: - Main Detection Method
    
    /// Detect books using enhanced CNN pipeline
    /// - Parameter pixelBuffer: Camera frame buffer
    /// - Returns: Array of detected books with quality scores and visual features
    func detectBooks(in pixelBuffer: CVPixelBuffer) async -> [DetectedBook] {
        print("🔍 Starting enhanced book detection...")
        let startTime = Date()
        
        // Step 1: Detect book objects
        let detections = useMLDetection
            ? await objectDetector.detectBooks(in: pixelBuffer)
            : await detectRectanglesLegacy(in: pixelBuffer)
        
        print("📐 Found \(detections.count) potential books")
        
        guard !detections.isEmpty else {
            print("⚠️ No detections found")
            return []
        }
        
        var detectedBooks: [DetectedBook] = []
        
        // Step 2: Process each detection
        for (index, detection) in detections.enumerated() {
            print("\n📖 Processing detection \(index + 1)/\(detections.count)")
            
            // Extract the region image
            guard let regionImage = captureImage(from: pixelBuffer, in: detection.boundingBox) else {
                print("⚠️ Failed to extract region image")
                continue
            }
            
            // Validate image quality
            let quality = await coverClassifier.assessImageQuality(regionImage)
            print("📊 Image quality score: \(quality.score)")
            
            if !quality.isAcceptable {
                print("⚠️ Skipping - poor quality: \(quality.issues.joined(separator: ", "))")
                continue
            }
            
            // Extract text via OCR
            let text = await ocrService.extractText(from: regionImage)
            let cleanedText = text.map { cleanExtractedText($0) } ?? ""
            print("📝 Extracted text (\(cleanedText.count) chars): \(cleanedText.prefix(50))...")
            
            // Extract visual features for cover matching
            let features = await coverClassifier.extractFeatures(from: regionImage)
            print("🧠 Extracted \(features?.count ?? 0) feature dimensions")
            
            // Extract dominant colors for UI
            let colors = await coverClassifier.extractDominantColors(from: regionImage, count: 3)
            print("🎨 Dominant colors: \(colors.count)")
            
            // Determine detection method
            let method: DetectionMethod = useMLDetection
                ? (detection.labels.contains("book") ? .cnnObjectDetection : .hybridDetection)
                : .rectangleDetection
            
            // Create detected book with all metadata
            let detectedBook = DetectedBook(
                detectedText: cleanedText,
                isbn: nil,
                boundingBox: detection.boundingBox,
                coverImage: regionImage,
                confidence: detection.confidence,
                visualFeatures: features,
                dominantColors: colors,
                detectionMethod: method
            )
            
            print("✅ Quality detection created (score: \(detectedBook.qualityScore))")
            detectedBooks.append(detectedBook)
        }
        
        let duration = Date().timeIntervalSince(startTime)
        print("\n✅ Detection complete: \(detectedBooks.count) books in \(Int(duration * 1000))ms")
        
        return detectedBooks
    }
    
    // MARK: - Legacy Rectangle Detection (Fallback)
    
    private func detectRectanglesLegacy(in pixelBuffer: CVPixelBuffer) async -> [BookDetection] {
        let rectangles = await detectRectangles(in: pixelBuffer)
        return rectangles.map { boundingBox in
            BookDetection(
                boundingBox: boundingBox,
                confidence: 0.5,  // Default confidence for legacy detection
                labels: ["rectangle_detection"]
            )
        }
    }
    
    private func detectRectangles(in pixelBuffer: CVPixelBuffer) async -> [CGRect] {
        return await withCheckedContinuation { continuation in
            let request = VNDetectRectanglesRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNRectangleObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                
                let rectangles = observations
                    .filter { $0.confidence > 0.3 }
                    .sorted { $0.boundingBox.width * $0.boundingBox.height > $1.boundingBox.width * $1.boundingBox.height }
                    .prefix(5)
                    .map { $0.boundingBox }
                
                continuation.resume(returning: Array(rectangles))
            }
            
            request.minimumAspectRatio = 0.3
            request.maximumAspectRatio = 3.0
            request.minimumSize = 0.1
            request.maximumObservations = 10
            
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
            try? handler.perform([request])
        }
    }
    
    // MARK: - Helper Methods
    
    private func captureImage(from pixelBuffer: CVPixelBuffer, in boundingBox: CGRect) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        
        let width = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let height = CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        
        // Convert Vision coordinates (bottom-left origin) to Core Image coordinates
        let rect = CGRect(
            x: boundingBox.origin.x * width,
            y: (1 - boundingBox.origin.y - boundingBox.height) * height,
            width: boundingBox.width * width,
            height: boundingBox.height * height
        )
        
        let croppedCIImage = ciImage.cropped(to: rect)
        
        guard let cgImage = context.createCGImage(croppedCIImage, from: croppedCIImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    private func cleanExtractedText(_ text: String) -> String {
        var cleaned = text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        
        cleaned = cleaned.replacingOccurrences(of: "|", with: "")
        cleaned = cleaned.replacingOccurrences(of: "_", with: "")
        cleaned = cleaned.replacingOccurrences(of: "~", with: "")
        
        if cleaned.count > 200 {
            cleaned = String(cleaned.prefix(200))
        }
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - API Integration
    
    /// Fetch book details with enhanced matching using visual features
    func fetchBookDetails(for detectedBook: DetectedBook) async -> [Book] {
        print("📡 Fetching book details...")
        print("   Text: '\(detectedBook.detectedText.prefix(50))...'")
        print("   Has visual features: \(detectedBook.visualFeatures != nil)")
        
        do {
            // Get candidates from API
            let candidates = try await apiService.searchByCover(
                detectedBook.detectedText,
                coverImage: detectedBook.coverImage
            )
            
            print("📊 API returned \(candidates.count) candidates")
            
            // If we have visual features, rank by similarity
            if let scannedFeatures = detectedBook.visualFeatures,
               let scannedImage = detectedBook.coverImage {
                
                print("🔍 Ranking candidates by visual similarity...")
                return await rankBySimilarity(
                    candidates: candidates,
                    scannedImage: scannedImage,
                    scannedFeatures: scannedFeatures
                )
            }
            
            return candidates
            
        } catch {
            print("❌ API error: \(error)")
            return []
        }
    }
    
    /// Rank API results by visual similarity to scanned cover
    private func rankBySimilarity(
        candidates: [Book],
        scannedImage: UIImage,
        scannedFeatures: [Float]
    ) async -> [Book] {
        
        var rankedBooks: [(book: Book, similarity: Float)] = []
        
        for candidate in candidates {
            // In real implementation, you'd download the candidate's cover image
            // and compare features. For now, we'll use a placeholder.
            
            // TODO: Download candidate.coverImageUrl
            // let coverImage = await downloadImage(from: candidate.coverImageUrl)
            // let similarity = await coverClassifier.calculateSimilarity(
            //     between: scannedImage,
            //     and: coverImage
            // )
            
            // Placeholder: use default similarity
            let similarity: Float = 0.7
            rankedBooks.append((candidate, similarity))
        }
        
        // Sort by similarity
        return rankedBooks
            .sorted { $0.similarity > $1.similarity }
            .map { $0.book }
    }
    
    // MARK: - Quality Feedback
    
    /// Get user-friendly quality feedback
    func getQualityFeedback(for detectedBooks: [DetectedBook]) -> String {
        if detectedBooks.isEmpty {
            return "No books detected. Try better lighting or adjust angle."
        }
        
        let avgQuality = detectedBooks.reduce(0.0) { $0 + $1.qualityScore } / Float(detectedBooks.count)
        
        if avgQuality >= 0.8 {
            return "✓ High quality detection (\(detectedBooks.count) books)"
        } else if avgQuality >= 0.6 {
            return "Good detection. Hold steady for better results."
        } else {
            return "Detection quality is low. Improve lighting and focus."
        }
    }
    
    // MARK: - Configuration
    
    func toggleMLDetection(_ enabled: Bool) {
        useMLDetection = enabled
        print("🔧 ML detection \(enabled ? "enabled" : "disabled")")
    }
    
    func setQualityThreshold(_ threshold: Float) {
        qualityThreshold = max(0.0, min(1.0, threshold))
        print("🔧 Quality threshold set to \(qualityThreshold)")
    }
}

// MARK: - Analytics

extension EnhancedMultiBookDetectionService {
    struct DetectionAnalytics {
        var totalDetections: Int = 0
        var successfulDetections: Int = 0
        var totalProcessingTime: TimeInterval = 0
        var confidenceSum: Float = 0
        
        var averageConfidence: Float {
            guard totalDetections > 0 else { return 0 }
            return confidenceSum / Float(totalDetections)
        }
        
        var averageProcessingTime: TimeInterval {
            guard totalDetections > 0 else { return 0 }
            return totalProcessingTime / Double(totalDetections)
        }
        
        var successRate: Float {
            guard totalDetections > 0 else { return 0 }
            return Float(successfulDetections) / Float(totalDetections)
        }
    }
    
    func logAnalytics(_ analytics: DetectionAnalytics) {
        print("""
        
        📊 Detection Analytics:
           Total Detections: \(analytics.totalDetections)
           Successful: \(analytics.successfulDetections)
           Success Rate: \(Int(analytics.successRate * 100))%
           Avg Confidence: \(String(format: "%.2f", analytics.averageConfidence))
           Avg Processing Time: \(Int(analytics.averageProcessingTime * 1000))ms
        """)
    }
}
