import SwiftUI

/// Reusable card component for displaying book search results
/// Supports adding books to libraries with customizable actions
struct BookSearchResultCard: View {
    let book: Book
    let onAddToLibrary: () -> Void
    let onTap: (() -> Void)?
    
    @State private var isAdding = false
    @State private var showSuccess = false
    
    init(book: Book, onAddToLibrary: @escaping () -> Void, onTap: (() -> Void)? = nil) {
        self.book = book
        self.onAddToLibrary = onAddToLibrary
        self.onTap = onTap
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Book content
            HStack(alignment: .top, spacing: 12) {
                // Cover image
                if let coverUrl = book.coverImageUrl, let url = URL(string: coverUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            placeholderImage
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure:
                            placeholderImage
                        @unknown default:
                            placeholderImage
                        }
                    }
                    .frame(width: 60, height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(radius: 2)
                } else {
                    placeholderImage
                }
                
                // Book info
                VStack(alignment: .leading, spacing: 6) {
                    Text(book.title)
                        .font(.headline)
                        .lineLimit(2)
                    
                    if !book.authors.isEmpty {
                        Text(book.authors.joined(separator: ", "))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    HStack(spacing: 8) {
                        if let isbn = book.isbn {
                            Label(isbn, systemImage: "barcode")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        if let source = book.source {
                            Text(source)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .clipShape(Capsule())
                        }
                    }
                    
                    if let publishYear = book.publishYear {
                        Text("Published: \(publishYear)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding()
            .contentShape(Rectangle())
            .onTapGesture {
                onTap?()
            }
            
            // Action button
            Divider()
            
            Button(action: handleAddToLibrary) {
                HStack {
                    if showSuccess {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Added!")
                            .foregroundColor(.green)
                    } else if isAdding {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                        Text("Adding...")
                            .foregroundColor(.secondary)
                    } else {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                        Text("Add to Library")
                            .foregroundColor(.blue)
                    }
                }
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .disabled(isAdding || showSuccess)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - Placeholder Image
    
    private var placeholderImage: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.gray.opacity(0.2))
            .frame(width: 60, height: 90)
            .overlay(
                Image(systemName: "book.fill")
                    .foregroundColor(.gray.opacity(0.5))
                    .font(.title2)
            )
    }
    
    // MARK: - Actions
    
    private func handleAddToLibrary() {
        isAdding = true
        
        // Call the add action
        onAddToLibrary()
        
        // Show success state
        withAnimation {
            isAdding = false
            showSuccess = true
        }
        
        // Reset after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showSuccess = false
            }
        }
    }
}

// MARK: - Preview

struct BookSearchResultCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            BookSearchResultCard(
                book: Book(
                    id: UUID(),
                    isbn: "978-0-123456-78-9",
                    title: "The Great Gatsby",
                    authors: ["F. Scott Fitzgerald"],
                    publisher: "Scribner",
                    publishYear: 1925,
                    coverImageUrl: "https://covers.openlibrary.org/b/isbn/9780743273565-M.jpg",
                    description: "A novel set in the Jazz Age",
                    pageCount: 180,
                    source: "OpenLibrary"
                ),
                onAddToLibrary: {
                    print("Add to library")
                },
                onTap: {
                    print("Card tapped")
                }
            )
            .padding()
            
            BookSearchResultCard(
                book: Book(
                    id: UUID(),
                    isbn: nil,
                    title: "1984",
                    authors: ["George Orwell"],
                    publisher: nil,
                    publishYear: 1949,
                    coverImageUrl: nil,
                    description: nil,
                    pageCount: nil,
                    source: "GoogleBooks"
                ),
                onAddToLibrary: {
                    print("Add to library")
                }
            )
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
}
