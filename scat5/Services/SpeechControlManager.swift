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
    private var isTapInstalled = false

    // Add these to track speech analyzer lifecycle
    private var currentAnalyzer: SpeechAnalyzer?
    private var currentTranscriber: SpeechTranscriber?
    private var streamContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var isCleaningUp = false

    // Legacy SFSpeechRecognizer fallback
    private var legacyRecognizer: SFSpeechRecognizer?
    private var legacyRequest: SFSpeechAudioBufferRecognitionRequest?
    private var legacyTask: SFSpeechRecognitionTask?

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
            currentAnalyzer = nil
        }
        
        // 3. Clean up transcriber
        currentTranscriber = nil

        // 4a. Stop legacy recognition if active
        legacyTask?.cancel()
        legacyTask = nil
        legacyRequest?.endAudio()
        legacyRequest = nil
        legacyRecognizer = nil
        
        // 4b. Stop audio engine and safely remove tap if installed
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        if isTapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            isTapInstalled = false
        }
        audioEngine.reset()
        
        // 5. Clean up audio session
        await AudioManager.shared.deactivateAudioSession()
        
        await MainActor.run {
            isListening = false
        }
        
        // 6. Wait a bit to ensure system cleanup
        try? await Task.sleep(nanoseconds: 200_000_000)
        
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
            
            // Request and activate audio session via AudioManager
            let sessionReady = await AudioManager.shared.requestAudioSession(for: .recording)
            guard sessionReady else {
                await MainActor.run {
                    self.errorMessage = "Unable to activate audio session for recording"
                    self.isEnabled = false
                }
                return
            }
            
            // Try modern path first (visionOS 26+), else fallback to legacy SFSpeechRecognizer
            if #available(visionOS 26.0, iOS 26.0, *) {
                try await runModernAnalyzer()
            } else {
                await runLegacyRecognizer()
            }
            
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
                    self.isEnabled = false
                }
            }
        }
        
        await forceCleanup()
    }

    @available(visionOS 26.0, iOS 26.0, *)
    private func runModernAnalyzer() async throws {
        // 1. Configure Audio Session preferences (category/active handled by AudioManager)
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setPreferredSampleRate(16000.0)
            try audioSession.setPreferredIOBufferDuration(0.2)
        } catch {
            print("⚠️ Failed to set preferred audio session parameters: \(error)")
        }
        print("🎤 Audio session configured - Sample rate: \(audioSession.sampleRate), Buffer duration: \(audioSession.ioBufferDuration)")
        
        // 2. Setup Transcriber with optimized settings for command recognition
        let transcriber = SpeechTranscriber(
            locale: Locale(identifier: "en-US"),
            transcriptionOptions: [],
            reportingOptions: [.volatileResults, .fastResults],
            attributeOptions: []
        )
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        
        currentTranscriber = transcriber
        currentAnalyzer = analyzer
        
        print("🎤 Created new analyzer and transcriber with on-device processing")
        
        // 3. Get optimal audio format
        guard let requiredFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            throw NSError(domain: "SpeechError", code: 2, userInfo: [NSLocalizedDescriptionKey: "No compatible audio format found for the speech analyzer."])
        }
        print("🎤 System optimal format: \(requiredFormat)")
        
        // 4. Prepare Audio Pipeline
        let (stream, continuation) = AsyncStream.makeStream(of: AnalyzerInput.self)
        streamContinuation = continuation
        
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        print("🎤 Audio engine input format: \(inputFormat)")
        
        let bufferSize = AVAudioFrameCount(requiredFormat.sampleRate * 0.2)
        guard let converter = AVAudioConverter(from: inputFormat, to: requiredFormat) else {
            throw NSError(domain: "SpeechError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not create audio converter"])
        }
        converter.sampleRateConverterQuality = 2

        if isTapInstalled {
            inputNode.removeTap(onBus: 0)
            isTapInstalled = false
        }
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self, let continuation = self.streamContinuation else { return }
            
            let outputCapacity = AVAudioFrameCount(Double(buffer.frameLength) * requiredFormat.sampleRate / inputFormat.sampleRate) + 1
            guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: requiredFormat, frameCapacity: outputCapacity) else {
                print("❌ Could not create output buffer")
                return
            }
            
            var error: NSError?
            let status = converter.convert(to: outputBuffer, error: &error) { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }
            
            if (status == .haveData || status == .endOfStream), outputBuffer.frameLength > 0 {
                continuation.yield(AnalyzerInput(buffer: outputBuffer))
            } else if let error {
                print("❌ Buffer conversion failed: \(error.localizedDescription)")
            }
        }
        isTapInstalled = true
        
        audioEngine.prepare()
        try audioEngine.start()
        
        await MainActor.run {
            self.isListening = true
            self.errorMessage = nil
            print("✅ Speech analyzer started with optimized settings")
        }
        
        // 5. Start Analysis & Handle Results
        async let analysisTask: Void = analyzer.start(inputSequence: stream)
        
        for try await result in transcriber.results {
            guard !Task.isCancelled else { break }
            let text = String(describing: result.text).trimmingCharacters(in: .whitespacesAndNewlines)
            let filteredText = filterNoiseFromText(text)
            
            if result.isFinal && !filteredText.isEmpty && filteredText.count > 1 {
                if !isSimilarToLastResult(filteredText) {
                    self.lastRecognizedText = filteredText
                    await processCommand(filteredText)
                }
            }
        }
        
        try await analysisTask
    }
    
    private func runLegacyRecognizer() async {
        print("🎤 Running legacy SFSpeechRecognizer fallback")
        
        await MainActor.run {
            self.errorMessage = nil
        }
        
        legacyRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        guard let recognizer = legacyRecognizer, recognizer.isAvailable else {
            await MainActor.run {
                self.errorMessage = "Speech recognizer not available"
                self.isEnabled = false
            }
            return
        }
        
        legacyRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = legacyRequest else {
            await MainActor.run {
                self.errorMessage = "Failed to create recognition request"
                self.isEnabled = false
            }
            return
        }
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false
        
        let inputNode = audioEngine.inputNode
        if isTapInstalled {
            inputNode.removeTap(onBus: 0)
            isTapInstalled = false
        }
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { [weak self] buffer, _ in
            guard let self = self else { return }
            if buffer.frameLength > 0 {
                request.append(buffer)
            }
        }
        isTapInstalled = true
        
        do {
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            await MainActor.run {
                self.errorMessage = "Audio engine start failed: \(error.localizedDescription)"
                self.isEnabled = false
            }
            return
        }
        
        await MainActor.run {
            self.isListening = true
        }
        
        legacyTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            if let result {
                let text = result.bestTranscription.formattedString
                let filteredText = self.filterNoiseFromText(text)
                if result.isFinal && !filteredText.isEmpty && !self.isSimilarToLastResult(filteredText) {
                    self.lastRecognizedText = filteredText
                    Task { await self.processCommand(filteredText) }
                }
            }
            if let error {
                print("❌ Legacy recognition error: \(error)")
                Task { @MainActor in
                    self.errorMessage = "Recognition error occurred"
                    self.isEnabled = false
                }
            }
        }
        
        // Keep this task alive until cancelled
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
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