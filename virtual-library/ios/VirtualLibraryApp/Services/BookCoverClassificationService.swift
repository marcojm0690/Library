import Vision
import CoreML
import UIKit

/// Service for classifying and matching book covers using CNN-based image features
/// Uses pre-trained models to extract visual features from book covers
class BookCoverClassificationService {
    
    // MARK: - Properties
    
    private var featureExtractorModel: VNCoreMLModel?
    
    // MARK: - Initialization
    
    init() {
        setupModels()
    }
    
    private func setupModels() {
        // RECOMMENDED: MobileNetV3 for feature extraction
        // 
        // Why MobileNetV3 for book covers?
        // ✓ Fast feature extraction (30-50ms)
        // ✓ Small model size (won't bloat app)
        // ✓ Good enough accuracy for cover matching
        // ✓ Battery efficient for real-time scanning
        //
        // For now, we use Vision's built-in VNGenerateImageFeaturePrintRequest
        // which provides excellent features without needing a separate model.
        // This is actually better than loading MobileNetV3 explicitly because:
        // - Zero setup required
        // - Optimized by Apple
        // - Automatic updates with iOS
        
        print("📱 Book cover classification service initialized")
        print("   Using Vision's built-in feature extraction (optimized)")
    }
    
    // MARK: - Feature Extraction
    
    /// Extract visual features from a book cover image using CNN
    /// These features can be used for similarity matching or classification
    /// - Parameter image: The book cover image
    /// - Returns: Feature vector (typically 1000-2048 dimensions depending on model)
    func extractFeatures(from image: UIImage) async -> [Float]? {
        guard let cgImage = image.cgImage else {
            return nil
        }
        
        return await withCheckedContinuation { continuation in
            // Use VNGenerateImageFeaturePrintRequest for feature extraction
            let request = VNGenerateImageFeaturePrintRequest { request, error in
                guard error == nil,
                      let results = request.results as? [VNFeaturePrintObservation],
                      let featurePrint = results.first else {
                    continuation.resume(returning: nil)
                    return
                }
                
                // Convert feature print to array of floats
                let features = self.convertFeaturePrintToArray(featurePrint)
                continuation.resume(returning: features)
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                print("⚠️ Feature extraction failed: \(error)")
                continuation.resume(returning: nil)
            }
        }
    }
    
    private func convertFeaturePrintToArray(_ featurePrint: VNFeaturePrintObservation) -> [Float] {
        // VNFeaturePrintObservation contains the feature vector
        // This is a simplified conversion
        var features: [Float] = []
        let data = featurePrint.data
        data.withUnsafeBytes { buffer in
            let floatBuffer = buffer.bindMemory(to: Float.self)
            features = Array(floatBuffer)
        }
        return features
    }
    
    // MARK: - Similarity Matching
    
    /// Calculate similarity between two book cover images
    /// Uses cosine similarity on extracted CNN features
    /// - Parameters:
    ///   - image1: First book cover
    ///   - image2: Second book cover
    /// - Returns: Similarity score (0.0 to 1.0, where 1.0 is identical)
    func calculateSimilarity(between image1: UIImage, and image2: UIImage) async -> Float {
        guard let features1 = await extractFeatures(from: image1),
              let features2 = await extractFeatures(from: image2) else {
            return 0.0
        }
        
        return cosineSimilarity(features1, features2)
    }
    
    private func cosineSimilarity(_ vector1: [Float], _ vector2: [Float]) -> Float {
        guard vector1.count == vector2.count else {
            return 0.0
        }
        
        var dotProduct: Float = 0.0
        var norm1: Float = 0.0
        var norm2: Float = 0.0
        
        for i in 0..<vector1.count {
            dotProduct += vector1[i] * vector2[i]
            norm1 += vector1[i] * vector1[i]
            norm2 += vector2[i] * vector2[i]
        }
        
        norm1 = sqrt(norm1)
        norm2 = sqrt(norm2)
        
        guard norm1 > 0 && norm2 > 0 else {
            return 0.0
        }
        
        return dotProduct / (norm1 * norm2)
    }
    
    // MARK: - Color Analysis
    
    /// Extract dominant colors from book cover using custom algorithm
    /// Useful for UI presentation and additional matching features
    func extractDominantColors(from image: UIImage, count: Int = 5) async -> [UIColor] {
        guard let cgImage = image.cgImage else {
            return []
        }
        
        // Simple dominant color extraction using image downsampling
        return await Task.detached {
            var colors: [UIColor] = []
            let size = CGSize(width: 50, height: 50)
            
            UIGraphicsBeginImageContext(size)
            defer { UIGraphicsEndImageContext() }
            
            let context = UIGraphicsGetCurrentContext()
            context?.interpolationQuality = .high
            
            let rect = CGRect(origin: .zero, size: size)
            UIImage(cgImage: cgImage).draw(in: rect)
            
            guard let downsampledImage = UIGraphicsGetImageFromCurrentImageContext(),
                  let pixelData = downsampledImage.cgImage?.dataProvider?.data,
                  let data = CFDataGetBytePtr(pixelData) else {
                return []
            }
            
            // Sample colors from downsampled image
            var colorCounts: [UIColor: Int] = [:]
            let pixelCount = Int(size.width * size.height)
            
            for i in 0..<min(pixelCount, 100) {
                let offset = i * 4
                let r = CGFloat(data[offset]) / 255.0
                let g = CGFloat(data[offset + 1]) / 255.0
                let b = CGFloat(data[offset + 2]) / 255.0
                let color = UIColor(red: r, green: g, blue: b, alpha: 1.0)
                colorCounts[color, default: 0] += 1
            }
            
            // Get most common colors
            colors = colorCounts.sorted { $0.value > $1.value }
                .prefix(count)
                .map { $0.key }
            
            return colors
        }.value
    }
    
