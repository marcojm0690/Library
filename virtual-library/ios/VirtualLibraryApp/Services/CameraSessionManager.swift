import AVFoundation
import UIKit

class CameraSessionManager: NSObject, ObservableObject {
    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private var isSessionConfigured = false
    
    var onFrameCaptured: ((CVPixelBuffer) -> Void)?
    
    override init() {
        super.init()
        // Don't setup session in init - wait for explicit start
    }
    
    private func setupSession() {
        guard !isSessionConfigured else { return }
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Check camera authorization first
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                break
            case .notDetermined:
                // Request permission synchronously on session queue
                var authorized = false
                let semaphore = DispatchSemaphore(value: 0)
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    authorized = granted
                    semaphore.signal()
                }
                semaphore.wait()
                
                guard authorized else {
                    print("❌ Camera access denied")
                    return
                }
            default:
                print("❌ Camera access not authorized")
                return
            }
            
            self.session.beginConfiguration()
            self.session.sessionPreset = .high
            
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice),
                  self.session.canAddInput(videoDeviceInput) else {
                print("❌ Failed to get camera device")
                self.session.commitConfiguration()
                return
            }
            
            self.session.addInput(videoDeviceInput)
            
            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera.frame.queue"))
            videoOutput.alwaysDiscardsLateVideoFrames = true
            
            // Set pixel format explicitly
            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            
            if self.session.canAddOutput(videoOutput) {
                self.session.addOutput(videoOutput)
                
                if let connection = videoOutput.connection(with: .video) {
                    connection.videoRotationAngle = 90
                }
            }
            
            self.session.commitConfiguration()
            self.isSessionConfigured = true
            print("✅ Camera session configured successfully")
        }
    }
    
    func startSession() {
        // Setup session first if not already configured
        if !isSessionConfigured {
            setupSession()
        }
        
        sessionQueue.async { [weak self] in
            guard let self = self, self.isSessionConfigured else { return }
            
            if !self.session.isRunning {
                self.session.startRunning()
                print("📹 Camera session started")
            }
        }
    }
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            if self.session.isRunning {
                self.session.stopRunning()
                print("📹 Camera session stopped")
            }
        }
    }
}

extension CameraSessionManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        onFrameCaptured?(pixelBuffer)
    }
}
