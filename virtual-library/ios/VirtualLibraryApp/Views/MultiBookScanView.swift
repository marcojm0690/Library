import SwiftUI
import AVFoundation

struct MultiBookScanView: View {
    @StateObject private var viewModel: MultiBookScanViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var scanMode: ScanMode = .imageBased
    @State private var showModeSelector = false
    let libraryId: UUID
    
    init(libraryId: UUID) {
        self.libraryId = libraryId
        let apiService = BookApiService(baseURL: "https://virtual-library-api-web.azurewebsites.net")
        _viewModel = StateObject(wrappedValue: MultiBookScanViewModel(apiService: apiService))
    }
    
    var body: some View {
        cameraView
            .onAppear {
                viewModel.setScanMode(scanMode)
                viewModel.startScanning()
            }
            .onDisappear {
                viewModel.stopScanning()
            }
            .onChange(of: scanMode) { _, newMode in
                viewModel.setScanMode(newMode)
            }
            .sheet(isPresented: $showModeSelector) {
                ModeSelectorSheet(selectedMode: $scanMode, onDismiss: { showModeSelector = false })
                    .presentationDetents([.height(280)])
                    .presentationDragIndicator(.visible)
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
            .overlay(instructionsOverlay)
    }
    
    private var cameraView: some View {
        ZStack {
            MultiBookCameraPreview(session: viewModel.getCameraSession())
                .edgesIgnoringSafeArea(.all)
            
            rectangleOverlaysView
            contentOverlay
        }
    }
    
    private var rectangleOverlaysView: some View {
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
    }
    
    private var contentOverlay: some View {
        VStack {
            topBarView
            Spacer()
            colorLegendView
            detectedBooksView
        }
    }
    
    private var topBarView: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding()
                    .background(Circle().fill(Color.black.opacity(0.6)))
            }
            
            Spacer()
            
            Button(action: { showModeSelector.toggle() }) {
                HStack(spacing: 6) {
                    Image(systemName: scanMode == .imageBased ? "camera.fill" : "text.viewfinder")
                        .font(.callout)
                    Text(scanMode == .imageBased ? "Imagen" : "Texto")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.8))
                .cornerRadius(20)
            }
            
            Spacer()
            
            statusIndicator
        }
        .padding()
    }
    
    private var statusIndicator: some View {
        HStack(spacing: 8) {
            if viewModel.isProcessing {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }
            
            if !viewModel.rectangleOverlays.isEmpty {
                Text("\(viewModel.rectangleOverlays.count) rect")
                    .font(.caption)
                    .foregroundColor(.white)
            }
        }
        .padding()
        .background(Circle().fill(Color.black.opacity(0.6)))
    }
    
    private var colorLegendView: some View {
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
    }
    
    @ViewBuilder
    private var detectedBooksView: some View {
        if !viewModel.detectedBooks.isEmpty {
            VStack(spacing: 0) {
                detectedBooksHeader
                detectedBooksScrollView
            }
            .frame(maxHeight: 280)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
    
    private var detectedBooksHeader: some View {
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
    }
    
    private var detectedBooksScrollView: some View {
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
    
    private var instructionsOverlay: some View {
        VStack {
            Spacer()
            if viewModel.detectedBooks.isEmpty {
                instructionsContent
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(10)
                    .padding(.bottom, 100)
            }
        }
    }
    
    @ViewBuilder
    private var instructionsContent: some View {
        VStack(spacing: 8) {
            if viewModel.rectangleOverlays.isEmpty {
                VStack(spacing: 4) {
                    Text(scanMode == .imageBased ? "Apunta la cámara a las portadas de libros" : "Apunta la cámara al texto de las portadas")
                        .font(.headline)
                    Text(scanMode == .imageBased ? "Modo: Reconocimiento de imagen" : "Modo: Extracción de texto")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(spacing: 4) {
                    Text("Detectando rectángulos...")
                        .font(.headline)
                    Text("\(viewModel.rectangleOverlays.count) forma(s) detectada(s)")
                        .font(.caption)
                    Text(scanMode == .imageBased ? "Procesando imágenes..." : "Extrayendo texto...")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
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

