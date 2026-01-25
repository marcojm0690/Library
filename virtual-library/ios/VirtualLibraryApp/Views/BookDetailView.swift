import SwiftUI

/// View to display full book details
struct BookDetailView: View {
    let book: Book
    let library: LibraryModel?
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteAlert = false
    @State private var isDeleting = false
    
    init(book: Book, library: LibraryModel? = nil) {
        self.book = book
        self.library = library
    }
    
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
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.2))
                            ProgressView()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 400)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(radius: 10)
                    .padding(.horizontal)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue.opacity(0.1))
                        Image(systemName: "book.fill")
                            .font(.system(size: 100))
                            .foregroundColor(.blue)
                    }
                    .frame(height: 400)
                    .padding(.horizontal)
                }
                
                // Book information
                VStack(alignment: .leading, spacing: 16) {
                    // Title
                    Text(book.title)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    // Authors
                    if !book.authors.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "person.fill")
                                .foregroundColor(.blue)
                            Text(book.authors.joined(separator: ", "))
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    // Details grid
                    VStack(alignment: .leading, spacing: 12) {
                        if let isbn = book.isbn {
                            DetailRow(label: "ISBN", value: isbn, icon: "barcode")
                        }
                        
                        if let publisher = book.publisher {
                            DetailRow(label: "Editorial", value: publisher, icon: "building.2")
                        }
                        
                        if let publishYear = book.publishYear {
                            DetailRow(label: "Año", value: "\(publishYear)", icon: "calendar")
                        }
                        
                        if let pageCount = book.pageCount {
                            DetailRow(label: "Páginas", value: "\(pageCount)", icon: "doc.text")
                        }
                        
                        if let source = book.source {
                            DetailRow(label: "Fuente", value: source, icon: "cloud")
                        }
                    }
                    
                    // Description
                    if let description = book.description, !description.isEmpty {
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "text.alignleft")
                                    .foregroundColor(.blue)
                                Text("Descripción")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                            }
                            
                            Text(description)
                                .font(.body)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding()
            }
            .padding(.vertical)
        }
        .navigationTitle("Detalle del libro")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if library != nil {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingDeleteAlert = true
                    } label: {
                        if isDeleting {
                            ProgressView()
                        } else {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                    .disabled(isDeleting)
                }
            }
        }
        .alert("Eliminar libro", isPresented: $showingDeleteAlert) {
            Button("Cancelar", role: .cancel) { }
            Button("Eliminar", role: .destructive) {
                Task {
                    await removeBookFromLibrary()
                }
            }
        } message: {
            Text("¿Estás seguro de que deseas eliminar este libro de la biblioteca?")
        }
    }
    
    private func removeBookFromLibrary() async {
        guard let library = library, let bookId = book.id else { return }
        
        isDeleting = true
        
        do {
            let apiService = BookApiService()
            try await apiService.removeBooksFromLibrary(libraryId: library.id, bookIds: [bookId])
            dismiss()
        } catch {
            print("❌ Failed to remove book: \(error)")
        }
        
        isDeleting = false
    }
}

/// Reusable detail row component
struct DetailRow: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.body)
            }
            
            Spacer()
        }
    }
}

#Preview {
    NavigationView {
        BookDetailView(book: Book(
            id: UUID(),
            isbn: "978-0-123456-78-9",
            title: "Sample Book",
            authors: ["Author Name"],
            publisher: "Publisher",
            publishYear: 2024,
            coverImageUrl: nil,
            description: "This is a sample book description that shows how the detail view looks with actual content.",
            pageCount: 350,
            source: "GoogleBooks"
        ))
    }
}
