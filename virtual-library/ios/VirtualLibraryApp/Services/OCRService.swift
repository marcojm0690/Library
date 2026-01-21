import Vision
import UIKit

/// Service responsible for extracting text from images using OCR.
/// Uses Apple's Vision framework for on-device text recognition.
class OCRService: ObservableObject {
    /// Published extracted text result
    @Published var extractedText: String?
    
    /// Published error message
    @Published var error: String?
    
    /// Extract text from an image using Vision framework
    /// - Parameter image: The UIImage to process
    func extractText(from image: UIImage) async -> String? {
        guard let cgImage = image.cgImage else {
            await MainActor.run {
                self.error = "Failed to convert image"
            }
            return nil
        }
        
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
            
            guard let observations = request.results, !observations.isEmpty else {
                await MainActor.run {
                    self.error = "No text found"
                }
                return nil
            }
            
            // Combine all recognized text with newlines
            let recognizedText = observations
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n")
            
            await MainActor.run {
                self.extractedText = recognizedText
            }
            
            return recognizedText
            
        } catch {
            await MainActor.run {
                self.error = "OCR failed: \(error.localizedDescription)"
            }
            return nil
        }
    }
    
    /// Extract text from cover image and return structured data
    /// Attempts to identify title, author, and other relevant information
    func extractStructuredText(from image: UIImage) async -> (title: String?, author: String?, fullText: String)? {
        guard let fullText = await extractText(from: image) else {
            return nil
        }
        
        // Parse the text to identify title and author
        // This is a simplified implementation - real-world would use more sophisticated parsing
        let lines = fullText.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        // Heuristic: First significant line is likely the title
        let title = lines.first
        
        // Heuristic: Look for "by" or author patterns
        let author = lines.first { line in
            line.lowercased().contains("by ") || 
            line.count < 50 && !line.contains(":") // Short lines without colons might be authors
        }
        
        return (title: title, author: author, fullText: fullText)
    }
}
