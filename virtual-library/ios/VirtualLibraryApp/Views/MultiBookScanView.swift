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
                    
                    // Status indicator
                    HStack(spacing: 8) {
                        if viewModel.isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        
                        // Show rectangle count
                        if !viewModel.rectangleOverlays.isEmpty {
                            Text("\(viewModel.rectangleOverlays.count) rect")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                    }
                    .padding()
                    .background(Circle().fill(Color.black.opacity(0.6)))
                }
                .padding()
                
                Spacer()
                
                // Color legend - always show when scanning
                HStack(spacing: 20) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 12, height: 12)
                        Text("Buscando")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 12, height: 12)
                        Text("Encontrado")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.6))
                .cornerRadius(20)
                .padding(.bottom, 8)
                
                // Detected books - compact cards at bottom
                if !viewModel.detectedBooks.isEmpty {
                    VStack(spacing: 0) {
                        // Header with count
                        HStack {
                            Text("Libros encontrados")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Text("\(viewModel.detectedBooks.filter { $0.isConfirmed }.count)/3")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.7))
                        
                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(viewModel.detectedBooks) { detectedBook in
                                    DetectedBookCard(
                                        detectedBook: detectedBook,
                                        onAdd: {
                                            Task {
                                                await viewModel.addBookToLibrary(detectedBook, libraryId: libraryId)
                                            }
                                        },
                                        onDismiss: {
                                            withAnimation {
                                                viewModel.removeDetection(detectedBook)
                                            }
                                        }
                                    )
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .bottom).combined(with: .opacity),
                                        removal: .opacity
                                    ))
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                        }
                        .background(Color.black.opacity(0.4))
                    }
                    .frame(maxHeight: 280)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
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
                if viewModel.detectedBooks.isEmpty {
                    VStack(spacing: 8) {
                        if viewModel.rectangleOverlays.isEmpty {
                            Text("Apunta la cámara a las portadas de libros")
                                .font(.headline)
                        } else {
                            Text("Detectando rectángulos...")
                                .font(.headline)
                            Text("\(viewModel.rectangleOverlays.count) forma(s) detectada(s)")
                                .font(.caption)
                        }
                    }
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
