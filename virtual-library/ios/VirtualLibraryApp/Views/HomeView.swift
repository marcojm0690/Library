import SwiftUI

/// Main home screen of the Virtual Library app.
/// Provides navigation to ISBN scanning and cover scanning features.
struct HomeView: View {
    @EnvironmentObject var authService: AuthenticationService
    @State private var showCreateLibrary = false
    @State private var showVoiceSearch = false
    @State private var showLibraryPicker = false
    @State private var showQuoteVerification = false
    @StateObject private var librariesViewModel = LibrariesListViewModel()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // App header
                    VStack(spacing: 10) {
                        Image(systemName: "books.vertical.fill")
                            .font(.system(size: 40))
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
                .padding(.horizontal, 10)
                
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
                        
                        Button(action: {
                            showQuoteVerification = true
                        }) {
                            CompactFeatureButton(
                                icon: "quote.bubble.fill",
                                title: "Verificar Cita",
                                description: "Autenticidad y fuentes",
                                color: .indigo
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 20)
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
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            showVoiceSearch = true
                        }
                    },
                    selectedLibrary: librariesViewModel.libraries.first
                )
            }
            .sheet(isPresented: $showVoiceSearch) {
                if let library = librariesViewModel.libraries.first {
                    VoiceSearchView(
                        libraryId: library.id,
                        userId: authService.user?.id,
                        onBookAdded: {
                            // Refresh if needed
                        }
                    )
                    .environmentObject(authService)
                }
            }
            .sheet(isPresented: $showQuoteVerification) {
                QuoteVerificationView(userId: authService.user?.id)
                    .environmentObject(authService)
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
    let selectedLibrary: LibraryModel?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                if libraries.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "books.vertical")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No tienes bibliotecas")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        Text("Crea una biblioteca primero")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(libraries) { library in
                        Button(action: {
                            onLibrarySelected(library)
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "books.vertical.fill")
                                    .foregroundColor(.blue)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(library.name)
                                        .foregroundColor(.primary)
                                        .fontWeight(.medium)
                                    if let description = library.description {
                                        Text(description)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                                if library.id == selectedLibrary?.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
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
