# Book Detection with CNNs and Core ML

## Overview

This document explains how to implement Convolutional Neural Network (CNN) based book detection in the Virtual Library iOS app using Apple's Core ML framework.

## Architecture

### Three-Layer Detection Pipeline

```
Camera Feed → CNN Object Detection → OCR Text Extraction → API Matching
                      ↓
                Feature Extraction → Cover Matching → Metadata Enrichment
```

## Components

### 1. BookObjectDetectionService
**Purpose:** Detect book-shaped objects in camera feed using CNNs

**Key Features:**
- Object detection using pre-trained Core ML models
- Rectangle detection fallback with book-specific heuristics
- Confidence scoring and filtering
- Real-time performance optimization

**How it works:**
```swift
// Detect books in real-time from camera
let detections = await bookDetector.detectBooks(in: pixelBuffer)

// Filter high-confidence detections
let books = detections.filter { $0.confidence > 0.7 }
```

### 2. BookCoverClassificationService
**Purpose:** Extract visual features and classify book covers

**Key Features:**
- CNN-based feature extraction (1000+ dimensions)
- Cover-to-cover similarity matching
- Image quality assessment
- Dominant color extraction
- Text region detection

**How it works:**
```swift
// Extract visual features for matching
let features = await coverClassifier.extractFeatures(from: coverImage)

// Calculate similarity between covers
let similarity = await coverClassifier.calculateSimilarity(
    between: scannedCover,
    and: databaseCover
)

// Assess if image is good quality
let quality = await coverClassifier.assessImageQuality(image)
if quality.isAcceptable {
    // Proceed with detection
}
```

### 3. MultiBookDetectionService (Enhanced)
**Purpose:** Orchestrate the complete detection pipeline

**Integration points:**
- Use BookObjectDetectionService for initial detection
- Apply BookCoverClassificationService for validation
- Extract text using OCRService
- Match against API using BookApiService

## How CNNs Work for Book Detection

### Neural Network Basics

1. **Input Layer:** Receives image pixels (e.g., 224x224x3 for RGB)
2. **Convolutional Layers:** Extract features like edges, textures, shapes
3. **Pooling Layers:** Reduce dimensionality, make features invariant to position
4. **Fully Connected Layers:** Combine features for classification
5. **Output Layer:** Produces predictions (book/not-book, bounding boxes, etc.)

### Training Process (if you want to train custom model)

```python
# Using Create ML or coremltools
import coremltools as ct

# 1. Prepare training data
#    - Collect 1000+ images of books with annotations
#    - Label bounding boxes around books
#    - Split into train/validation/test sets

# 2. Train or fine-tune a model
#    - Start with pre-trained model (MobileNetV3, YOLOv5)
#    - Fine-tune on book-specific dataset
#    - Optimize for mobile (quantization, pruning)

# 3. Convert to Core ML
model = ct.models.MLModel('book_detector.mlmodel')
model.save('BookDetector.mlmodel')

# 4. Add to Xcode project
```

### Pre-trained Models You Can Use

