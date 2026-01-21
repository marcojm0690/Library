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
                        cameraService.stopScanning()
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
        .onAppear {
            print("📱 ISBN Scanner view appeared")
        }
        .onDisappear {
            print("🚪 ISBN Scanner view disappeared - cleaning up camera")
            cameraService.stopScanning()
            viewModel.reset()
        }
    }
}

/// UIViewRepresentable wrapper for camera preview
struct CameraPreviewView: UIViewRepresentable {
    let cameraService: CameraService
    
    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        
        // Start camera scanning only once
        cameraService.startScanning { previewLayer in
            guard let previewLayer = previewLayer else {
                print("❌ Failed to get preview layer")
                return
            }
            
            DispatchQueue.main.async {
                view.setupPreviewLayer(previewLayer)
            }
        }
        
        return view
    }
    
    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        // Frame updates are handled by the view itself in layoutSubviews
    }
}

/// Custom UIView for camera preview that properly handles layout
class CameraPreviewUIView: UIView {
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupPreviewLayer(_ layer: AVCaptureVideoPreviewLayer) {
        // Remove any existing preview layers
        self.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        
        previewLayer = layer
        layer.frame = bounds
        layer.videoGravity = .resizeAspectFill
        self.layer.insertSublayer(layer, at: 0)
        
        print("✅ Camera preview layer setup with frame: \(bounds)")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Update preview layer frame whenever view bounds change
        if let previewLayer = previewLayer {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            previewLayer.frame = bounds
            CATransaction.commit()
            print("📐 Preview layer frame updated to: \(bounds)")
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
