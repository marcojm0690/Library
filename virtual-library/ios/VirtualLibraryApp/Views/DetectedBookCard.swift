import SwiftUI

struct DetectedBookCard: View {
    let detectedBook: DetectedBook
    let onAdd: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let book = detectedBook.book {
                // Book details found
                HStack(alignment: .top, spacing: 12) {
                    if let coverUrl = book.coverImageUrl, let url = URL(string: coverUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } placeholder: {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                        }
                        .frame(width: 60, height: 90)
                        .cornerRadius(4)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(book.title)
                            .font(.headline)
                            .lineLimit(2)
                        
                        if !book.authors.isEmpty {
                            Text(book.authors.joined(separator: ", "))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        if let isbn = book.isbn {
                            Text("ISBN: \(isbn)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
                
                HStack {
                    Button("Descartar") {
                        onDismiss()
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("Agregar a Biblioteca") {
                        onAdd()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                // Only text detected, no book details yet
                VStack(alignment: .leading, spacing: 8) {
                    Text("Texto detectado:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(detectedBook.detectedText)
                        .font(.body)
                        .lineLimit(3)
                    
                    if let isbn = detectedBook.isbn {
                        Text("ISBN: \(isbn)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Buscando detalles del libro...")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.vertical, 4)
                    
                    ProgressView()
                        .scaleEffect(0.8)
                }
                
                Button("Descartar") {
                    onDismiss()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 8)
    }
}
