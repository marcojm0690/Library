import SwiftUI

/// Main home screen of the Virtual Library app.
/// Provides navigation to ISBN scanning and cover scanning features.
struct HomeView: View {
    @EnvironmentObject var authService: AuthenticationService
    @State private var showCreateLibrary = false
    @State private var showVoiceSearch = false
    @State private var showLibraryPicker = false
    @StateObject private var librariesViewModel = LibrariesListViewModel()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 25) {
                // App header
                VStack(spacing: 10) {
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    // Welcome message with user name
                    if let userName = authService.user?.fullName {
                        Text("¡Bienvenido!")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text(userName)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    } else {
                        Text("Biblioteca Virtual")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                    }
                    
                    Text("Identifica y agrega libros a tu biblioteca")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 10)
                
                // Quick Voice Search Action
                Button(action: {
                    Task {
                        if let userId = authService.user?.id {
                            await librariesViewModel.loadLibraries(for: userId)
                        }
                    }
                    showLibraryPicker = true
                }) {
                    HStack {
                        Image(systemName: "mic.circle.fill")
                            .font(.system(size: 32))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Búsqueda por voz")
                                .font(.title3)
                                .fontWeight(.semibold)
                            Text("Di el nombre del libro")
                                .font(.caption)
                                .opacity(0.9)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(15)
                    .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .padding(.horizontal, 10
                )
                
            
                // Navigation options
                VStack(alignment: .leading, spacing: 12) {
                    Text("Agregar libros")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                    
                    VStack(spacing: 12) {
                        NavigationLink(destination: ScanIsbnView()) {
                            CompactFeatureButton(
                                icon: "barcode.viewfinder",
                                title: "Escanear ISBN",
                                description: "Código de barras",
                                color: .blue
                            )
                        }
                        
                        NavigationLink(destination: LibrarySelectionForScanView()) {
                            CompactFeatureButton(
                                icon: "camera.viewfinder",
                                title: "Escanear cubierta",
                                description: "Múltiples libros",
                                color: .green
                            )
                        }
                    }
                    .padding(.horizontal, 15)
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    Text("Bibliotecas")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 15)
                    
                    VStack(spacing: 12) {
                        NavigationLink(destination: LibrariesListView()) {
                            CompactFeatureButton(
                                icon: "books.vertical.fill",
                                title: "Ver bibliotecas",
                                description: "Explora tus colecciones",
                                color: .orange
                            )
                        }
                        
                        Button(action: {
                            showCreateLibrary = true
                        }) {
                            CompactFeatureButton(
                                icon: "plus.rectangle.on.folder.fill",
                                title: "Crear biblioteca",
                                description: "Nueva colección",
                                color: .purple
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        authService.signOut()
                    }) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .sheet(isPresented: $showCreateLibrary) {
                CreateLibraryView()
                    .environmentObject(authService)
            }
            .sheet(isPresented: $showLibraryPicker) {
                LibraryPickerForVoiceSearchView(
                    libraries: librariesViewModel.libraries,
                    onLibrarySelected: { library in
                        showLibraryPicker = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showVoiceSearch = true
                        }
                    }
                )
            }
            .sheet(isPresented: $showVoiceSearch) {
                if let library = librariesViewModel.libraries.first {
                    VoiceSearchView(libraryId: library.id) {
                        // Refresh if needed
                    }
                }
            }
            .task {
                if let userId = authService.user?.id {
                    await librariesViewModel.loadLibraries(for: userId)
                }
            }
        }
    }
}

/// Compact button component for feature navigation
struct CompactFeatureButton: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

/// Library picker for voice search
struct LibraryPickerForVoiceSearchView: View {
    let libraries: [LibraryModel]
    let onLibrarySelected: (LibraryModel) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List(libraries) { library in
                Button(action: {
                    onLibrarySelected(library)
                }) {
                    HStack {
                        Image(systemName: "books.vertical.fill")
                            .foregroundColor(.blue)
                        Text(library.name)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Selecciona biblioteca")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthenticationService())
}
