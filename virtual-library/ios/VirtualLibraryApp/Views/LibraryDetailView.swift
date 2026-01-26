import SwiftUI
enum BookSortOption: String, CaseIterable {
    case title = "Nombre"
    case author = "Autor"
    case year = "Año"
}

struct LibraryDetailView: View {
    let library: LibraryModel
    @StateObject private var viewModel: LibraryDetailViewModel
    @State private var showVoiceSearch = false
    @State private var showAddMenu = false
    @State private var sortOption: BookSortOption = .title
    
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
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Menu {
                    ForEach(BookSortOption.allCases, id: \.self) { option in
                        Button(action: { sortOption = option }) {
                            HStack {
                                Text(option.rawValue)
                                if sortOption == option {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Label("Ordenar", systemImage: "arrow.up.arrow.down")
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showVoiceSearch = true }) {
                        Label("Búsqueda por voz", systemImage: "mic.circle.fill")
                    }
                    
                    NavigationLink(destination: ScanIsbnView()) {
                        Label("Escanear ISBN", systemImage: "barcode.viewfinder")
                    }
                    
                    NavigationLink(destination: MultiBookScanView(libraryId: library.id)) {
                        Label("Escanear cubiertas", systemImage: "camera.viewfinder")
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
            }
        }
        .sheet(isPresented: $showVoiceSearch) {
            VoiceSearchView(libraryId: library.id) {
                Task {
                    await viewModel.refresh()
                }
            }
        }
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
            
            Text("Agrega libros usando voz, escáner o ISBN")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // Quick action buttons
            VStack(spacing: 12) {
                Button(action: { showVoiceSearch = true }) {
                    HStack {
                        Image(systemName: "mic.circle.fill")
                        Text("Búsqueda por voz")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
                
                HStack(spacing: 12) {
                    NavigationLink(destination: ScanIsbnView()) {
                        HStack {
                            Image(systemName: "barcode.viewfinder")
                            Text("ISBN")
                        }
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    
                    NavigationLink(destination: MultiBookScanView(libraryId: library.id)) {
                        HStack {
                            Image(systemName: "camera.viewfinder")
                            Text("Escanear")
                        }
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(12)
                    }
                }
            }
            .padding(.horizontal, 40)
            .padding(.top, 10)
        }
        .padding()
    }
        var sortedBooks: [Book] {
        switch sortOption {
        case .title:
            return viewModel.books.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .author:
            return viewModel.books.sorted { book1, book2 in
                let author1 = book1.authors.first ?? ""
                let author2 = book2.authors.first ?? ""
                return author1.localizedCaseInsensitiveCompare(author2) == .orderedAscending
            }
        case .year:
            return viewModel.books.sorted { book1, book2 in
                let year1 = book1.publishedDate ?? ""
                let year2 = book2.publishedDate ?? ""
                return year1.compare(year2) == .orderedDescending
            }
        }
    }
        var booksList: some View {
        List {
            ForEach(sortedBooks) { book in
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
