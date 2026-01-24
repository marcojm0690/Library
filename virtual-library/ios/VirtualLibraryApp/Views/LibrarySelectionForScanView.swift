import SwiftUI

struct LibrarySelectionForScanView: View {
    @EnvironmentObject var authService: AuthenticationService
    @ObservedObject private var viewModel = LibrariesListViewModel()
    
    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.libraries.isEmpty {
                ProgressView("Cargando bibliotecas...")
            } else if let error = viewModel.error {
                ErrorView(message: error)
            } else if viewModel.libraries.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "books.vertical")
                        .font(.system(size: 80))
                        .foregroundColor(.secondary)
                    
                    Text("No tienes bibliotecas")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Crea una biblioteca primero para usar la detección múltiple")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                .padding()
            } else {
                List {
                    Section(header: Text("Selecciona una biblioteca")) {
                        ForEach(viewModel.libraries) { library in
                            NavigationLink(destination: MultiBookScanView(libraryId: library.id)) {
                                HStack {
                                    Image(systemName: "book.closed.fill")
                                        .foregroundColor(.blue)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(library.name)
                                            .font(.headline)
                                        
                                        Text(library.description ?? "Sin descripción")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "camera.viewfinder")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Seleccionar biblioteca")
        .navigationBarTitleDisplayMode(.inline)
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
}
