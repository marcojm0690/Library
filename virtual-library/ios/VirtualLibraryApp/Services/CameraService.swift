import AVFoundation
import UIKit

/// Service responsible for camera-based barcode scanning.
/// Uses AVFoundation to capture and decode ISBN barcodes.
class CameraService: NSObject, ObservableObject {
    /// Published result containing scanned ISBN
    @Published var scannedISBN: String?
    
    /// Published error message
    @Published var error: String?
    
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    /// Check if camera permission is granted
    func checkCameraPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }
    
    /// Start barcode scanning session
    /// - Parameter completion: Callback with the video preview layer
    func startScanning(completion: @escaping (AVCaptureVideoPreviewLayer?) -> Void) {
        guard let device = AVCaptureDevice.default(for: .video) else {
            error = "No camera available"
            completion(nil)
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            let session = AVCaptureSession()
            
            if session.canAddInput(input) {
                session.addInput(input)
            }
            
            let output = AVCaptureMetadataOutput()
            
            if session.canAddOutput(output) {
                session.addOutput(output)
                output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                // Support EAN-13 (ISBN-13) and EAN-8 barcodes
                output.metadataObjectTypes = [.ean13, .ean8]
            }
            
            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.videoGravity = .resizeAspectFill
            
            self.captureSession = session
            self.previewLayer = previewLayer
            
            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
            }
            
            completion(previewLayer)
        } catch {
            self.error = "Failed to setup camera: \(error.localizedDescription)"
            completion(nil)
        }
    }
    
    /// Stop the scanning session
    func stopScanning() {
        captureSession?.stopRunning()
        captureSession = nil
        previewLayer = nil
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate
extension CameraService: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let metadataObject = metadataObjects.first,
              let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
              let stringValue = readableObject.stringValue else {
            return
        }
        
        // Found a barcode - publish the result
        scannedISBN = stringValue
        stopScanning()
    }
}
