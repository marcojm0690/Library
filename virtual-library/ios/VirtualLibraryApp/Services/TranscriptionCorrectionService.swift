import Foundation
import NaturalLanguage

/// Service for correcting speech transcription errors using vocabulary hints
/// Applies fuzzy matching and phonetic similarity to fix misrecognized words
@MainActor
class TranscriptionCorrectionService {
    
    private let logger = Logger(subsystem: "com.virtuallibrary", category: "TranscriptionCorrection")
    
    /// Correct transcribed text using vocabulary hints
    /// - Parameters:
    ///   - transcription: The raw text from speech recognition
    ///   - vocabularyHints: Known correct words (authors, titles, etc.)
    /// - Returns: Corrected text with misrecognized words replaced
    func correctTranscription(_ transcription: String, using vocabularyHints: [String]) -> CorrectionResult {
        guard !transcription.isEmpty else {
            return CorrectionResult(
                originalText: transcription,
                correctedText: transcription,
                corrections: []
            )
        }
        
        logger.info("🔧 Correcting transcription: '\(transcription)'")
        logger.info("📚 Using \(vocabularyHints.count) vocabulary hints")
        
        var corrections: [TextCorrection] = []
        var correctedText = transcription
        
        // Only try phrase-level correction on short inputs (likely single queries)
        // Skip if input is too long (likely already correct or multiple queries)
        if transcription.split(separator: " ").count <= 4 {
            // Step 1: Try to match entire input as a phrase first
            correctedText = correctPhrases(correctedText, using: vocabularyHints, corrections: &corrections)
        }
        
        let result = CorrectionResult(
            originalText: transcription,
            correctedText: correctedText,
            corrections: corrections
        )
        
        if !corrections.isEmpty {
            logger.info("🎯 Applied \(corrections.count) corrections")
        } else {
            logger.info("✓ No corrections needed")
        }
        
        return result
    }
    
    /// Correct multi-word phrases (e.g., "Emanuelle Cunt" -> "Immanuel Kant")
    /// Also handles cases like "Shopping hour" -> "Schopenhauer"
    private func correctPhrases(_ text: String, using hints: [String], corrections: inout [TextCorrection]) -> String {
        var correctedText = text
        var bestMatch: (hint: String, match: PhraseMatch)?
        var bestScore: Double = 0.0
        
        // Find the single best match across all hints
        for hint in hints {
            // Skip very long hints (likely full titles)
            if hint.split(separator: " ").count > 5 { continue }
            
            // Try fuzzy matching
            if let match = fuzzyMatchPhrase(in: correctedText, against: hint) {
                if match.confidence > bestScore {
                    bestScore = match.confidence
                    bestMatch = (hint, match)
                }
            }
        }
        
        // Only apply the single best correction if confidence is high enough (60%)
        if let match = bestMatch, bestScore >= 0.60 {
            let correction = TextCorrection(
                original: match.match.originalPhrase,
                corrected: match.hint,
                confidence: match.match.confidence,
                range: match.match.range
            )
            corrections.append(correction)
            
            // Apply correction
            correctedText.replaceSubrange(match.match.range, with: match.hint)
            
            logger.info("✅ Phrase corrected: '\(match.match.originalPhrase)' → '\(match.hint)' (confidence: \(String(format: "%.2f", match.match.confidence)))")
        }
        
        return correctedText
    }
    
    /// Find fuzzy match for a phrase (handles different word counts)
    private func fuzzyMatchPhrase(in text: String, against targetPhrase: String) -> PhraseMatch? {
        let targetWords = targetPhrase.split(separator: " ").map(String.init)
        let targetWordCount = targetWords.count
        
        // Tokenize the text
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        
        var tokens: [(range: Range<String.Index>, text: String)] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let token = String(text[range])
            tokens.append((range: range, text: token))
            return true
        }
        
        // Only try exact word count match and ±1 word
        let windowSizes = [targetWordCount, targetWordCount - 1, targetWordCount + 1].filter { $0 > 0 && $0 <= tokens.count }
        
        var bestMatch: PhraseMatch?
        var bestScore: Double = 0.0
        
