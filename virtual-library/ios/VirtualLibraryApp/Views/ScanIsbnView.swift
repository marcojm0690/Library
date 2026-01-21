import SwiftUI
import AVFoundation

/// View for scanning ISBN barcodes using the device camera.
/// Integrates with CameraService for barcode detection.
struct ScanIsbnView: View {
    @StateObject private var viewModel = ScanIsbnViewModel()
    @StateObject private var cameraService = CameraService()
    
    var body: some View {
        ZStack {
            // Camera preview
            if viewModel.isScanning {
                CameraPreviewView(cameraService: cameraService)
                    .edgesIgnoringSafeArea(.all)
                
                // Scanning overlay
                VStack {
                    Text("Point camera at ISBN barcode")
                        .font(.headline)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.top, 50)
                    
                    Spacer()
                    
                    Button("Cancel") {
                        viewModel.stopScanning()
                    }
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.bottom, 50)
                }
            } else {
                // Results or start screen
                VStack(spacing: 20) {
                    if viewModel.isLoading {
                        ProgressView("Looking up book...")
                            .padding()
                    } else if let book = viewModel.scannedBook {
                        BookResultView(book: book)
                    } else if let error = viewModel.error {
                        ErrorView(message: error)
                    } else {
                        // Start scanning button
                        VStack(spacing: 15) {
                            Image(systemName: "barcode.viewfinder")
                                .font(.system(size: 80))
                                .foregroundColor(.blue)
                            
                            Text("Scan ISBN Barcode")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("Position the barcode within the camera frame")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            Button(action: {
                                Task {
                                    if await cameraService.checkCameraPermission() {
                                        viewModel.startScanning()
                                    } else {
                                        viewModel.error = "Camera permission denied"
                                    }
                                }
                            }) {
                                Text("Start Scanning")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.blue)
                                    .cornerRadius(10)
                            }
                            .padding(.horizontal)
                        }
                        .padding()
                    }
                    
                    if viewModel.scannedBook != nil || viewModel.error != nil {
                        Button("Scan Another") {
                            viewModel.reset()
                        }
                        .padding()
                    }
                }
            }
        }
        .navigationTitle("ISBN Scanner")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: cameraService.scannedISBN) { oldValue, newValue in
            if let isbn = newValue {
                Task {
                    await viewModel.lookupBook(isbn: isbn)
                }
            }
        }
    }
}

/// UIViewRepresentable wrapper for camera preview
struct CameraPreviewView: UIViewRepresentable {
    let cameraService: CameraService
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        
        cameraService.startScanning { previewLayer in
            guard let previewLayer = previewLayer else { return }
            DispatchQueue.main.async {
                previewLayer.frame = view.bounds
                view.layer.addSublayer(previewLayer)
            }
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update preview layer frame if needed
        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            previewLayer.frame = uiView.bounds
        }
    }
}

/// Simple error display view
struct ErrorView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

#Preview {
    NavigationView {
        ScanIsbnView()
    }
}