1. **YOLOv3/YOLOv5** - Fast object detection
   - Download: [Apple ML Models](https://developer.apple.com/machine-learning/models/)
   - Use case: Real-time book detection in camera feed

2. **MobileNetV3** - Lightweight classification
   - Download: [Core ML Models](https://developer.apple.com/machine-learning/models/)
   - Use case: Verify detected regions contain books

3. **ResNet50** - Feature extraction
   - Download: [Apple ML Models](https://developer.apple.com/machine-learning/models/)
   - Use case: Extract features for cover matching

4. **Vision's Built-in Models** - No download needed
   - VNGenerateImageFeaturePrintRequest
   - VNClassifyImageRequest
   - Use case: Quick prototyping

## Implementation Steps

### Step 1: Add Core ML Model to Project

1. Download or train a Core ML model (`.mlmodel` file)
2. Drag model into Xcode project
3. Xcode auto-generates Swift interface
4. Use in code:

```swift
import CoreML

do {
    let config = MLModelConfiguration()
    let model = try BookDetectorModel(configuration: config)
    let vnModel = try VNCoreMLModel(for: model.model)
} catch {
    print("Failed to load model: \(error)")
}
```

### Step 2: Integrate with Camera Pipeline

Update `MultiBookDetectionService.swift`:

```swift
import Vision

class EnhancedMultiBookDetectionService {
    let objectDetector = BookObjectDetectionService()
    let coverClassifier = BookCoverClassificationService()
    let ocrService = OCRService()
    
    func detectBooks(in pixelBuffer: CVPixelBuffer) async -> [DetectedBook] {
        // Step 1: Detect book objects using CNN
        let detections = await objectDetector.detectBooks(in: pixelBuffer)
        
        var books: [DetectedBook] = []
        
        for detection in detections {
            // Step 2: Extract region
            guard let regionImage = extractRegion(
                from: pixelBuffer,
                boundingBox: detection.boundingBox
            ) else { continue }
            
            // Step 3: Validate it's actually a book
            let classification = await coverClassifier.classifyBookRegion(
                image: regionImage
            )
            
            guard classification.isBook && classification.confidence > 0.6 else {
                continue
            }
            
            // Step 4: Extract text via OCR
            let text = await ocrService.extractText(from: regionImage)
            
            // Step 5: Extract features for matching
            let features = await coverClassifier.extractFeatures(from: regionImage)
            
            // Step 6: Create detected book
            let book = DetectedBook(
                detectedText: text ?? "",
                isbn: nil,
                boundingBox: detection.boundingBox,
                coverImage: regionImage,
                confidence: detection.confidence,
                visualFeatures: features
            )
            
            books.append(book)
        }
        
        return books
    }
}
```

### Step 3: Add Quality Checks

```swift
// Before processing, check image quality
let quality = await coverClassifier.assessImageQuality(image)

if !quality.isAcceptable {
    // Show user feedback
    showMessage("Please improve lighting or reduce blur")
    return
}
```

### Step 4: Implement Cover Matching

```swift
// When user scans a book, match against database
func findMatchingBook(scannedCover: UIImage, 
                     candidates: [Book]) async -> Book? {
    let scannedFeatures = await coverClassifier.extractFeatures(
        from: scannedCover
    )
    
    var bestMatch: (book: Book, similarity: Float)?
    
    for candidate in candidates {
        guard let coverURL = candidate.coverImageUrl,
              let coverImage = await downloadImage(from: coverURL) else {
            continue
        }
        
        let similarity = await coverClassifier.calculateSimilarity(
            between: scannedCover,
            and: coverImage
        )
        
        if similarity > (bestMatch?.similarity ?? 0.0) {
            bestMatch = (candidate, similarity)
        }
    }
    
    // Return if similarity is high enough
    return bestMatch?.similarity ?? 0 > 0.75 ? bestMatch?.book : nil
}
```

## Performance Optimization

### 1. Model Size
- Use quantized models for faster inference
- MobileNet family designed for mobile
- Target: < 50MB model size

### 2. Real-time Processing
```swift
// Process every Nth frame, not every frame
private var frameCounter = 0
private let processEveryNFrames = 5

func processFrame(_ pixelBuffer: CVPixelBuffer) async {
    frameCounter += 1
    guard frameCounter % processEveryNFrames == 0 else {
        return
    }
    
    await detectBooks(in: pixelBuffer)
}
```

### 3. Background Processing
```swift
// Use background queue for heavy operations
let detections = await Task.detached(priority: .userInitiated) {
    await self.objectDetector.detectBooks(in: pixelBuffer)
}.value
```

### 4. Caching
```swift
// Cache extracted features
private var featureCache: [String: [Float]] = [:]

func getCachedFeatures(for imageHash: String) -> [Float]? {
    return featureCache[imageHash]
}
```

## Error Handling

```swift
enum BookDetectionError: Error {
    case modelNotLoaded
    case invalidImage
    case lowConfidence
    case processingFailed(Error)
}

func detectWithErrorHandling(_ image: UIImage) async throws -> [DetectedBook] {
    guard objectDetector.isModelLoaded else {
        throw BookDetectionError.modelNotLoaded
    }
    
    guard image.cgImage != nil else {
        throw BookDetectionError.invalidImage
    }
    
    do {
        let detections = await objectDetector.detectBooks(in: image)
        
        guard !detections.isEmpty else {
            throw BookDetectionError.lowConfidence
        }
        
        return detections.map { /* convert to DetectedBook */ }
    } catch {
        throw BookDetectionError.processingFailed(error)
    }
}
```

## Testing

### Unit Tests
```swift
import XCTest

class BookDetectionTests: XCTestCase {
    func testBookDetection() async throws {
        let service = BookObjectDetectionService()
        let testImage = UIImage(named: "test_book_cover")!
        
        let detections = await service.detectBooks(in: testImage)
        
        XCTAssertGreaterThan(detections.count, 0)
        XCTAssertGreaterThan(detections.first?.confidence ?? 0, 0.5)
    }
}
```

### Performance Tests
```swift
func testDetectionPerformance() {
    measure {
        let _ = await service.detectBooks(in: testImage)
    }
    // Should complete in < 500ms on modern iPhones
}
```

## Resources

### Training Custom Models
- [Create ML Documentation](https://developer.apple.com/documentation/createml)
- [Core ML Tools](https://github.com/apple/coremltools)
- [Turi Create](https://github.com/apple/turicreate)

### Pre-trained Models
- [Apple ML Models Gallery](https://developer.apple.com/machine-learning/models/)
- [Core ML Community Models](https://github.com/likedan/Awesome-CoreML-Models)

### Learning Resources
- [WWDC Videos on Core ML](https://developer.apple.com/videos/frameworks/core-ml)
- [Vision Framework Guide](https://developer.apple.com/documentation/vision)
- [Machine Learning with Swift](https://www.raywenderlich.com/books/machine-learning-by-tutorials)

## Next Steps

1. **Download a pre-trained model** (Start with MobileNetV3)
2. **Integrate into BookObjectDetectionService**
3. **Test with sample book images**
4. **Fine-tune confidence thresholds**
5. **Collect training data for custom model** (optional)
6. **Train custom book detector** (optional)
7. **Deploy and monitor performance**

## FAQ

**Q: Do I need to train my own model?**
A: No, you can start with pre-trained models and Vision framework. Only train custom if you need better accuracy for specific book types.

**Q: How much training data do I need?**
A: For good results: 1000+ labeled images. For great results: 10,000+ images.

**Q: Will this work offline?**
A: Yes! Core ML runs entirely on-device. No internet required.

**Q: What about battery life?**
A: CNNs can be intensive. Use:
- Smaller models (MobileNet)
- Process every Nth frame
- Pause when app is backgrounded

**Q: How accurate can it be?**
A: With good models and data:
- Detection accuracy: 90-95%
- Classification accuracy: 85-90%
- OCR accuracy: 80-90% (depends on image quality)
