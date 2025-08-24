import Foundation
import SwiftUI
import Speech
import AVFoundation

@Observable
class SpeechTranscriptionManager {
    var transcript: String = ""
    var errorMessage: String?
    var isTranscribing: Bool = false
    
    // Modern API properties (iOS 26.0+)
    @available(iOS 26.0, visionOS 26.0, *)
    private var speechAnalyzer: SpeechAnalyzer?
    @available(iOS 26.0, visionOS 26.0, *)
    private var speechTranscriber: SpeechTranscriber?
    
    // Legacy API properties
    private var legacySpeechRecognizer: SFSpeechRecognizer?
    private var legacyRecognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var legacyRecognitionTask: SFSpeechRecognitionTask?
    private var legacyAudioEngine = AVAudioEngine()
    
    // Modern API properties
    private var inputBuilder: AsyncStream<AnalyzerInput>.Continuation?
    private var analysisTask: Task<Void, Never>?
    private var resultsTask: Task<Void, Never>?
    
    // Track which API we're using
    private var usingModernAPI: Bool = false
    
    init() {
        Task {
            await setupSpeechTranscription()
        }
    }
    
    deinit {
        Task {
            await stopTranscribing()
        }
    }
    
    // MARK: - Setup
    private func setupSpeechTranscription() async {
        // Request authorization
        guard await requestSpeechAuthorization() else {
            return
        }
        
        // Try modern API first
        if #available(iOS 26.0, visionOS 26.0, *) {
            await setupModernTranscription()
        } else {
            setupLegacyTranscription()
        }
    }
    
    @available(iOS 26.0, visionOS 26.0, *)
    private func setupModernTranscription() async {
        guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale.current) else {
            await MainActor.run {
                self.errorMessage = "Speech recognition not supported for current locale"
            }
            return
        }
        
        speechTranscriber = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
        
        guard let transcriber = speechTranscriber else {
            await MainActor.run {
                self.errorMessage = "Failed to create speech transcriber"
            }
            return
        }
        
        // Install assets if needed
        do {
            if let installationRequest = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                try await installationRequest.downloadAndInstall()
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to install speech assets: \(error.localizedDescription)"
            }
            return
        }
        
        speechAnalyzer = SpeechAnalyzer(modules: [transcriber])
        usingModernAPI = true
        
        await MainActor.run {
            self.errorMessage = nil
        }
    }
    
    private func setupLegacyTranscription() {
        legacySpeechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        legacySpeechRecognizer?.defaultTaskHint = .dictation
        usingModernAPI = false
    }
    
    private func requestSpeechAuthorization() async -> Bool {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { authStatus in
                Task { @MainActor in
                    switch authStatus {
                    case .authorized:
                        self.errorMessage = nil
                        continuation.resume(returning: true)
                    case .denied:
                        self.errorMessage = "Speech recognition access denied"
                        continuation.resume(returning: false)
                    case .restricted:
                        self.errorMessage = "Speech recognition restricted"
                        continuation.resume(returning: false)
                    case .notDetermined:
                        self.errorMessage = "Speech recognition not determined"
                        continuation.resume(returning: false)
                    @unknown default:
                        self.errorMessage = "Unknown speech recognition status"
                        continuation.resume(returning: false)
                    }
                }
            }
        }
    }
    
    // MARK: - Public Interface
    func startTranscribing() async {
        guard !isTranscribing else { return }
        
        if usingModernAPI {
            if #available(iOS 26.0, visionOS 26.0, *) {
                await startModernTranscription()
            }
        } else {
            await startLegacyTranscription()
        }
    }
    
    func stopTranscribing() async {
        guard isTranscribing else { return }
        
        if usingModernAPI {
            if #available(iOS 26.0, visionOS 26.0, *) {
                await stopModernTranscription()
            }
        } else {
            await stopLegacyTranscription()
        }
    }
    
    // MARK: - Modern API Implementation
    @available(iOS 26.0, visionOS 26.0, *)
    private func startModernTranscription() async {
        guard let analyzer = speechAnalyzer,
              let transcriber = speechTranscriber else {
            await MainActor.run {
                self.errorMessage = "Speech analyzer not ready"
            }
            return
        }
        
        do {
            // Get audio format
            let audioFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
            guard let format = audioFormat else {
                throw TranscriptionError.audioFormatNotAvailable
            }
            
            // Prepare analyzer
            try await analyzer.prepareToAnalyze(in: format)
            
            // Create input stream
            let (inputSequence, inputBuilder) = AsyncStream.makeStream(of: AnalyzerInput.self)
            self.inputBuilder = inputBuilder
            
            // Start audio capture
            try await startAudioCapture(format: format, inputBuilder: inputBuilder)
            
            // Start analysis
            analysisTask = Task {
                do {
                    _ = try await analyzer.analyzeSequence(inputSequence)
                } catch {
                    await MainActor.run {
                        self.errorMessage = "Transcription failed: \(error.localizedDescription)"
                        self.isTranscribing = false
                    }
                }
            }
            
            // Start results processing
            resultsTask = Task {
                await processResults(from: transcriber)
            }
            
            await MainActor.run {
                self.isTranscribing = true
                self.transcript = ""
                self.errorMessage = nil
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to start transcription: \(error.localizedDescription)"
            }
        }
    }
    
    @available(iOS 26.0, visionOS 26.0, *)
    private func stopModernTranscription() async {
        analysisTask?.cancel()
        resultsTask?.cancel()
        analysisTask = nil
        resultsTask = nil
        
        inputBuilder?.finish()
        inputBuilder = nil
        
        if let analyzer = speechAnalyzer {
            await analyzer.cancelAndFinishNow()
        }
        
        await MainActor.run {
            self.isTranscribing = false
        }
    }
    
    @available(iOS 26.0, visionOS 26.0, *)
    private func startAudioCapture(format: AVAudioFormat, inputBuilder: AsyncStream<AnalyzerInput>.Continuation) async throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        let audioEngine = AVAudioEngine()
        let inputNode = audioEngine.inputNode
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            let input = AnalyzerInput(buffer: buffer)
            inputBuilder.yield(input)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        // Keep engine running
        Task {
            defer {
                audioEngine.stop()
                inputNode.removeTap(onBus: 0)
            }
            
            while !Task.isCancelled && self.isTranscribing {
                try await Task.sleep(nanoseconds: 100_000_000)
            }
        }
    }
    
    @available(iOS 26.0, visionOS 26.0, *)
    private func processResults(from transcriber: SpeechTranscriber) async {
        do {
            for try await result in transcriber.results {
                let recognizedText = String(result.text.characters)
                
                await MainActor.run {
                    self.transcript = recognizedText
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Results processing error: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Legacy API Implementation
    private func startLegacyTranscription() async {
        guard let speechRecognizer = legacySpeechRecognizer,
              speechRecognizer.isAvailable else {
            await MainActor.run {
                self.errorMessage = "Speech recognizer not available"
            }
            return
        }
        
        do {
            try await startLegacySpeechRecognition()
            await MainActor.run {
                self.isTranscribing = true
                self.transcript = ""
                self.errorMessage = nil
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to start transcription: \(error.localizedDescription)"
            }
        }
    }
    
    private func stopLegacyTranscription() async {
        legacyAudioEngine.stop()
        legacyAudioEngine.inputNode.removeTap(onBus: 0)
        legacyRecognitionRequest?.endAudio()
        legacyRecognitionTask?.cancel()
        
        legacyRecognitionRequest = nil
        legacyRecognitionTask = nil
        
        await MainActor.run {
            self.isTranscribing = false
        }
    }
    
    private func startLegacySpeechRecognition() async throws {
        legacyRecognitionTask?.cancel()
        legacyRecognitionTask = nil
        
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        legacyRecognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = legacyRecognitionRequest else {
            throw TranscriptionError.failedToCreateRequest
        }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false
        
        let inputNode = legacyAudioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        
        let recordingFormat = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        legacyAudioEngine.prepare()
        try legacyAudioEngine.start()
        
        legacyRecognitionTask = legacySpeechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                if let result = result {
                    self?.transcript = result.bestTranscription.formattedString
                }
                
                if let error = error {
                    print("Speech recognition error: \(error)")
                    self?.errorMessage = "Recognition error occurred"
                }
            }
        }
    }
}

// MARK: - Error Types  
enum TranscriptionError: Error {
    case failedToCreateRequest
    case audioFormatNotAvailable
    case analyzerNotReady
    
    var localizedDescription: String {
        switch self {
        case .failedToCreateRequest:
            return "Failed to create speech recognition request"
        case .audioFormatNotAvailable:
            return "Compatible audio format not available"
        case .analyzerNotReady:
            return "Speech analyzer is not ready"
        }
    }
}