import SwiftUI

/// View to display quote verification results
struct QuoteResultView: View {
    let result: QuoteVerificationResponse
    let onAddToLibrary: ((Book) -> Void)?
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    private var isCompact: Bool {
        horizontalSizeClass == .compact || verticalSizeClass == .compact
    }
    
    var body: some View {
        VStack(spacing: isCompact ? 16 : 20) {
            // Verification status header
            verificationHeader
            
            // Confidence meter
            confidenceMeter
            
            // Context section
            if let context = result.context {
                contextSection(context)
            }
            
            // Possible sources
            if !result.possibleSources.isEmpty {
                sourcesSection
            }
            
            // Recommended book action
            if let book = result.recommendedBook {
                recommendedBookSection(book)
            }
        }
        .padding(isCompact ? 16 : 20)
        .background(Color(.systemBackground))
        .cornerRadius(isCompact ? 12 : 16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Verification Header
    
    private var verificationHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: result.isVerified ? "checkmark.seal.fill" : "questionmark.circle.fill")
                .font(.system(size: isCompact ? 32 : 40))
                .foregroundColor(result.isVerified ? .green : .orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(result.isVerified ? "Cita Verificada" : "Verificación Parcial")
                    .font(isCompact ? .headline : .title3)
                    .fontWeight(.bold)
                
                if let author = result.claimedAuthor {
                    HStack(spacing: 6) {
                        Image(systemName: result.authorVerified ? "person.fill.checkmark" : "person.fill.questionmark")
                            .font(.caption)
                        Text("Autor: \(author)")
                            .font(.subheadline)
                        Text(result.authorVerified ? "✓" : "?")
                            .fontWeight(.bold)
                            .foregroundColor(result.authorVerified ? .green : .orange)
                    }
                    .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
    }
    
    // MARK: - Confidence Meter
    
    private var confidenceMeter: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Nivel de confianza")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(Int(result.overallConfidence * 100))%")
                    .font(isCompact ? .body : .headline)
                    .fontWeight(.bold)
                    .foregroundColor(confidenceColor)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(height: isCompact ? 12 : 16)
                    
                    // Progress
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [confidenceColor.opacity(0.7), confidenceColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * result.overallConfidence, height: isCompact ? 12 : 16)
                        .animation(.spring(), value: result.overallConfidence)
                }
            }
            .frame(height: isCompact ? 12 : 16)
            
            Text(confidenceDescription)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
    
    private var confidenceColor: Color {
        if result.overallConfidence >= 0.8 {
            return .green
        } else if result.overallConfidence >= 0.5 {
            return .orange
        } else {
            return .red
        }
    }
    
    private var confidenceDescription: String {
        if result.overallConfidence >= 0.8 {
            return "Alta confianza - La cita parece ser auténtica"
        } else if result.overallConfidence >= 0.5 {
            return "Confianza media - Puede requerir verificación adicional"
        } else {
            return "Baja confianza - La cita puede ser inexacta o falsa"
        }
    }
    
    // MARK: - Context Section
    
    private func contextSection(_ context: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Contexto", systemImage: "info.circle.fill")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.blue)
            
            Text(context)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.05))
        .cornerRadius(10)
    }
    
    // MARK: - Sources Section
    
    private var sourcesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Fuentes Posibles", systemImage: "book.fill")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            ForEach(result.possibleSources.prefix(3)) { source in
                SourceCard(source: source, isCompact: isCompact)
            }
        }
    }
    
    // MARK: - Recommended Book Section
    
    private func recommendedBookSection(_ book: Book) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Libro Recomendado")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                // Book cover or placeholder
                if let coverUrl = book.coverImageUrl, let url = URL(string: coverUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .overlay(Image(systemName: "book.fill").foregroundColor(.gray))
                    }
                    .frame(width: isCompact ? 60 : 80, height: isCompact ? 90 : 120)
                    .cornerRadius(8)
                } else {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(width: isCompact ? 60 : 80, height: isCompact ? 90 : 120)
                        .cornerRadius(8)
                        .overlay(Image(systemName: "book.fill").foregroundColor(.gray))
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(book.title)
                        .font(isCompact ? .subheadline : .body)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                    
                    Text(book.authorsDisplay)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    if let year = book.publishYear {
                        Text("\(year)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if let addToLibrary = onAddToLibrary {
                        Button(action: {
                            addToLibrary(book)
                        }) {
                            Label("Agregar a Por Leer", systemImage: "plus.circle.fill")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }
}

// MARK: - Source Card

struct SourceCard: View {
    let source: QuoteSource
    let isCompact: Bool
    
    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(source.book.title)
                    .font(isCompact ? .subheadline : .body)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                Text(source.book.authorsDisplay)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Label(source.source, systemImage: "globe")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text(source.matchType)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(spacing: 4) {
                Text("\(Int(source.confidence * 100))%")
                    .font(isCompact ? .caption : .subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(confidenceColor(source.confidence))
                
                Image(systemName: confidenceIcon(source.confidence))
                    .font(.caption)
                    .foregroundColor(confidenceColor(source.confidence))
            }
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private func confidenceColor(_ confidence: Double) -> Color {
        if confidence >= 0.8 {
            return .green
        } else if confidence >= 0.5 {
            return .orange
        } else {
            return .red
        }
    }
    
    private func confidenceIcon(_ confidence: Double) -> String {
        if confidence >= 0.8 {
            return "checkmark.circle.fill"
        } else if confidence >= 0.5 {
            return "exclamationmark.triangle.fill"
        } else {
            return "xmark.circle.fill"
        }
    }
}

#Preview {
    ScrollView {
        QuoteResultView(
            result: QuoteVerificationResponse(
                originalQuote: "I think, therefore I am",
                claimedAuthor: "René Descartes",
                isVerified: true,
                authorVerified: true,
                overallConfidence: 0.95,
                inputMethod: "text",
                possibleSources: [
                    QuoteSource(
                        book: Book(
                            id: UUID(),
                            isbn: nil,
                            title: "Discourse on Method",
                            authors: ["René Descartes"],
                            publisher: "Philosophy Press",
                            publishYear: 1637,
                            coverImageUrl: nil,
                            description: "A philosophical treatise",
                            pageCount: 200,
                            source: "Google Books"
                        ),
                        confidence: 0.95,
                        matchType: "Description Match",
                        source: "Google Books"
                    )
                ],
                context: "This quote appears to be from \"Discourse on Method\" by René Descartes...",
                recommendedBook: nil
            ),
            onAddToLibrary: nil
        )
        .padding()
    }
}
