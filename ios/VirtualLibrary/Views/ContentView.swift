import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = BookViewModel()
    @State private var showingScanner = false
    @State private var showingImagePicker = false
    @State private var showingManualEntry = false
    @State private var manualISBN = ""
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.isLoading {
                    ProgressView("Loading...")
                        .padding()
                }
                
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                }
                
                if let currentBook = viewModel.currentBook {
                    BookDetailView(book: currentBook)
                        .padding()
                }
                
                if !viewModel.books.isEmpty {
                    List(viewModel.books) { book in
                        BookRowView(book: book)
                            .onTapGesture {
                                viewModel.currentBook = book
                            }
                    }
                } else if !viewModel.isLoading && viewModel.errorMessage == nil {
                    VStack(spacing: 20) {
                        Image(systemName: "book.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No books scanned yet")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        Text("Scan a barcode or take a photo of a book cover to get started")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding()
                }
                
                Spacer()
                
                HStack(spacing: 20) {
                    Button(action: {
                        showingScanner = true
                    }) {
                        VStack {
                            Image(systemName: "barcode.viewfinder")
                                .font(.title)
                            Text("Scan Barcode")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    
                    Button(action: {
                        showingImagePicker = true
                    }) {
                        VStack {
                            Image(systemName: "camera.fill")
                                .font(.title)
                            Text("Scan Cover")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    
                    Button(action: {
                        showingManualEntry = true
                    }) {
                        VStack {
                            Image(systemName: "keyboard")
                                .font(.title)
                            Text("Manual Entry")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
                .padding()
            }
            .navigationTitle("Virtual Library")
            .sheet(isPresented: $showingScanner) {
                BarcodeScannerView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePickerView { image in
                    Task {
                        await viewModel.searchByCover(image: image)
                    }
                }
            }
            .alert("Enter ISBN", isPresented: $showingManualEntry) {
                TextField("ISBN", text: $manualISBN)
                Button("Cancel", role: .cancel) { }
                Button("Search") {
                    Task {
                        await viewModel.lookupBook(isbn: manualISBN)
                        manualISBN = ""
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
