import Vision
import CoreML
import UIKit
import CoreImage

/// Service for detecting books using a pre-trained Core ML model
/// Combines object detection with Vision framework for enhanced accuracy
class BookObjectDetectionService {
    
    // MARK: - Models
    
    /// RECOMMENDED: MobileNetV3 - Best balance for book detection
    /// Why MobileNetV3?
    /// - Designed for iOS (fast, battery-efficient)
    /// - 30-50ms inference (real-time capable)
    /// - Small size (~5-15MB)
    /// - 70-75% accuracy (sufficient for books)
    ///
    /// Download from Apple's Core ML Model Gallery:
    /// https://developer.apple.com/machine-learning/models/
    ///
    /// Alternative models (NOT recommended for books):
    /// - ResNet50: Too heavy, slower (use for complex medical/scientific imaging)
    /// - SqueezeNet: Outdated, less accurate than MobileNetV3
    /// - YOLOv3: Good for multi-object detection, but MobileNetV3 faster for single objects
    /// - Custom trained: Only if you need 95%+ accuracy on your specific book collection
    
    private var objectDetectionModel: VNCoreMLModel?
    
    // MARK: - Initialization
    
    init() {
        setupModel()
    }
    
    private func setupModel() {
        // TODO: Download MobileNetV3 from Apple ML Gallery and add to project
        // Steps:
        // 1. Visit https://developer.apple.com/machine-learning/models/
        // 2. Download "MobileNetV3" (Small or Large variant)
        // 3. Drag .mlmodel file into Xcode project
        // 4. Uncomment code below and replace "MobileNetV3" with actual model name
        
        /*
        do {
            let config = MLModelConfiguration()
            // Use MobileNetV3Small for best performance
            let model = try MobileNetV3Small(configuration: config)
            self.objectDetectionModel = try VNCoreMLModel(for: model.model)
            print("✅ MobileNetV3 model loaded successfully")
        } catch {
            print("⚠️ Failed to load MobileNetV3 model: \(error)")
            print("   Falling back to Vision rectangle detection")
        }
        */
    }
    
    // MARK: - Detection Methods
    
    /// Detect books in an image using Core ML object detection
    /// - Parameter image: The UIImage to analyze
    /// - Returns: Array of detected book regions with confidence scores
    func detectBooks(in image: UIImage) async -> [BookDetection] {
        guard let cgImage = image.cgImage else {
            return []
        }
        
        return await detectBooks(in: cgImage)
    }
    
    /// Detect books in a pixel buffer (useful for real-time camera feed)
    /// - Parameter pixelBuffer: The CVPixelBuffer from camera
    /// - Returns: Array of detected book regions
    func detectBooks(in pixelBuffer: CVPixelBuffer) async -> [BookDetection] {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return []
        }
        
        return await detectBooks(in: cgImage)
    }
    
    private func detectBooks(in cgImage: CGImage) async -> [BookDetection] {
        // If Core ML model is available, use it
        if let model = objectDetectionModel {
            return await detectWithCoreML(cgImage: cgImage, model: model)
        }
        
        // Fallback to Vision rectangle detection + heuristics
        return await detectWithVisionHeuristics(cgImage: cgImage)
    }
    
    // MARK: - Core ML Detection
    
    private func detectWithCoreML(cgImage: CGImage, model: VNCoreMLModel) async -> [BookDetection] {
        return await withCheckedContinuation { continuation in
            let request = VNCoreMLRequest(model: model) { request, error in
                guard error == nil,
                      let results = request.results as? [VNRecognizedObjectObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                
                // Filter for book detections with confidence > 0.5
                let detections = results
                    .filter { $0.confidence > 0.5 }
                    .map { observation in
                        BookDetection(
                            boundingBox: observation.boundingBox,
                            confidence: observation.confidence,
                            labels: observation.labels.map { $0.identifier }
                        )
                    }
                
                continuation.resume(returning: detections)
            }
            
            request.imageCropAndScaleOption = .scaleFit
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                print("⚠️ Core ML detection failed: \(error)")
                continuation.resume(returning: [])
            }
        }
    }
    
    // MARK: - Vision-Based Detection (Fallback)
    
    private func detectWithVisionHeuristics(cgImage: CGImage) async -> [BookDetection] {
        return await withCheckedContinuation { continuation in
            let request = VNDetectRectanglesRequest { request, error in
                guard error == nil,
                      let results = request.results as? [VNRectangleObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                
                // Apply heuristics to filter for book-like rectangles
                let detections = results
                    .filter { self.isLikelyBook($0, imageSize: CGSize(width: cgImage.width, height: cgImage.height)) }
                    .map { observation in
                        BookDetection(
                            boundingBox: observation.boundingBox,
                            confidence: observation.confidence,
                            labels: ["book_candidate"]
                        )
                    }
                
                continuation.resume(returning: detections)
            }
            
            // Configure for better book detection
            request.minimumAspectRatio = 0.3 // Books can be vertical or horizontal
            request.maximumAspectRatio = 3.0
            request.minimumSize = 0.1 // At least 10% of image
            request.maximumObservations = 10
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                print("⚠️ Rectangle detection failed: \(error)")
                continuation.resume(returning: [])
            }
        }
    }
    
    // MARK: - Heuristics
    
    /// Determine if a detected rectangle is likely a book based on shape and size
    private func isLikelyBook(_ rectangle: VNRectangleObservation, imageSize: CGSize) -> Bool {
        let boundingBox = rectangle.boundingBox
        let width = boundingBox.width
        let height = boundingBox.height
        
        // Calculate aspect ratio (should be book-like)
        let aspectRatio = width / height
        
        // Books typically have aspect ratios between 0.6-1.5 (depending on orientation)
        let hasBookAspectRatio = (0.6...1.5).contains(aspectRatio) || (0.66...1.66).contains(1/aspectRatio)
        
        // Should occupy reasonable portion of image (not too small)
        let area = width * height
        let hasReasonableSize = area > 0.05 && area < 0.9
        
        // Check confidence
        let hasGoodConfidence = rectangle.confidence > 0.5
        
        return hasBookAspectRatio && hasReasonableSize && hasGoodConfidence
    }
    
    // MARK: - Classification Enhancement
    
    /// Classify if a detected region actually contains a book using image classification
    /// This can use MobileNetV2 or similar pre-trained classifier
    func classifyBookRegion(image: UIImage) async -> BookClassification {
        guard let cgImage = image.cgImage else {
            return BookClassification(isBook: false, confidence: 0.0, category: nil)
        }
        
        // Use Vision's built-in image classifier or custom Core ML model
        return await withCheckedContinuation { continuation in
            // Example using VNClassifyImageRequest (requires iOS 17+)
            let request = VNClassifyImageRequest { request, error in
                guard error == nil,
                      let results = request.results as? [VNClassificationObservation],
                      let topResult = results.first else {
                    continuation.resume(returning: BookClassification(isBook: false, confidence: 0.0, category: nil))
                    return
                }
                
                // Check if top classification is book-related
                let bookKeywords = ["book", "novel", "textbook", "magazine", "publication"]
                let isBook = bookKeywords.contains { topResult.identifier.lowercased().contains($0) }
                
                continuation.resume(returning: BookClassification(
                    isBook: isBook,
                    confidence: topResult.confidence,
                    category: topResult.identifier
                ))
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: BookClassification(isBook: false, confidence: 0.0, category: nil))
            }
        }
    }
}

// MARK: - Supporting Types

struct BookDetection {
    let boundingBox: CGRect
    let confidence: Float
    let labels: [String]
}

struct BookClassification {
    let isBook: Bool
    let confidence: Float
    let category: String?
}
