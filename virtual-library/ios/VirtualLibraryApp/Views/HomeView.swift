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
                VStack(spacing: 24) {
                    // Compact header
                    VStack(spacing: 8) {
                        Image(systemName: "books.vertical.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                        
                        if let userName = authService.user?.fullName {
                            Text(userName)
                                .font(.title2)
                                .fontWeight(.bold)
                        } else {
                            Text("Biblioteca Virtual")
                                .font(.title3)
                                .fontWeight(.bold)
                        }
                    }
                    .padding(.top, 20)
                    
                    // Featured Voice Search
                    Button(action: {
                        Task {
                            if let userId = authService.user?.id {
                                await librariesViewModel.loadLibraries(for: userId)
                            }
                        }
                        showLibraryPicker = true
                    }) {
                        HStack(spacing: 16) {
                            Image(systemName: "mic.circle.fill")
                                .font(.system(size: 28))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Búsqueda por voz")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                Text("Di el nombre del libro")
                                    .font(.caption)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding(16)
                        .background(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .padding(.horizontal, 16)
                    .padding(.horizontal, 16)
                    
                    // Quick Actions Grid
                    VStack(spacing: 16) {
                        HStack(spacing: 12) {
                            NavigationLink(destination: ScanIsbnView()) {
                                QuickActionCard(
                                    icon: "barcode.viewfinder",
                                    title: "Escanear ISBN",
                                    color: .blue
                                )
                            }
                            
                            NavigationLink(destination: LibrarySelectionForScanView()) {
                                QuickActionCard(
                                    icon: "camera.viewfinder",
                                    title: "Escanear cubierta",
                                    color: .green
                                )
                            }
                        }
                        
                        HStack(spacing: 12) {
                            NavigationLink(destination: LibrariesListView()) {
                                QuickActionCard(
                                    icon: "books.vertical.fill",
                                    title: "Mis bibliotecas",
                                    color: .orange
                                )
                            }
                            
                            Button(action: {
                                showCreateLibrary = true
                            }) {
                                QuickActionCard(
                                    icon: "plus.rectangle.on.folder",
                                    title: "Crear biblioteca",
                                    color: .purple
                                )
                            }
                        }
                        
                        Button(action: {
                            showQuoteVerification = true
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "quote.bubble.fill")
                                    .font(.title3)
                                    .foregroundColor(.indigo)
                                Text("Verificar Cita")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(14)
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                        }
                    }
                    .padding(.horizontal, 16)
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

/// Quick action card for 2x2 grid
struct QuickActionCard: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 56, height: 56)
                
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)
            }
            
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

/// Compact button component for feature navigation (deprecated, kept for compatibility)
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

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(AuthenticationService())
    }
}
