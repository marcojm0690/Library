import SwiftUI

/// View to display user's libraries
struct LibrariesListView: View {
    @EnvironmentObject var authService: AuthenticationService
    @StateObject private var viewModel = LibrariesListViewModel()
    @State private var showCreateLibrary = false
    
    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.libraries.isEmpty {
                ProgressView("Cargando bibliotecas...")
            } else if let error = viewModel.error {
                ErrorView(message: error)
            } else if viewModel.libraries.isEmpty {
                emptyStateView
            } else {
                librariesList
            }
        }
        .navigationTitle("Mis Bibliotecas")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showCreateLibrary = true
                }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showCreateLibrary, onDismiss: {
            // Refresh libraries when sheet is dismissed
            Task {
                if let userId = authService.user?.id {
                    await viewModel.refresh(for: userId)
                }
            }
        }) {
            CreateLibraryView()
                .environmentObject(authService)
        }
        .task {
            if let userId = authService.user?.id {
                await viewModel.loadLibraries(for: userId)
            }
        }
        .refreshable {
            if let userId = authService.user?.id {
                await viewModel.refresh(for: userId)
            }
        }
    }
    
    var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "books.vertical")
                .font(.system(size: 80))
                .foregroundColor(.secondary)
            
            Text("No tienes bibliotecas")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Crea tu primera biblioteca para comenzar")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: {
                showCreateLibrary = true
            }) {
                Label("Crear Biblioteca", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.top)
        }
        .padding()
    }
    
    var librariesList: some View {
        List {
            ForEach(viewModel.libraries) { library in
                NavigationLink(destination: LibraryDetailView(library: library)) {
                    LibraryRowView(library: library)
                }
            }
        }
    }
}

/// Row view for a library
struct LibraryRowView: View {
    let library: Library
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(library.name)
                    .font(.headline)
                
                Spacer()
                
                if library.isPublic {
                    Image(systemName: "globe")
                        .foregroundColor(.blue)
                        .font(.caption)
                } else {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            
            if let description = library.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            HStack {
                Label("\(library.bookCount) libros", systemImage: "book.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if !library.tags.isEmpty {
                    Spacer()
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(library.tags.prefix(3), id: \.self) { tag in
                                Text(tag)
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationView {
        LibrariesListView()
            .environmentObject(AuthenticationService())
    }
}
