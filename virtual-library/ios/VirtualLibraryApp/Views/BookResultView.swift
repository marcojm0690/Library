import SwiftUI

/// View displaying detailed information about a book.
/// Shows all available book metadata in a clean, readable format.
struct BookResultView: View {
    let book: Book
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Cover image
                if let coverUrl = book.coverImageUrl, let url = URL(string: coverUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
                    .cornerRadius(10)
                    .shadow(radius: 5)
                } else {
                    Image(systemName: "book.fill")
                        .font(.system(size: 100))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(10)
                }
                
                // Book details
                VStack(alignment: .leading, spacing: 15) {
                    // Title
                    Text(book.title)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    // Authors
                    if !book.authors.isEmpty {
                        HStack(alignment: .top) {
                            Label("Authors", systemImage: "person.fill")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .frame(width: 100, alignment: .leading)
                            
                            Text(book.authorsDisplay)
                                .font(.body)
                        }
                    }
                    
                    // ISBN
                    if let isbn = book.isbn {
                        HStack(alignment: .top) {
                            Label("ISBN", systemImage: "barcode")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .frame(width: 100, alignment: .leading)
                            
                            Text(isbn)
                                .font(.body)
                        }
                    }
                    
                    // Publisher and Year
                    if book.publisher != nil || book.publishYear != nil {
                        HStack(alignment: .top) {
                            Label("Published", systemImage: "building.2")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .frame(width: 100, alignment: .leading)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                if let publisher = book.publisher {
                                    Text(publisher)
                                }
                                if let year = book.publishYear {
                                    Text(String(year))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .font(.body)
                        }
                    }
                    
                    // Page count
                    if let pageCount = book.pageCount {
                        HStack(alignment: .top) {
                            Label("Pages", systemImage: "book.pages")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .frame(width: 100, alignment: .leading)
                            
                            Text("\(pageCount)")
                                .font(.body)
                        }
                    }
                    
                    // Source
                    if let source = book.source {
                        HStack(alignment: .top) {
                            Label("Source", systemImage: "network")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .frame(width: 100, alignment: .leading)
                            
                            Text(source)
                                .font(.body)
                        }
                    }
                    
                    // Description
                    if let description = book.description {
                        Divider()
                            .padding(.vertical, 5)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.headline)
                            
                            Text(description)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
            }
            .padding()
        }
        .navigationTitle("Book Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        BookResultView(book: Book(
            id: UUID(),
            isbn: "978-0-123456-78-9",
            title: "Sample Book Title",
            authors: ["John Doe", "Jane Smith"],
            publisher: "Sample Publisher",
            publishYear: 2024,
            coverImageUrl: nil,
            description: "This is a sample book description that would typically contain a synopsis of the book's content, themes, and key topics.",
            pageCount: 350,
            source: "GoogleBooks"
        ))
    }
}
