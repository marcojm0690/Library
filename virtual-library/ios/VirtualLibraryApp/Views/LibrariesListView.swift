import SwiftUI

/// View to display user's libraries
struct LibrariesListView: View {
    @EnvironmentObject var authService: AuthenticationService
    @StateObject private var viewModel = LibrariesListViewModel()
    @State private var showCreateLibrary = false
    @State private var selectedTypeFilter: LibraryType?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }
    
    private var filteredLibraries: [LibraryModel] {
        if let filter = selectedTypeFilter {
            return viewModel.libraries.filter { $0.type == filter }
        }
        return viewModel.libraries
    }
    
    private func colorForType(_ type: LibraryType) -> Color {
        switch type {
        case .read: return .green
        case .toRead: return .blue
        case .reading: return .orange
        case .wishlist: return .purple
        case .favorites: return .red
        }
    }
    
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
        VStack(spacing: 0) {
            // Type filter
            if !viewModel.libraries.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: isCompact ? 8 : 12) {
                        FilterChip(
                            title: "Todas",
                            icon: "square.grid.2x2",
                            isSelected: selectedTypeFilter == nil,
                            color: .blue
                        ) {
                            selectedTypeFilter = nil
                        }
                        
                        ForEach(LibraryType.allCases) { type in
                            FilterChip(
                                title: type.displayName,
                                icon: type.icon,
                                isSelected: selectedTypeFilter == type,
                                color: colorForType(type)
                            ) {
                                selectedTypeFilter = type
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                .background(Color(.systemGroupedBackground))
            }
            
            List {
                ForEach(filteredLibraries) { library in
                    NavigationLink(destination: LibraryDetailView(library: library)) {
                        LibraryRowView(library: library)
                    }
                }
                .onDelete { indexSet in
                    Task {
                        for index in indexSet {
                            let library = filteredLibraries[index]
                            do {
                                try await viewModel.deleteLibrary(library)
                            } catch {
                                print("❌ Failed to delete library: \(error)")
                            }
                        }
                    }
                }
            }
        }
    }
}

/// Row view for a library
struct LibraryRowView: View {
    let library: LibraryModel
    
    private func colorForType(_ type: LibraryType) -> Color {
        switch type {
        case .read: return .green
        case .toRead: return .blue
        case .reading: return .orange
        case .wishlist: return .purple
        case .favorites: return .red
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Library type badge
                Label {
                    Text(library.name)
                        .font(.headline)
                } icon: {
                    Image(systemName: library.type.icon)
                        .foregroundColor(colorForType(library.type))
                }
                
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
                
                Text("•")
                    .foregroundColor(.secondary)
                    .font(.caption)
                
                Text(library.type.displayName)
                    .font(.caption)
                    .foregroundColor(colorForType(library.type))
                    .fontWeight(.medium)
                
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

/// Filter chip component
struct FilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? color : Color(.systemGray5))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
            .shadow(color: isSelected ? color.opacity(0.3) : Color.clear, radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationView {
        LibrariesListView()
            .environmentObject(AuthenticationService())
    }
}
