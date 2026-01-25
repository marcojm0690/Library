import Foundation
import UIKit

struct DetectedBook: Identifiable, Equatable {
    let id: UUID
    let detectedText: String
    let isbn: String?
    let boundingBox: CGRect
    let coverImage: UIImage? // Captured cover image for API search
    var book: Book?
    var isConfirmed: Bool // True when book has been successfully fetched from API
    
    // CNN-based detection features
    let confidence: Float? // Detection confidence from CNN model (0.0 - 1.0)
    let visualFeatures: [Float]? // CNN-extracted feature vector for cover matching
    let dominantColors: [UIColor]? // Extracted dominant colors from cover
    let detectionMethod: DetectionMethod // How the book was detected
    
    init(
        id: UUID = UUID(),
        detectedText: String,
        isbn: String? = nil,
        boundingBox: CGRect,
        coverImage: UIImage? = nil,
        book: Book? = nil,
        isConfirmed: Bool = false,
        confidence: Float? = nil,
        visualFeatures: [Float]? = nil,
        dominantColors: [UIColor]? = nil,
        detectionMethod: DetectionMethod = .rectangleDetection
    ) {
        self.id = id
        self.detectedText = detectedText
        self.isbn = isbn
        self.boundingBox = boundingBox
        self.coverImage = coverImage
        self.book = book
        self.isConfirmed = isConfirmed
        self.confidence = confidence
        self.visualFeatures = visualFeatures
        self.dominantColors = dominantColors
        self.detectionMethod = detectionMethod
    }
    
    static func == (lhs: DetectedBook, rhs: DetectedBook) -> Bool {
        lhs.id == rhs.id &&
        lhs.detectedText == rhs.detectedText &&
        lhs.isbn == rhs.isbn &&
        lhs.boundingBox == rhs.boundingBox
    }
}

// MARK: - Detection Method

enum DetectionMethod: String, Codable {
    case rectangleDetection = "Rectangle Detection"
    case cnnObjectDetection = "CNN Object Detection"
    case hybridDetection = "Hybrid (CNN + Rectangle)"
    case manualSelection = "Manual Selection"
}

// MARK: - Helper Extensions

extension DetectedBook {
    /// Quality score based on multiple factors
    var qualityScore: Float {
        var score: Float = 0.5 // Base score
        
        // Factor in detection confidence
        if let confidence = confidence {
            score = (score + confidence) / 2.0
        }
        
        // Boost for CNN-based detection
        if detectionMethod == .cnnObjectDetection || detectionMethod == .hybridDetection {
            score += 0.1
        }
        
        // Boost if we have visual features (successful feature extraction)
        if visualFeatures != nil {
            score += 0.1
        }
        
        // Boost if we have cover image
        if coverImage != nil {
            score += 0.1
        }
        
        return min(score, 1.0)
    }
    
    /// Whether this detection has high enough quality to trust
    var isHighQuality: Bool {
        qualityScore >= 0.7
    }
}
