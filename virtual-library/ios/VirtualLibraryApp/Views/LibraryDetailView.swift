import SwiftUI

/// View to display books in a library
struct LibraryDetailView: View {
    let library: Library
    @StateObject private var viewModel: LibraryDetailViewModel
    
    init(library: Library) {
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
                NavigationLink(destination: BookDetailView(book: book)) {
                    BookRowView(book: book)
                }
            }
        }
    }
}

/// Row view for a book in the library
struct BookRowView: View {
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

/// Error view
struct ErrorView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            Text("Error")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding()
        }
    }
}
