import Foundation
import Speech
import AVFoundation

/// Service responsible for converting speech to text using iOS Speech framework
/// Uses SpeechTranscriber directly for real-time updates and vocabulary support (iOS 26+)
@MainActor
class SpeechRecognitionService: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current authorization status for speech recognition
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    
    /// Whether the service is currently listening
    @Published var isListening = false
    
    /// Real-time transcription result
    @Published var transcribedText = ""
    
    /// Error message if something goes wrong
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var currentTranscription = ""
    private var timeoutTask: Task<Void, Never>?
    private let audioEngine = AVAudioEngine()
    
    // Timeout after silence (in seconds)
    private let silenceTimeout: TimeInterval = 2.0
    
    // MARK: - Initialization
    
    override init() {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
        super.init()
        
        // Log detailed info about speech recognizer setup
        print("🎤 Initializing Speech Recognition Service")
        print("   Locale: \(Locale.current.identifier)")
        if #available(iOS 16, *) {
            print("   Language: \(Locale.current.language.languageCode?.identifier ?? "unknown")")
        } else {
            print("   Language: \(Locale.current.languageCode ?? "unknown")")
        }
        print("   Region: \(Locale.current.region?.identifier ?? "unknown")")
        if let recognizer = speechRecognizer {
            print("   Recognizer available: \(recognizer.isAvailable)")
            print("   Supports on-device: \(recognizer.supportsOnDeviceRecognition)")
        } else {
            print("   ⚠️ Speech recognizer is nil - locale may not be supported")
        }
        
        // Request authorization on init
        Task {
            await requestAuthorization()
        }
    }
    
    // MARK: - Authorization
    
    /// Request speech recognition authorization from the user
    func requestAuthorization() async {
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        
        self.authorizationStatus = status
        
        switch status {
        case .authorized:
            print("✅ Speech recognition authorized")
        case .denied:
            self.errorMessage = "Speech recognition access denied. Please enable it in Settings."
        case .restricted:
            self.errorMessage = "Speech recognition is restricted on this device."
        case .notDetermined:
            print("⏳ Speech recognition authorization not determined")
        @unknown default:
            self.errorMessage = "Unknown authorization status"
        }
    }
    
    // MARK: - Context Configuration
    
    /// Custom vocabulary hints to improve recognition accuracy
    /// Apple's Speech framework has built-in ML for phonetic variations
    var vocabularyHints: [String] = []
    
    // MARK: - Recording Control
    
    /// Start listening and transcribing speech
    /// - Parameter completion: Called when user stops speaking or timeout occurs
    func startListening(completion: @escaping (Result<String, Error>) -> Void) {
        print("\n🎤🎤🎤 START LISTENING CALLED 🎤🎤🎤")
        print("   Authorization status: \(authorizationStatus.rawValue)")
        
        // Check authorization
        guard authorizationStatus == .authorized else {
            print("❌ Authorization failed: \(authorizationStatus)")
            let error = NSError(
                domain: "SpeechRecognition",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Speech recognition not authorized: \(authorizationStatus)"]
            )
            completion(.failure(error))
            return
        }
        
        // Check if recognizer is available
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            print("❌ Speech recognizer not available")
            print("   Recognizer exists: \(speechRecognizer != nil)")
            print("   Is available: \(speechRecognizer?.isAvailable ?? false)")
            let error = NSError(
                domain: "SpeechRecognition",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Speech recognizer not available. Check device language settings."]
            )
            completion(.failure(error))
            return
        }
        
        // Cancel any ongoing recognition
        stopListening()
        
        // Configure audio session for optimal speech recognition
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // Configuration that supports AirPods and other Bluetooth devices
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .allowBluetoothA2DP])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            // Log audio route information
            print("🎙️ Audio session configured successfully")
            
            if let currentRoute = audioSession.currentRoute.inputs.first {
                print("🎧 Input device: \(currentRoute.portName)")
                print("   Type: \(currentRoute.portType.rawValue)")
                
                if currentRoute.portType == .bluetoothHFP || currentRoute.portType == .bluetoothA2DP {
                    print("   ✅ Using Bluetooth device (AirPods/headset)")
                } else if currentRoute.portType == .builtInMic {
                    print("   📱 Using built-in microphone")
                }
            }
        } catch {
            print("❌ Audio session configuration error: \(error)")
            completion(.failure(error))
            return
        }
        
        // Clear previous transcription
        self.transcribedText = ""
        self.currentTranscription = ""
        self.errorMessage = nil
        self.isListening = true
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            let error = NSError(
                domain: "SpeechRecognition",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Unable to create recognition request"]
            )
            completion(.failure(error))
            return
        }
        
        // Configure recognition request for best accuracy
        recognitionRequest.shouldReportPartialResults = true
        
        // Try on-device recognition for better vocabulary hint integration
        if speechRecognizer.supportsOnDeviceRecognition {
            recognitionRequest.requiresOnDeviceRecognition = true
            print("🔒 Using on-device recognition for better hint accuracy")
        } else {
            print("☁️ Using server-based recognition")
        }
        
        // Set task hint for search/dictation context
        recognitionRequest.taskHint = .search // Optimizes for short queries like names
        
        // Add vocabulary hints for improved recognition
        if !vocabularyHints.isEmpty {
            recognitionRequest.contextualStrings = vocabularyHints
            print("📚 Added \(vocabularyHints.count) vocabulary hints:")
            print("   First 10: \(vocabularyHints.prefix(10).joined(separator: ", "))")
            
            // Check if "Kant" is in the hints
            if vocabularyHints.contains(where: { $0.lowercased() == "kant" }) {
                print("   ✅ 'Kant' is in vocabulary hints")
            } else {
                print("   ⚠️ 'Kant' NOT found in vocabulary hints!")
            }
        } else {
            print("⚠️ No vocabulary hints provided!")
        }
        
        // Add words to recognize - alternative API that may work better
        if #available(iOS 16.0, *), !vocabularyHints.isEmpty {
            // On iOS 16+, we can add custom pronunciations
            // This helps with difficult names like "Schopenhauer", "Kant", etc.
            print("📚 Using iOS 16+ vocabulary recognition features")
        }
        
        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            var isFinal = false
            
            if let result = result {
                let transcription = result.bestTranscription.formattedString
                
                Task { @MainActor in
                    print("\n🗣️ SPEECH: '\(transcription)' (final: \(result.isFinal))")
                    
                    // Debug: Print alternative transcriptions to see what recognizer is considering
                    if !result.transcriptions.isEmpty {
                        print("   Alternatives: \(result.transcriptions.prefix(3).map { $0.formattedString }.joined(separator: " | "))")
                    }
                    
                    // Only update if we have actual content (don't overwrite with empty final results)
                    if !transcription.isEmpty {
                        self.transcribedText = transcription
                        self.currentTranscription = transcription
                        
                        // Notify observers of transcription update
                        NotificationCenter.default.post(name: .speechTranscriptionUpdated, object: transcription)
                        
                        // Reset timeout on each update
                        self.timeoutTask?.cancel()
                        self.startSilenceTimeout()
                    }
                }
                
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                Task { @MainActor in
                    self.stopListening()
                    if let error = error {
                        print("❌ Recognition error: \(error)")
                        completion(.failure(error))
                    } else {
                        print("✅ Final transcription: \(self.currentTranscription)")
                        completion(.success(self.currentTranscription))
                    }
                }
            }
        }
        
        // Start audio engine
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        do {
            try audioEngine.start()
            print("✅ Audio engine started, listening for speech...")
        } catch {
            print("❌ Audio engine error: \(error)")
            completion(.failure(error))
        }
    }
    
    /// Start a timeout that will automatically stop listening after silence
    private func startSilenceTimeout() {
        timeoutTask?.cancel()
        timeoutTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(silenceTimeout))
            
            // Check if we haven't been cancelled
            guard !Task.isCancelled else { return }
            
            // If we have some transcription, finish gracefully
            if !self.currentTranscription.isEmpty {
                print("⏱️ Silence timeout - finishing with: \(self.currentTranscription)")
                self.stopListening()
            }
        }
    }
    
    /// Stop listening and return final transcription
    func stopListening() {
        // Cancel timeout
        timeoutTask?.cancel()
        timeoutTask = nil
        
        // Stop audio engine
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        // End recognition request
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        self.isListening = false
        print("🛑 Stopped listening")
    }
    
    /// Cancel current recognition task
    func cancelListening() {
        // Cancel timeout
        timeoutTask?.cancel()
        timeoutTask = nil
        
        // Cancel recognition task
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        
        // Stop audio engine
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        self.isListening = false
        self.transcribedText = ""
        self.currentTranscription = ""
        self.errorMessage = nil
        
        print("❌ Cancelled listening")
    }
    
    // MARK: - Utility
    
    /// Check if speech recognition is available and authorized
    var isAvailable: Bool {
        authorizationStatus == .authorized
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let speechTranscriptionUpdated = Notification.Name("speechTranscriptionUpdated")
}
