import SwiftUI
import AVFoundation

struct MultiBookScanView: View {
    @StateObject private var viewModel: MultiBookScanViewModel
    @Environment(\.dismiss) private var dismiss
    let libraryId: UUID
    
    init(libraryId: UUID) {
        self.libraryId = libraryId
        let apiService = BookApiService(baseURL: "https://virtual-library-api-web.azurewebsites.net")
        _viewModel = StateObject(wrappedValue: MultiBookScanViewModel(apiService: apiService))
    }
    
    var body: some View {
        ZStack {
            // Camera preview
            MultiBookCameraPreview(session: viewModel.getCameraSession())
                .edgesIgnoringSafeArea(.all)
            
            // Rectangle overlays with color coding
            GeometryReader { geometry in
                ForEach(viewModel.rectangleOverlays.indices, id: \.self) { index in
                    let overlay = viewModel.rectangleOverlays[index]
                    let rect = overlay.rect
                    let color: Color = overlay.hasBook ? .green : .red
                    
                    Rectangle()
                        .stroke(color, lineWidth: 3)
                        .frame(
                            width: rect.width * geometry.size.width,
                            height: rect.height * geometry.size.height
                        )
                        .position(
                            x: rect.midX * geometry.size.width,
                            y: (1 - rect.midY) * geometry.size.height
                        )
                        .animation(.easeInOut(duration: 0.3), value: overlay.hasBook)
                }
            }
            
            VStack {
                // Top bar
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding()
                            .background(Circle().fill(Color.black.opacity(0.6)))
                    }
                    
                    Spacer()
                    
                    if viewModel.isProcessing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .padding()
                            .background(Circle().fill(Color.black.opacity(0.6)))
                    }
                }
                .padding()
                
                Spacer()
                
                // Detected books
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(viewModel.detectedBooks) { detectedBook in
                            DetectedBookCard(
                                detectedBook: detectedBook,
                                onAdd: {
                                    Task {
                                        await viewModel.addBookToLibrary(detectedBook, libraryId: libraryId)
                                    }
                                },
                                onDismiss: {
                                    viewModel.removeDetection(detectedBook)
                                }
                            )
                        }
                    }
                    .padding()
                }
                .frame(maxHeight: 400)
            }
        }
        .onAppear {
            viewModel.startScanning()
        }
        .onDisappear {
            viewModel.stopScanning()
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
        .overlay(
            VStack {
                Spacer()
                if viewModel.detectedBooks.isEmpty && !viewModel.isProcessing {
                    Text("Apunta la cámara a las portadas de libros")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                        .padding(.bottom, 100)
                }
            }
        )
    }
}

struct MultiBookCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        context.coordinator.previewLayer = previewLayer
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = context.coordinator.previewLayer {
            DispatchQueue.main.async {
                previewLayer.frame = uiView.bounds
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}
