import SwiftUI

/// View to display books in a library
struct LibraryDetailView: View {
    let library: LibraryModel
    @StateObject private var viewModel: LibraryDetailViewModel
    
    init(library: LibraryModel) {
        self.library = library
        _viewModel = StateObject(wrappedValue: LibraryDetailViewModel(libraryId: library.id))
    }
    
    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.books.isEmpty {
                ProgressView("Cargando libros...")
            } else if let error = viewModel.error {
                ErrorView(message: error)
            } else if viewModel.books.isEmpty {
                emptyStateView
            } else {
                booksList
            }
        }
        .navigationTitle(library.name)
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.loadBooks()
        }
        .refreshable {
            await viewModel.refresh()
        }
    }
    
    var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "books.vertical")
                .font(.system(size: 80))
                .foregroundColor(.secondary)
            
            Text("No hay libros en esta biblioteca")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Agrega libros escaneándolos")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    var booksList: some View {
        List {
            ForEach(viewModel.books) { book in
                NavigationLink(destination: BookDetailView(book: book, library: library)) {
                    LibraryBookRowView(book: book)
                }
            }
            .onDelete { indexSet in
                Task {
                    for index in indexSet {
                        let book = viewModel.books[index]
                        guard let bookId = book.id else { continue }
                        do {
                            try await viewModel.removeBook(bookId: bookId)
                        } catch {
                            print("❌ Failed to remove book: \(error)")
                        }
                    }
                }
            }
        }
    }
}

/// Row view for a book in the library
struct LibraryBookRowView: View {
    let book: Book
    
    var body: some View {
        HStack(spacing: 12) {
            // Cover image
            if let coverUrl = book.coverImageUrl, let url = URL(string: coverUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.2))
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }
                .frame(width: 50, height: 75)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                // Placeholder
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.blue.opacity(0.1))
                    Image(systemName: "book.fill")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
                .frame(width: 50, height: 75)
            }
            
            // Book info
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
                
                if let publisher = book.publisher {
                    Text(publisher)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}
