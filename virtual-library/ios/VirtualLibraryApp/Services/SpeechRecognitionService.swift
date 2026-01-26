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
    var vocabularyHints: [String] = []
    
    // MARK: - Recording Control
    
    /// Start listening and transcribing speech
    /// - Parameter completion: Called when user stops speaking or timeout occurs
    func startListening(completion: @escaping (Result<String, Error>) -> Void) {
        print("\n🎤🎤🎤 START LISTENING CALLED 🎤🎤🎤")
        
        // Check authorization
        guard authorizationStatus == .authorized else {
            let error = NSError(
                domain: "SpeechRecognition",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Speech recognition not authorized"]
            )
            completion(.failure(error))
            return
        }
        
        // Check if recognizer is available
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            let error = NSError(
                domain: "SpeechRecognition",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Speech recognizer not available"]
            )
            completion(.failure(error))
            return
        }
        
        // Cancel any ongoing recognition
        stopListening()
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
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
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Add vocabulary hints if available
        if !vocabularyHints.isEmpty {
            recognitionRequest.contextualStrings = vocabularyHints
            print("📚 Added vocabulary hints: \(vocabularyHints)")
        }
        
        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            var isFinal = false
            
            if let result = result {
                let transcription = result.bestTranscription.formattedString
                
                Task { @MainActor in
                    print("\n🗣️ SPEECH: '\(transcription)' (final: \(result.isFinal))")
                    self.transcribedText = transcription
                    self.currentTranscription = transcription
                    
                    // Reset timeout on each update
                    self.timeoutTask?.cancel()
                    self.startSilenceTimeout()
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