        for windowSize in windowSizes {
            for i in 0...(tokens.count - windowSize) {
                let candidateTokens = Array(tokens[i..<(i + windowSize)])
                let candidatePhrase = candidateTokens.map { $0.text }.joined(separator: " ")
                
                // Calculate similarity
                let similarity = flexiblePhraseSimilarity(candidatePhrase, targetPhrase)
                
                if similarity > bestScore {
                    bestScore = similarity
                    
                    let startIndex = candidateTokens.first!.range.lowerBound
                    let endIndex = candidateTokens.last!.range.upperBound
                    let range = startIndex..<endIndex
                    
                    bestMatch = PhraseMatch(
                        originalPhrase: candidatePhrase,
                        range: range,
                        confidence: similarity
                    )
                }
            }
        }
        
        if let match = bestMatch {
            logger.info("📊 Best phrase match: '\(match.originalPhrase)' vs '\(targetPhrase)' = \(String(format: "%.2f", match.confidence))")
        }
        
        return bestMatch
    }
    
    /// Calculate flexible phrase similarity (handles different word counts)
    private func flexiblePhraseSimilarity(_ phrase1: String, _ phrase2: String) -> Double {
        let words1 = phrase1.lowercased().split(separator: " ").map(String.init)
        let words2 = phrase2.lowercased().split(separator: " ").map(String.init)
        
        // If word counts match, use word-by-word comparison
        if words1.count == words2.count {
            return wordByWordSimilarity(words1, words2)
        }
        
        // If word counts differ, treat as single strings
        // This handles "Shopping hour" vs "Schopenhauer"
        let combined1 = words1.joined()
        let combined2 = words2.joined()
        
        let levenshteinSim = levenshteinSimilarity(combined1, combined2)
        let phoneticSim = phoneticSimilarity(combined1, combined2)
        
        let score = (levenshteinSim * 0.5 + phoneticSim * 0.5)
        
        logger.info("  String match: '\(combined1)' vs '\(combined2)' = \(String(format: "%.2f", score)) (lev: \(String(format: "%.2f", levenshteinSim)), phon: \(String(format: "%.2f", phoneticSim)))")
        
        return score
    }
    
    /// Word-by-word similarity for equal length phrases
    private func wordByWordSimilarity(_ words1: [String], _ words2: [String]) -> Double {
        var totalScore = 0.0
        
        for (word1, word2) in zip(words1, words2) {
            let levenshteinSim = levenshteinSimilarity(word1, word2)
            let phoneticSim = phoneticSimilarity(word1, word2)
            
            let wordScore = (levenshteinSim * 0.5 + phoneticSim * 0.5)
            totalScore += wordScore
            
            logger.info("  Word match: '\(word1)' vs '\(word2)' = \(String(format: "%.2f", wordScore)) (lev: \(String(format: "%.2f", levenshteinSim)), phon: \(String(format: "%.2f", phoneticSim)))")
        }
        
        return totalScore / Double(words1.count)
    }
    
    /// Find the best matching vocabulary hint for a word
    private func findBestMatch(for word: String, in hints: [String]) -> Match? {
        var bestMatch: Match?
        var bestScore: Double = 0.0
        
        // Lowered threshold to 50% for better matching
        let minSimilarity: Double = 0.50
        
        for hint in hints {
            // Calculate multiple similarity scores
            let levenshteinSim = levenshteinSimilarity(word, hint)
            let phoneticSim = phoneticSimilarity(word, hint)
            let prefixSim = prefixSimilarity(word, hint)
            
            // Weighted combination of similarity metrics
            let combinedScore = (
                levenshteinSim * 0.5 +  // Edit distance (increased weight)
                phoneticSim * 0.4 +      // Phonetic similarity
                prefixSim * 0.1           // Prefix matching
            )
            
            if combinedScore > bestScore && combinedScore >= minSimilarity {
                bestScore = combinedScore
                bestMatch = Match(word: hint, confidence: combinedScore)
                
                logger.info("  Candidate: '\(word)' vs '\(hint)' = \(String(format: "%.2f", combinedScore)) (lev: \(String(format: "%.2f", levenshteinSim)), phon: \(String(format: "%.2f", phoneticSim)))")
            }
        }
        
        return bestMatch
    }
    
    /// Calculate Levenshtein distance similarity (0.0 to 1.0)
    private func levenshteinSimilarity(_ str1: String, _ str2: String) -> Double {
        let s1 = str1.lowercased()
        let s2 = str2.lowercased()
        
        let distance = levenshteinDistance(s1, s2)
        let maxLength = max(s1.count, s2.count)
        
        guard maxLength > 0 else { return 1.0 }
        
        return 1.0 - (Double(distance) / Double(maxLength))
    }
    
    /// Calculate Levenshtein edit distance
    private func levenshteinDistance(_ str1: String, _ str2: String) -> Int {
        let s1 = Array(str1)
        let s2 = Array(str2)
        
        var matrix = [[Int]](
            repeating: [Int](repeating: 0, count: s2.count + 1),
            count: s1.count + 1
        )
        
        for i in 0...s1.count {
            matrix[i][0] = i
        }
        
        for j in 0...s2.count {
            matrix[0][j] = j
        }
        
        for i in 1...s1.count {
            for j in 1...s2.count {
                let cost = s1[i-1] == s2[j-1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i-1][j] + 1,      // deletion
                    matrix[i][j-1] + 1,      // insertion
                    matrix[i-1][j-1] + cost  // substitution
                )
            }
        }
        
        return matrix[s1.count][s2.count]
    }
    
    /// Calculate phonetic similarity using simplified Soundex-like algorithm
    private func phoneticSimilarity(_ str1: String, _ str2: String) -> Double {
        let phonetic1 = phoneticEncoding(str1)
        let phonetic2 = phoneticEncoding(str2)
        
        // Compare phonetic encodings
        return levenshteinSimilarity(phonetic1, phonetic2)
    }
    
    /// Generate phonetic encoding (simplified Soundex/Metaphone approach)
    private func phoneticEncoding(_ str: String) -> String {
        let s = str.lowercased()
        var encoded = ""
        
        // Keep first letter
        if let first = s.first {
            encoded.append(first)
        }
        
        // Convert to phonetic codes
        for char in s.dropFirst() {
            let code = phoneticCode(for: char)
            if !code.isEmpty && (encoded.isEmpty || encoded.last != code.first) {
                encoded.append(code)
            }
        }
        
        return encoded
    }
    
    /// Get phonetic code for a character
    private func phoneticCode(for char: Character) -> String {
        switch char.lowercased() {
        case "b", "f", "p", "v":
            return "1"
        case "c", "g", "j", "k", "q", "s", "x", "z":
            return "2"
        case "d", "t":
            return "3"
        case "l":
            return "4"
        case "m", "n":
            return "5"
        case "r":
            return "6"
        default:
            return "" // Vowels and other letters are dropped
        }
    }
    
    /// Calculate prefix similarity (for catching partial matches)
    private func prefixSimilarity(_ str1: String, _ str2: String) -> Double {
        let s1 = str1.lowercased()
        let s2 = str2.lowercased()
        
        let minLength = min(s1.count, s2.count)
        guard minLength > 0 else { return 0.0 }
        
        var matchingChars = 0
        let prefix1 = s1.prefix(minLength)
        let prefix2 = s2.prefix(minLength)
        
        for (c1, c2) in zip(prefix1, prefix2) {
            if c1 == c2 {
                matchingChars += 1
            } else {
                break
            }
        }
        
        return Double(matchingChars) / Double(minLength)
    }
}

// MARK: - Models

struct Match {
    let word: String
    let confidence: Double
}

struct PhraseMatch {
    let originalPhrase: String
    let range: Range<String.Index>
    let confidence: Double
}

struct TextCorrection {
    let original: String
    let corrected: String
    let confidence: Double
    let range: Range<String.Index>
}

struct CorrectionResult {
    let originalText: String
    let correctedText: String
    let corrections: [TextCorrection]
    
    var hasCorrections: Bool {
        !corrections.isEmpty
    }
}

// MARK: - Logger

fileprivate extension TranscriptionCorrectionService {
    struct Logger {
        let subsystem: String
        let category: String
        
        func info(_ message: String) {
            print("ℹ️ [\(category)] \(message)")
        }
    }
}
