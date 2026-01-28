import Foundation
import SwiftUI

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
}