    // MARK: - Quality Assessment
    
    /// Assess the quality of a book cover image
    /// Helps determine if the image is suitable for detection/matching
    func assessImageQuality(_ image: UIImage) async -> ImageQuality {
        guard let cgImage = image.cgImage else {
            return ImageQuality(score: 0.0, isAcceptable: false, issues: ["Invalid image"])
        }
        
        var issues: [String] = []
        var qualityScore: Float = 1.0
        
        // Check resolution
        let width = cgImage.width
        let height = cgImage.height
        let minDimension = min(width, height)
        
        if minDimension < 200 {
            issues.append("Low resolution")
            qualityScore *= 0.5
        }
        
        // Check if image is too blurry using Vision
        let blurScore = await detectBlur(cgImage: cgImage)
        if blurScore > 0.7 {
            issues.append("Image appears blurry")
            qualityScore *= 0.6
        }
        
        // Check aspect ratio (book covers should be roughly rectangular)
        let aspectRatio = Float(width) / Float(height)
        if aspectRatio < 0.5 || aspectRatio > 2.0 {
            issues.append("Unusual aspect ratio")
            qualityScore *= 0.8
        }
        
        let isAcceptable = qualityScore >= 0.5 && issues.count < 3
        
        return ImageQuality(
            score: qualityScore,
            isAcceptable: isAcceptable,
            issues: issues
        )
    }
    
    private func detectBlur(cgImage: CGImage) async -> Float {
        // Laplacian variance blur detection
        // Higher variance = sharper image, lower variance = blurry image
        return await Task.detached {
            let ciImage = CIImage(cgImage: cgImage)
            let context = CIContext(options: [.useSoftwareRenderer: false])
            
            // Convert to grayscale for faster processing
            guard let grayscaleFilter = CIFilter(name: "CIColorControls") else {
                return 0.3
            }
            grayscaleFilter.setValue(ciImage, forKey: kCIInputImageKey)
            grayscaleFilter.setValue(0.0, forKey: kCIInputSaturationKey)
            
            guard let grayImage = grayscaleFilter.outputImage else {
                return 0.3
            }
            
            // Apply Laplacian edge detection filter
            guard let laplacianFilter = CIFilter(name: "CIEdges") else {
                return 0.3
            }
            laplacianFilter.setValue(grayImage, forKey: kCIInputImageKey)
            laplacianFilter.setValue(1.0, forKey: kCIInputIntensityKey)
            
            guard let edgeImage = laplacianFilter.outputImage else {
                return 0.3
            }
            
            // Sample the image to calculate variance
            let extent = edgeImage.extent
            let smallExtent = CGRect(x: 0, y: 0, width: min(100, extent.width), height: min(100, extent.height))
            
            guard let outputCGImage = context.createCGImage(edgeImage, from: smallExtent) else {
                return 0.3
            }
            
            // Calculate variance of pixel values
            guard let dataProvider = outputCGImage.dataProvider,
                  let pixelData = dataProvider.data,
                  let data = CFDataGetBytePtr(pixelData) else {
                return 0.3
            }
            
            let pixelCount = outputCGImage.width * outputCGImage.height
            var sum: Double = 0.0
            var sumSquared: Double = 0.0
            
            for i in 0..<pixelCount {
                let offset = i * 4
                let gray = Double(data[offset])
                sum += gray
                sumSquared += gray * gray
            }
            
            let mean = sum / Double(pixelCount)
            let variance = (sumSquared / Double(pixelCount)) - (mean * mean)
            
            // Normalize variance to 0.0-1.0 blur score
            // Lower variance = more blur, higher score
            // Typical values: sharp image variance > 500, blurry < 100
            let normalizedVariance = min(variance / 1000.0, 1.0)
            let blurScore = Float(1.0 - normalizedVariance)
            
            return blurScore
        }.value
    }
    
    // MARK: - Text Detection on Cover
    
    /// Detect and extract text regions from book cover
    /// Returns bounding boxes for title, author, etc.
    func detectTextRegions(in image: UIImage) async -> [TextRegion] {
        guard let cgImage = image.cgImage else {
            return []
        }
        
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil,
                      let results = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                
                let regions = results.compactMap { observation -> TextRegion? in
                    guard let topCandidate = observation.topCandidates(1).first else {
                        return nil
                    }
                    
                    return TextRegion(
                        text: topCandidate.string,
                        boundingBox: observation.boundingBox,
                        confidence: topCandidate.confidence
                    )
                }
                
                continuation.resume(returning: regions)
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: [])
            }
        }
    }
}

// MARK: - Supporting Types

struct ImageQuality {
    let score: Float
    let isAcceptable: Bool
    let issues: [String]
}

struct TextRegion {
    let text: String
    let boundingBox: CGRect
    let confidence: Float
}

// Blur detection uses Laplacian variance algorithm:
// - Converts image to grayscale
// - Applies edge detection (Laplacian operator)
// - Calculates variance of edge intensities
// - Low variance = blurry (few/weak edges)
// - High variance = sharp (strong edges)