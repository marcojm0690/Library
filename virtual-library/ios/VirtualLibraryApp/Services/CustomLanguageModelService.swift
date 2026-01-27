import Foundation
import Speech

/// Service for creating and managing custom language models for improved speech recognition
/// Uses SFSpeechLanguageModel to train on user-specific vocabulary (author names, book titles)
@MainActor
class CustomLanguageModelService {
    
    private let logger = Logger(subsystem: "com.virtuallibrary", category: "CustomLanguageModel")
    
    /// Generate custom language model training data from vocabulary hints
    /// This creates an SFCustomLanguageModelData object that iOS uses to improve recognition
    ///
    /// - Parameter vocabularyHints: Array of words/phrases to train on (authors, titles, etc.)
    /// - Returns: URL to the generated training data file
    func generateTrainingData(from vocabularyHints: [String]) async throws -> URL {
        guard !vocabularyHints.isEmpty else {
            throw CustomLanguageModelError.emptyVocabulary
        }
        
        // Create custom language model data
        // Requires identifier and version for model management
        let languageModelData = SFCustomLanguageModelData(
            locale: .current,
            identifier: "com.virtuallibrary.speechmodel",
            version: "1.0"
        ) {
            // Each phrase gets a count of 1 (can be increased for more weight)
            for hint in vocabularyHints {
                SFCustomLanguageModelData.PhraseCount(phrase: hint, count: 1)
            }
        }
        
        logger.debug("Added \(vocabularyHints.count) training phrases to custom language model")
        
        // Export training data to a file
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let trainingDataURL = documentsURL.appendingPathComponent("speech-training-data.bin")
        
        try await languageModelData.export(to: trainingDataURL)
        
        logger.info("✅ Generated custom language model training data: \(trainingDataURL.path)")
        return trainingDataURL
    }
    
    /// Prepare a custom language model from training data
    /// This uses ML to create a model optimized for your specific vocabulary
    ///
    /// - Parameter trainingDataURL: URL to the training data file
    /// - Returns: Configured SFSpeechLanguageModel.Configuration
    func prepareCustomLanguageModel(from trainingDataURL: URL) async throws -> SFSpeechLanguageModel.Configuration {
        // Create configuration for the custom language model
        let configuration = SFSpeechLanguageModel.Configuration(languageModel: trainingDataURL)
        
        // Prepare the model (this trains the ML model on your vocabulary)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            SFSpeechLanguageModel.prepareCustomLanguageModel(
                for: trainingDataURL,
                configuration: configuration
            ) { error in
                if let error = error {
                    self.logger.error("❌ Failed to prepare custom language model: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                } else {
                    self.logger.info("✅ Custom language model prepared successfully")
                    continuation.resume()
                }
            }
        }
        
        return configuration
    }
    
    /// Complete workflow: Generate training data and prepare custom language model
    ///
    /// - Parameter vocabularyHints: Array of words/phrases to train on
    /// - Returns: Configuration ready to use with SFSpeechRecognizer
    func createCustomLanguageModel(from vocabularyHints: [String]) async throws -> SFSpeechLanguageModel.Configuration {
        // Step 1: Generate training data from vocabulary
        let trainingDataURL = try await generateTrainingData(from: vocabularyHints)
        
        // Step 2: Prepare the custom ML model
        let configuration = try await prepareCustomLanguageModel(from: trainingDataURL)
        
        logger.info("✅ Custom language model ready with \(vocabularyHints.count) vocabulary hints")
        return configuration
    }
    
    /// Clean up old training data files
    func cleanupTrainingData() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let trainingDataURL = documentsURL.appendingPathComponent("speech-training-data.bin")
        
        if FileManager.default.fileExists(atPath: trainingDataURL.path) {
            try? FileManager.default.removeItem(at: trainingDataURL)
            logger.debug("🗑️ Cleaned up old training data")
        }
    }
}

// MARK: - Errors

enum CustomLanguageModelError: LocalizedError {
    case emptyVocabulary
    case trainingDataGenerationFailed
    case modelPreparationFailed
    
    var errorDescription: String? {
        switch self {
        case .emptyVocabulary:
            return "Cannot create custom language model with empty vocabulary"
        case .trainingDataGenerationFailed:
            return "Failed to generate training data for custom language model"
        case .modelPreparationFailed:
            return "Failed to prepare custom language model"
        }
    }
}

// MARK: - Logger Extension

fileprivate extension CustomLanguageModelService {
    struct Logger {
        let subsystem: String
        let category: String
        
        func debug(_ message: String) {
            print("🔍 [\(category)] \(message)")
        }
        
        func info(_ message: String) {
            print("ℹ️ [\(category)] \(message)")
        }
        
        func error(_ message: String) {
            print("❌ [\(category)] \(message)")
        }
    }
}
