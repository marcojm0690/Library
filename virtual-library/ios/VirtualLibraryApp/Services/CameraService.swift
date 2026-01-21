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
    private var isSessionConfigured = false
    
    deinit {
        print("♻️ CameraService deallocated - cleaning up session")
        cleanup()
    }
    
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
        print("📸 Starting camera scanning...")
        
        // Prevent starting if already configured
        if isSessionConfigured, let existingLayer = previewLayer {
            print("⚠️ Camera session already running, returning existing layer")
            completion(existingLayer)
            return
        }
        
        guard let device = AVCaptureDevice.default(for: .video) else {
            let errorMsg = "No camera available"
            print("❌ \(errorMsg)")
            error = errorMsg
            completion(nil)
            return
        }
        
        print("✅ Camera device found: \(device.localizedName)")
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            let session = AVCaptureSession()
            
            session.beginConfiguration()
            
            if session.canAddInput(input) {
                session.addInput(input)
                print("✅ Camera input added")
            } else {
                print("❌ Cannot add camera input")
                completion(nil)
                return
            }
            
            let output = AVCaptureMetadataOutput()
            
            if session.canAddOutput(output) {
                session.addOutput(output)
                output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                // Support EAN-13 (ISBN-13) and EAN-8 barcodes
                output.metadataObjectTypes = [.ean13, .ean8]
                print("✅ Metadata output configured for barcode types: EAN-13, EAN-8")
            } else {
                print("❌ Cannot add metadata output")
                completion(nil)
                return
            }
            
            session.commitConfiguration()
            
            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.videoGravity = .resizeAspectFill
            
            self.captureSession = session
            self.previewLayer = previewLayer
            
            print("✅ Session configured, starting capture...")
            
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                session.startRunning()
                DispatchQueue.main.async {
                    self?.isSessionConfigured = true
                    print("✅ Camera session is running")
                }
            }
            
            completion(previewLayer)
        } catch {
            let errorMsg = "Failed to setup camera: \(error.localizedDescription)"
            print("❌ \(errorMsg)")
            self.error = errorMsg
            completion(nil)
        }
    }
    
    /// Stop the scanning session
    func stopScanning() {
        print("🛑 Stopping camera scanning...")
        cleanup()
    }
    
    /// Clean up camera resources
    private func cleanup() {
        if let session = captureSession, session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                session.stopRunning()
                // Remove all inputs and outputs
                session.inputs.forEach { session.removeInput($0) }
                session.outputs.forEach { session.removeOutput($0) }
                
                DispatchQueue.main.async {
                    self?.captureSession = nil
                    self?.previewLayer = nil
                    self?.scannedISBN = nil
                    self?.isSessionConfigured = false
                    print("✅ Camera session stopped and cleaned up")
                }
            }
        } else {
            captureSession = nil
            previewLayer = nil
            scannedISBN = nil
            isSessionConfigured = false
            print("✅ Camera session already stopped")
        }
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
        
        print("📷 Barcode detected: \(stringValue)")
        
        // Found a barcode - publish the result
        scannedISBN = stringValue
        stopScanning()
    }
}
