import Foundation
import SwiftUI
import Vision

/// ViewModel for quote verification feature
@MainActor
class QuoteVerificationViewModel: ObservableObject {
    @Published var quoteText = ""
    @Published var claimedAuthor = ""
    @Published var result: QuoteVerificationResponse?
    @Published var isLoading = false
    @Published var error: String?
    @Published var selectedInputMethod: QuoteInputMethod = .text
    
    private let apiService: BookApiService
    private let userId: String?
    
    init(userId: String? = nil, apiService: BookApiService = BookApiService()) {
        self.userId = userId
        self.apiService = apiService
    }
    
    /// Verify the quote using the selected input method
    func verifyQuote() async {
        guard !quoteText.trimmingCharacters(in: .whitespaces).isEmpty else {
            error = "Por favor ingresa una cita"
            return
        }
        
        isLoading = true
        error = nil
        result = nil
        
        do {
            let request = QuoteVerificationRequest(
                quoteText: quoteText.trimmingCharacters(in: .whitespaces),
                claimedAuthor: claimedAuthor.isEmpty ? nil : claimedAuthor.trimmingCharacters(in: .whitespaces),
                userId: userId,
                inputMethod: selectedInputMethod.rawValue
            )
            
            print("🔍 Verifying quote: \(request.quoteText)")
            print("🔍 Claimed author: \(request.claimedAuthor ?? "none")")
            print("🔍 Input method: \(request.inputMethod)")
            
            result = try await apiService.verifyQuote(request)
            print("✅ Verification complete. Confidence: \(result?.overallConfidence ?? 0)")
            
        } catch {
            self.error = "Error al verificar la cita: \(error.localizedDescription)"
            print("❌ Failed to verify quote: \(error)")
        }
        
        isLoading = false
    }
    
    /// Reset the form and results
    func reset() {
        quoteText = ""
        claimedAuthor = ""
        result = nil
        error = nil
    }
    
    /// Clear just the results
    func clearResults() {
        result = nil
        error = nil
    }
    
    /// Extract text from an image using Vision framework
    func extractTextFromImage(_ image: UIImage) async {
        guard let cgImage = image.cgImage else {
            error = "No se pudo procesar la imagen"
            return
        }
        
        isLoading = true
        error = nil
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard let self = self else { return }
            
            Task { @MainActor in
                if let error = error {
                    self.error = "Error al extraer texto: \(error.localizedDescription)"
                    self.isLoading = false
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    self.error = "No se encontró texto en la imagen"
                    self.isLoading = false
                    return
                }
                
                let extractedText = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: " ")
                
                if extractedText.isEmpty {
                    self.error = "No se pudo extraer texto de la imagen"
                } else {
                    self.quoteText = extractedText
                }
                
                self.isLoading = false
            }
        }
        
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        do {
            try requestHandler.perform([request])
        } catch {
            await MainActor.run {
                self.error = "Error al procesar la imagen: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
}
