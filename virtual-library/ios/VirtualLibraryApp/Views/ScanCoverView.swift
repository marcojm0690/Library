import SwiftUI
import PhotosUI

/// View for scanning book covers using OCR.
/// Allows user to take a photo or select from library, then processes with OCR.
struct ScanCoverView: View {
    @StateObject private var viewModel = ScanCoverViewModel()
    @State private var showImagePicker = false
    @State private var showCamera = false
    @State private var selectedImage: UIImage?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if viewModel.isProcessing {
                    // Processing state
                    VStack(spacing: 15) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Processing image...")
                            .font(.headline)
                        Text("Extracting text and searching...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    
                } else if !viewModel.searchResults.isEmpty {
                    // Results state
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Found \(viewModel.searchResults.count) match(es)")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        if let extractedText = viewModel.extractedText {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Extracted Text:")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                Text(extractedText)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(3)
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.horizontal)
                        }
                        
                        ForEach(viewModel.searchResults) { book in
                            NavigationLink(destination: BookResultView(book: book)) {
                                BookRowView(book: book)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    Button("Search Another") {
                        viewModel.reset()
                        selectedImage = nil
                    }
                    .padding()
                    
                } else if let error = viewModel.error {
                    // Error state
                    ErrorView(message: error)
                    
                    Button("Try Again") {
                        viewModel.reset()
                        selectedImage = nil
                    }
                    .padding()
                    
                } else {
                    // Initial state - show options
                    VStack(spacing: 20) {
                        Image(systemName: "doc.text.viewfinder")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                        
                        Text("Scan Book Cover")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Take a photo or select an image of a book cover")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        VStack(spacing: 15) {
                            Button(action: {
                                showCamera = true
                            }) {
                                Label("Take Photo", systemImage: "camera.fill")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.blue)
                                    .cornerRadius(10)
                            }
                            
                            Button(action: {
                                showImagePicker = true
                            }) {
                                Label("Choose from Library", systemImage: "photo.fill")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(10)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding()
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Cover Scanner")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $selectedImage, sourceType: .photoLibrary)
        }
        .sheet(isPresented: $showCamera) {
            ImagePicker(image: $selectedImage, sourceType: .camera)
        }
        .onChange(of: selectedImage) { _, newImage in
            if let image = newImage {
                Task {
                    await viewModel.processImage(image)
                }
            }
        }
    }
}

/// Row view for displaying a book in search results
struct BookRowView: View {
    let book: Book
    
    var body: some View {
        HStack(spacing: 15) {
            // Cover image placeholder
            if let coverUrl = book.coverImageUrl, let url = URL(string: coverUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray.opacity(0.3)
                }
                .frame(width: 60, height: 90)
                .cornerRadius(8)
            } else {
                Image(systemName: "book.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.gray)
                    .frame(width: 60, height: 90)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: 5) {
                Text(book.title)
                    .font(.headline)
                    .lineLimit(2)
                
                Text(book.authorsDisplay)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                if let year = book.publishYear {
                    Text(String(year))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

/// Image picker wrapper using UIKit
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let sourceType: UIImagePickerController.SourceType
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    NavigationView {
        ScanCoverView()
    }
}
