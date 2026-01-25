import Foundation
import Speech
import AVFoundation

/// Service responsible for converting speech to text using iOS Speech framework
/// Uses the modern SpeechAnalyzer API for improved accuracy and performance (iOS 26+)
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
    private let audioEngine = AVAudioEngine()
    
    // Keep track of analyzer’s preferred audio format (if any)
    private var desiredAnalyzerFormat: AVAudioFormat?
    private var bufferConverter: AVAudioConverter?
    
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
    
    /// Perform transcription using SpeechAnalyzer and SpeechTranscriber (iOS 26+)
    @MainActor
    private func performTranscription(completion: @escaping (Result<String, Error>) -> Void) async {
        do {
            // Step 1: Create transcriber module
            guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale.current) else {
                throw NSError(
                    domain: "SpeechRecognition",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Locale not supported for transcription"]
                )
            }
            
            let transcriber = SpeechTranscriber(locale: locale, preset: SpeechTranscriber.Preset.timeIndexedProgressiveTranscription)
            self.transcriber = transcriber
            
            // Step 2: Check and download assets if needed
            if let installationRequest = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                try await installationRequest.downloadAndInstall()
            }
            
            // Step 3: Create input sequence
            let (inputSequence, inputBuilder) = AsyncStream.makeStream(of: AnalyzerInput.self)
            self.inputContinuation = inputBuilder
            
            // Step 4: Create analyzer
            // Ask for the best available audio format, but DO NOT use it to install the tap directly.
            // We’ll install the tap with the input node’s format and convert if needed.
            let bestFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
            self.desiredAnalyzerFormat = bestFormat
            self.bufferConverter = nil // reset converter; will be created lazily if needed
            
            let analyzer = await SpeechAnalyzer(modules: [transcriber])
            self.analyzer = analyzer
            
            // Step 5: Start supplying audio (always from input node’s native format)
            self.supplyAudio(to: inputBuilder)
            
            // Step 7: Process results
            var finalTranscription = ""
            resultsTask = Task { @MainActor in
                do {
                    for try await result in transcriber.results {
                        let transcription = String(result.text.characters)
                        self.transcribedText = transcription
                        finalTranscription = transcription
                        print("🎤 Transcription: \(transcription)")
                    }
                } catch {
                    print("❌ Results error: \(error)")
                }
            }
            
            // Step 6: Perform analysis
            print("🎤 Started listening with SpeechAnalyzer...")
            let lastSampleTime = try await analyzer.analyzeSequence(inputSequence)
            
            // Step 8: Finish analysis
            if let lastSampleTime {
                try await analyzer.finalizeAndFinish(through: lastSampleTime)
            } else {
                try await analyzer.cancelAndFinishNow()
            }
            
            // Wait for results to complete
            await resultsTask?.value
            
            self.isListening = false
            print("✅ Final transcription: \(finalTranscription)")
            completion(.success(finalTranscription))
            
        } catch {
            print("❌ Transcription error: \(error)")
            self.isListening = false
            self.errorMessage = error.localizedDescription
            completion(.failure(error))
        }
    }
    
    /// Supply audio buffers to the analyzer
    /// Always install the tap using the input node’s output format to avoid format mismatch.
    @MainActor
    private func supplyAudio(to inputBuilder: AsyncStream<AnalyzerInput>.Continuation) {
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0) // e.g., 48kHz Float32 mono
        
        // Prepare converter if analyzer prefers a different format
        if let desired = desiredAnalyzerFormat, desired != inputFormat {
            bufferConverter = AVAudioConverter(from: inputFormat, to: desired)
            if bufferConverter == nil {
                print("⚠️ Could not create AVAudioConverter from \(inputFormat) to \(desired). Proceeding with input format.")
            } else {
                print("🔁 Using AVAudioConverter: \(inputFormat) -> \(desired)")
            }
        } else {
            bufferConverter = nil
        }
        
        // Install audio tap using the input node's native format
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }
            Task { @MainActor in
                if let converter = self.bufferConverter, let desired = self.desiredAnalyzerFormat {
                    // Convert buffer to the analyzer’s desired format
                    if let converted = self.convert(buffer: buffer, from: inputFormat, to: desired, using: converter) {
                        let input = AnalyzerInput(buffer: converted)
                        inputBuilder.yield(input)
                    } else {
                        // Fallback to original buffer if conversion fails
                        let input = AnalyzerInput(buffer: buffer)
                        inputBuilder.yield(input)
                    }
                } else {
                    // No conversion needed
                    let input = AnalyzerInput(buffer: buffer)
                    inputBuilder.yield(input)
                }
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
    
    /// Convert an AVAudioPCMBuffer to a target format using AVAudioConverter
    private func convert(buffer: AVAudioPCMBuffer, from: AVAudioFormat, to: AVAudioFormat, using converter: AVAudioConverter) -> AVAudioPCMBuffer? {
        guard let channelCount = to.channelLayout?.channelCount ?? to.channelCount as NSNumber? else { return nil }
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: to, frameCapacity: buffer.frameCapacity) else { return nil }
        outputBuffer.frameLength = buffer.frameLength
        
        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        
        let status = converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)
        switch status {
        case .haveData, .inputRanDry, .endOfStream:
            return outputBuffer
        case .error:
            if let error {
                print("❌ AVAudioConverter error: \(error)")
            }
            return nil
        @unknown default:
            return outputBuffer
        }
    }
    
    /// Stop listening and return final transcription
    func stopListening() {
        // Finish audio input
        inputContinuation?.finish()
        inputContinuation = nil
        
        // Cancel tasks
        analysisTask?.cancel()
        resultsTask?.cancel()
        analysisTask = nil
        resultsTask = nil
        
        // Stop audio engine
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
            print("🛑 Stopped listening")
        }
        
        self.isListening = false
    }
    
    /// Cancel current recognition task
    func cancelListening() {
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
