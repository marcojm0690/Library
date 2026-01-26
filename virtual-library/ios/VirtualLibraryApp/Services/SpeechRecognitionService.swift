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
    
    private var analyzer: SpeechAnalyzer?
    private var transcriber: SpeechTranscriber?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var analysisTask: Task<Void, Never>?
    private var resultsTask: Task<Void, Never>?
    private var currentTranscription = ""
    private var timeoutTask: Task<Void, Never>?
    private let audioEngine = AVAudioEngine()
    
    // Timeout after silence (in seconds)
    private let silenceTimeout: TimeInterval = 2.0
    
    // MARK: - Initialization
    
    override init() {
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
    
    /// Start listening and transcribing speech using modern SpeechAnalyzer API
    /// - Parameter completion: Called when user stops speaking or timeout occurs
    func startListening(completion: @escaping (Result<String, Error>) -> Void) {
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
        self.errorMessage = nil
        self.isListening = true
        
        // Start transcription with new API
        analysisTask = Task { @MainActor in
            await self.performTranscription(completion: completion)
        }
    }
    
    /// Perform transcription using SpeechTranscriber directly (iOS 26+)
    @MainActor
    private func performTranscription(completion: @escaping (Result<String, Error>) -> Void) async {
        do {
            // Step 1: Get supported locale
            guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale.current) else {
                throw NSError(
                    domain: "SpeechRecognition",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Locale not supported for transcription"]
                )
            }
            
            // Step 2: Create transcriber with vocabulary hints
            let transcriber = SpeechTranscriber(
                locale: locale,
                preset: .timeIndexedProgressiveTranscription
            )
            
            self.transcriber = transcriber
            
            // Step 3: Check and download assets if needed
            if let installationRequest = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                try await installationRequest.downloadAndInstall()
            }
            
            // Step 4: Create input sequence for analyzer
            let (inputSequence, inputBuilder) = AsyncStream.makeStream(of: AnalyzerInput.self)
            self.inputContinuation = inputBuilder
            
            // Step 5: Create analyzer with transcriber module
            let analyzer = SpeechAnalyzer(modules: [transcriber])
            self.analyzer = analyzer
            
            // Step 6: Start analysis task - feed inputs to analyzer by analyzing the sequence
            analysisTask = Task {
                await analyzer.analyze(on: inputSequence)
                print("🎤 Input sequence finished")
            }
            
            // Step 7: Process results
            self.currentTranscription = ""
            var lastUpdateTime = Date()
            
            resultsTask = Task { @MainActor in
                do {
                    for try await result in transcriber.results {
                        let transcription = String(result.text.characters)
                        self.transcribedText = transcription
                        self.currentTranscription = transcription
                        print("🎤 Transcription: \(transcription)")
                        
                        // Reset timeout on each update
                        self.timeoutTask?.cancel()
                        self.startSilenceTimeout()
                    }
                } catch is CancellationError {
                    print("⚠️ Results cancelled")
                } catch {
                    print("❌ Results error: \(error)")
                }
            }
            
            // Step 8: Supply audio to analyzer
            self.supplyAudio(to: inputBuilder)
            
            print("🎤 Started listening...")
            
            // Wait for results
            await resultsTask?.value
            
            self.isListening = false
            print("✅ Final transcription: \(self.currentTranscription)")
            completion(.success(self.currentTranscription))
            
        } catch {
            print("❌ Transcription error: \(error)")
            self.isListening = false
            self.errorMessage = error.localizedDescription
            completion(.failure(error))
        }
    }
    
    /// Supply audio buffers to the analyzer
    /// Always install the tap using the input node's native format to avoid format mismatch.
    @MainActor
    private func supplyAudio(to inputBuilder: AsyncStream<AnalyzerInput>.Continuation) {
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        // Install audio tap using the input node's native format
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }
            Task { @MainActor in
                let input = AnalyzerInput(buffer: buffer)
                inputBuilder.yield(input)
            }
        }
        
        // Start audio engine
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            print("❌ Audio engine error: \(error)")
            inputBuilder.finish()
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
    
    /// Convert an AVAudioPCMBuffer to a target format using AVAudioConverter
    
    /// Stop listening and return final transcription
    func stopListening() {
        // Cancel timeout
        timeoutTask?.cancel()
        timeoutTask = nil
        
        // Stop audio engine first
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
            print("🛑 Stopped listening")
        }
        
        // Finish audio input to signal end
        inputContinuation?.finish()
        inputContinuation = nil
        
        // Let the analyzer finish gracefully by cancelling the task
        // This will trigger the CancellationError handling which returns current transcription
        analysisTask?.cancel()
    }
    
    /// Cancel current recognition task
    func cancelListening() {
        // Cancel timeout
        timeoutTask?.cancel()
        timeoutTask = nil
        
        // Finish input
        inputContinuation?.finish()
        inputContinuation = nil
        
        // Cancel all tasks
        analysisTask?.cancel()
        resultsTask?.cancel()
        analysisTask = nil
        resultsTask = nil
        
        // Stop audio engine
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        self.isListening = false
        self.transcribedText = ""
        self.errorMessage = nil
        
        print("❌ Cancelled listening")
    }
    
    // MARK: - Utility
    
    /// Check if speech recognition is available and authorized
    var isAvailable: Bool {
        authorizationStatus == .authorized
    }
}
