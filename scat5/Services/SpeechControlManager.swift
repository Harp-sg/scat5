import Foundation
import SwiftUI
import Speech
import AVFoundation

@Observable
class SpeechControlManager {
    var isEnabled: Bool = false {
        didSet {
            if isEnabled != oldValue {
                if isEnabled {
                    startListening()
                } else {
                    stopListening()
                }
            }
        }
    }
    
    var isListening: Bool = false
    var currentCommand: String = ""
    var lastRecognizedText: String = ""
    var errorMessage: String?
    
    private var recognitionTask: Task<Void, Never>?
    private let audioEngine = AVAudioEngine()
    private var commandProcessor: CommandProcessor
    
    // Add these to track speech analyzer lifecycle
    private var currentAnalyzer: SpeechAnalyzer?
    private var currentTranscriber: SpeechTranscriber?
    private var streamContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var isCleaningUp = false
    
    init() {
        self.commandProcessor = CommandProcessor()
        requestPermissions()
    }
    
    deinit {
        Task {
            await forceCleanup()
        }
    }
    
    private func requestPermissions() {
        print("🎤 Requesting speech permissions...")
        SFSpeechRecognizer.requestAuthorization { authStatus in
            print("🎤 Speech authorization status: \(authStatus)")
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    self.errorMessage = nil
                    print("🎤 Speech authorized, requesting microphone permission...")
                    
                    // Try the new visionOS API first, with fallback to legacy API
                    if #available(visionOS 2.0, *) {
                        AVAudioApplication.requestRecordPermission { granted in
                            print("🎤 Microphone permission (new API) granted: \(granted)")
                            DispatchQueue.main.async {
                                if !granted {
                                    self.errorMessage = "Microphone access denied"
                                }
                            }
                        }
                    } else {
                        // Fallback for older versions
                        AVAudioSession.sharedInstance().requestRecordPermission { granted in
                            print("🎤 Microphone permission (legacy API) granted: \(granted)")
                            DispatchQueue.main.async {
                                if !granted {
                                    self.errorMessage = "Microphone access denied"
                                }
                            }
                        }
                    }
                case .denied:
                    self.errorMessage = "Speech access denied"
                case .restricted:
                    self.errorMessage = "Speech restricted"
                case .notDetermined:
                    self.errorMessage = "Speech access not yet determined"
                @unknown default:
                    self.errorMessage = "Unknown speech authorization status"
                }
            }
        }
    }
    
    private func startListening() {
        print("🎤 startListening() called")
        print("🎤 Speech authorization: \(SFSpeechRecognizer.authorizationStatus())")
        
        // Prevent multiple concurrent startups
        guard !isCleaningUp else {
            print("🎤 Currently cleaning up, deferring start")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if self.isEnabled && !self.isListening {
                    self.startListening()
                }
            }
            return
        }
        
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            errorMessage = "Speech recognition not authorized"
            isEnabled = false
            print("🎤 Speech not authorized, stopping")
            return
        }
        
        // Check microphone permission with fallback
        var microphoneGranted = false
        if #available(visionOS 2.0, *) {
            microphoneGranted = AVAudioApplication.shared.recordPermission == .granted
            print("🎤 Microphone permission (new API): \(AVAudioApplication.shared.recordPermission)")
        } else {
            microphoneGranted = AVAudioSession.sharedInstance().recordPermission == .granted
            print("🎤 Microphone permission (legacy API): \(AVAudioSession.sharedInstance().recordPermission)")
        }
        
        guard microphoneGranted else {
            errorMessage = "Microphone access not granted"
            isEnabled = false
            print("🎤 Microphone not granted, stopping")
            return
        }
        
        // Ensure complete cleanup before starting new recognition
        recognitionTask = Task {
            await forceCleanup()
            // Small delay to ensure cleanup is complete
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            await runSpeechRecognition()
        }
    }
    
    private func stopListening() {
        print("🎤 Stopping speech recognition.")
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        Task {
            await forceCleanup()
        }
    }
    
    private func forceCleanup() async {
        guard !isCleaningUp else { return }
        isCleaningUp = true
        
        print("🎤 Force cleaning up all resources...")
        
        // 1. Finish the stream first
        streamContinuation?.finish()
        streamContinuation = nil
        
        // 2. Stop and clean up analyzer with explicit disposal
        if let analyzer = currentAnalyzer {
            print("🎤 Disposing of current analyzer...")
            // The analyzer should be disposed by setting it to nil and letting ARC handle it
            // But we need to ensure any ongoing operations complete first
            currentAnalyzer = nil
        }
        
        // 3. Clean up transcriber
        currentTranscriber = nil
        
        // 4. Stop audio engine
        if audioEngine.isRunning {
            audioEngine.stop()
            if audioEngine.inputNode.numberOfInputs > 0 {
                audioEngine.inputNode.removeTap(onBus: 0)
            }
        }
        
        // 5. Clean up audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("❌ Error deactivating audio session: \(error)")
        }
        
        await MainActor.run {
            isListening = false
        }
        
        // 6. Wait a bit to ensure system cleanup
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        isCleaningUp = false
        print("🎤 Cleanup complete")
    }
    
    private func runSpeechRecognition() async {
        do {
            // Ensure we're not already running
            guard currentAnalyzer == nil else {
                print("🎤 Analyzer already exists, aborting")
                return
            }
            
            // 1. Configure Audio Session with better settings for speech
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.duckOthers, .defaultToSpeaker])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            // Set preferred sample rate for better quality
            try audioSession.setPreferredSampleRate(16000.0)
            try audioSession.setPreferredIOBufferDuration(0.2) // 200ms for better latency/quality balance
            
            print("🎤 Audio session configured - Sample rate: \(audioSession.sampleRate), Buffer duration: \(audioSession.ioBufferDuration)")
            
            // 2. Check if SpeechAnalyzer is available (visionOS 26+)
            guard #available(visionOS 26.0, iOS 26.0, *) else {
                await MainActor.run {
                    self.errorMessage = "SpeechAnalyzer requires visionOS 26 or later"
                    print("❌ SpeechAnalyzer not available on this OS version")
                }
                return
            }
            
            // 3. Setup Transcriber with optimized settings for command recognition
            let transcriber = SpeechTranscriber(
                locale: Locale(identifier: "en-US"),
                transcriptionOptions: [], // Use empty set for default transcription
                reportingOptions: [.volatileResults, .fastResults],
                attributeOptions: []
            )
            
            let analyzer = SpeechAnalyzer(modules: [transcriber])
            
            // Store references ONLY after successful creation
            currentTranscriber = transcriber
            currentAnalyzer = analyzer
            
            print("🎤 Created new analyzer and transcriber with on-device processing")
            
            // 4. Get optimal audio format from the system
            guard let requiredFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
                throw NSError(domain: "SpeechError", code: 2, userInfo: [NSLocalizedDescriptionKey: "No compatible audio format found for the speech analyzer."])
            }
            
            print("🎤 System optimal format: \(requiredFormat)")
            
            // 5. Prepare Audio Pipeline with better buffer management
            let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
            streamContinuation = continuation
            
            let inputNode = audioEngine.inputNode
            let inputFormat = inputNode.outputFormat(forBus: 0)
            
            print("🎤 Audio engine input format: \(inputFormat)")
            
            // Use larger buffer size for better quality (0.2 seconds as recommended)
            let bufferSize = AVAudioFrameCount(requiredFormat.sampleRate * 0.2)
            
            // Create high-quality converter
            guard let converter = AVAudioConverter(from: inputFormat, to: requiredFormat) else {
                throw NSError(domain: "SpeechError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not create audio converter"])
            }
            
            // Configure converter for better quality
            converter.sampleRateConverterQuality = 2 // Max quality (0=min, 1=medium, 2=max)
            
            inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, time in
                guard let self = self, let continuation = self.streamContinuation else { return }
                
                // Create output buffer with proper capacity
                let outputCapacity = AVAudioFrameCount(Double(buffer.frameLength) * requiredFormat.sampleRate / inputFormat.sampleRate) + 1
                guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: requiredFormat, frameCapacity: outputCapacity) else {
                    print("❌ Could not create output buffer")
                    return
                }
                
                var error: NSError?
                let status = converter.convert(to: outputBuffer, error: &error) { inNumPackets, outStatus in
                    outStatus.pointee = .haveData
                    return buffer
                }
                
                if status == .haveData || status == .endOfStream {
                    // Only send non-empty buffers
                    if outputBuffer.frameLength > 0 {
                        continuation.yield(AnalyzerInput(buffer: outputBuffer))
                    }
                } else {
                    print("❌ Buffer conversion failed with status: \(status), error: \(error?.localizedDescription ?? "Unknown")")
                }
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            
            await MainActor.run {
                self.isListening = true
                self.errorMessage = nil
                print("✅ Speech analyzer started with optimized settings")
            }
            
            // 6. Start Analysis & Handle Results with better filtering
            async let analysisTask: Void = analyzer.start(inputSequence: stream)
            
            for try await result in transcriber.results {
                guard !Task.isCancelled else { 
                    print("🎤 Recognition task cancelled, breaking result loop")
                    break 
                }
                
                let text = String(describing: result.text).trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Better filtering of results
                let filteredText = filterNoiseFromText(text)
                
                // Only process final results that have meaningful content
                if result.isFinal && !filteredText.isEmpty && filteredText.count > 1 {
                    print("🎤 Final result (filtered): '\(filteredText)'")
                    
                    // Avoid processing duplicate or very similar results
                    if !isSimilarToLastResult(filteredText) {
                        self.lastRecognizedText = filteredText
                        await processCommand(filteredText)
                    } else {
                        print("🎤 Skipping similar result: '\(filteredText)'")
                    }
                } else if !result.isFinal && !filteredText.isEmpty {
                    // Show intermediate results for debugging
                    print("🎤 Intermediate: '\(filteredText)'")
                }
            }
            
            // Wait for analysis to complete
            try await analysisTask
            
        } catch {
            if !(error is CancellationError) {
                await MainActor.run {
                    if let speechError = error as NSError?, speechError.domain == "SFSpeechErrorDomain", speechError.code == 16 {
                        self.errorMessage = "Too many speech recognizers active. Please wait and try again."
                        print("❌ Maximum recognizers reached - forcing cleanup")
                    } else {
                        self.errorMessage = "Speech Error: \(error.localizedDescription)"
                        print("❌ Speech recognition error: \(error)")
                    }
                }
                
                // On recognizer limit error, force cleanup and disable
                if let speechError = error as NSError?, speechError.domain == "SFSpeechErrorDomain", speechError.code == 16 {
                    await forceCleanup()
                    await MainActor.run {
                        self.isEnabled = false
                    }
                } else {
                    // Don't restart automatically on other errors
                    await MainActor.run {
                        self.isEnabled = false
                    }
                }
            }
        }
        
        // 7. Final cleanup
        await forceCleanup()
    }
    
    @MainActor
    private func processCommand(_ text: String) {
        print("🎤 Processing text: '\(text)'")
        let command = commandProcessor.parseCommand(from: text)
        if let command = command {
            print("🎤 Executing: \(command)")
            currentCommand = command.description
            commandProcessor.executeCommand(command)
            
            // Clear command after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.currentCommand = ""
            }
        } else {
            print("🎤 No command found for: '\(text)'")
            // Show the unrecognized text in the UI for debugging
            currentCommand = "Unrecognized: \(text)"
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self.currentCommand = ""
            }
        }
    }
    
    // MARK: - Public Interface
    func setCommandDelegate(_ delegate: CommandExecutionDelegate) {
        commandProcessor.delegate = delegate
    }
    
    func toggleSpeechControl() {
        isEnabled.toggle()
    }
    
    func forceRestart() {
        print("🎤 Force restart requested")
        isEnabled = false
        Task {
            await forceCleanup()
            // Wait a bit longer before restarting to ensure complete cleanup
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            await MainActor.run {
                self.isEnabled = true
            }
        }
    }
    
    // MARK: - Text Processing Helpers
    
    private func filterNoiseFromText(_ text: String) -> String {
        var filtered = text
        
        // Remove common speech recognition artifacts
        let noisePatterns = [
            "\\{[^}]*\\}", // Remove anything in braces like "{ }"
            "\\.{3,}", // Remove multiple periods "..."
            "\\s{2,}", // Replace multiple spaces with single space
            "^(yeah|uh|um|er|ah)\\s*", // Remove filler words at start
            "\\s+(yeah|uh|um|er|ah)\\s*$", // Remove filler words at end
        ]
        
        for pattern in noisePatterns {
            filtered = filtered.replacingOccurrences(
                of: pattern,
                with: " ",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        
        return filtered.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func isSimilarToLastResult(_ text: String) -> Bool {
        // Avoid similarity check if either string is empty
        guard !text.isEmpty && !lastRecognizedText.isEmpty else {
            return false
        }
        
        let similarity = stringSimilarity(text.lowercased(), lastRecognizedText.lowercased())
        return similarity > 0.8 // 80% similarity threshold
    }
    
    private func stringSimilarity(_ str1: String, _ str2: String) -> Double {
        // Handle empty strings
        if str1.isEmpty && str2.isEmpty { return 1.0 }
        if str1.isEmpty || str2.isEmpty { return 0.0 }
        
        let longer = str1.count > str2.count ? str1 : str2
        let shorter = str1.count > str2.count ? str2 : str1
        
        let editDistance = levenshteinDistance(str1, str2)
        return (Double(longer.count) - Double(editDistance)) / Double(longer.count)
    }
    
    private func levenshteinDistance(_ str1: String, _ str2: String) -> Int {
        // Handle empty strings
        if str1.isEmpty { return str2.count }
        if str2.isEmpty { return str1.count }
        
        let str1Array = Array(str1)
        let str2Array = Array(str2)
        let str1Count = str1Array.count
        let str2Count = str2Array.count
        
        // Ensure we have valid counts
        guard str1Count > 0 && str2Count > 0 else { return max(str1Count, str2Count) }
        
        var matrix = Array(repeating: Array(repeating: 0, count: str2Count + 1), count: str1Count + 1)
        
        // Initialize first row and column
        for i in 0...str1Count {
            matrix[i][0] = i
        }
        
        for j in 0...str2Count {
            matrix[0][j] = j
        }
        
        // Fill the matrix
        for i in 1...str1Count {
            for j in 1...str2Count {
                let cost = str1Array[i-1] == str2Array[j-1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i-1][j] + 1,      // deletion
                    matrix[i][j-1] + 1,      // insertion
                    matrix[i-1][j-1] + cost  // substitution
                )
            }
        }
        
        return matrix[str1Count][str2Count]
    }
}