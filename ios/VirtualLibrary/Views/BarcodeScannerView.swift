import SwiftUI
import AVFoundation

struct BarcodeScannerView: View {
    @ObservedObject var viewModel: BookViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                CameraPreview(scanner: viewModel.scanner)
                    .edgesIgnoringSafeArea(.all)
                
                VStack {
                    Spacer()
                    
                    Text("Position the barcode within the frame")
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding()
                }
            }
            .navigationTitle("Scan Barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        viewModel.scanner.stopScanning()
                        dismiss()
                    }
                }
            }
            .onAppear {
                viewModel.scanner.startScanning()
            }
            .onDisappear {
                viewModel.scanner.stopScanning()
            }
            .onChange(of: viewModel.scanner.scannedCode) { oldValue, newValue in
                if newValue != nil {
                    dismiss()
                }
            }
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    let scanner: BarcodeScannerService
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        
        if let previewLayer = scanner.setupScanner() {
            previewLayer.frame = view.layer.bounds
            view.layer.addSublayer(previewLayer)
            
            // Store the layer in the context for later updates
            context.coordinator.previewLayer = previewLayer
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = context.coordinator.previewLayer {
            previewLayer.frame = uiView.layer.bounds
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}
