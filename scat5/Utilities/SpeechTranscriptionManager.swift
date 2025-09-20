import Foundation
import SwiftUI
import Speech
import AVFoundation

@Observable
class SpeechTranscriptionManager {
    var transcript: String = ""
    var errorMessage: String?
    var isTranscribing: Bool = false

    private let forceLegacyAPI = true

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
    private var isLegacyTapInstalled = false
    
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
        guard await requestSpeechAuthorization() else {
            return
        }

        if forceLegacyAPI {
            setupLegacyTranscription()
            return
        }

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

        if forceLegacyAPI {
            await startLegacyTranscription()
            return
        }

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

        if forceLegacyAPI {
            await stopLegacyTranscription()
            return
        }

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
            let ok = await AudioManager.shared.requestAudioSession(for: .recording)
            guard ok else {
                await MainActor.run {
                    self.errorMessage = "Unable to activate audio session"
                }
                return
            }

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
        
        await AudioManager.shared.deactivateAudioSession()
        
        await MainActor.run {
            self.isTranscribing = false
        }
    }
    
    @available(iOS 26.0, visionOS 26.0, *)
    private func startAudioCapture(format: AVAudioFormat, inputBuilder: AsyncStream<AnalyzerInput>.Continuation) async throws {
        let audioEngine = AVAudioEngine()
        let inputNode = audioEngine.inputNode
        
        // Remove any existing taps first
        inputNode.removeTap(onBus: 0)
        
        // Use a compatible format that works with Vision Pro
        let inputFormat = inputNode.outputFormat(forBus: 0)
        print("🎵 Modern API - Input format: \(inputFormat)")
        print("🎯 Modern API - Required format: \(format)")
        
        // Create a working format - use input sample rate but target channels/bit depth
        let workingFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: inputFormat.sampleRate, // Use hardware sample rate
            channels: min(inputFormat.channelCount, format.channelCount),
            interleaved: false
        )!
        
        print("🔧 Modern API - Working format: \(workingFormat)")
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: workingFormat) { buffer, _ in
            // Convert to required format if needed
            if workingFormat.sampleRate == format.sampleRate && 
               workingFormat.channelCount == format.channelCount {
                let input = AnalyzerInput(buffer: buffer)
                inputBuilder.yield(input)
            } else {
                // Create converter for format mismatch
                if let converter = AVAudioConverter(from: workingFormat, to: format) {
                    let capacity = AVAudioFrameCount(Double(buffer.frameLength) * format.sampleRate / workingFormat.sampleRate)
                    if let convertedBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) {
                        var error: NSError?
                        converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                            outStatus.pointee = .haveData
                            return buffer
                        }
                        if error == nil {
                            let input = AnalyzerInput(buffer: convertedBuffer)
                            inputBuilder.yield(input)
                        } else {
                            print("❌ Audio conversion error: \(error!)")
                        }
                    }
                } else {
                    // Fallback: use original buffer
                    let input = AnalyzerInput(buffer: buffer)
                    inputBuilder.yield(input)
                }
            }
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
        if isLegacyTapInstalled {
            legacyAudioEngine.inputNode.removeTap(onBus: 0)
            isLegacyTapInstalled = false
        }
        legacyRecognitionRequest?.endAudio()
        legacyRecognitionTask?.cancel()
        
        legacyRecognitionRequest = nil
        legacyRecognitionTask = nil
        
        await AudioManager.shared.deactivateAudioSession()
        
        await MainActor.run {
            self.isTranscribing = false
        }
    }

    private func startLegacySpeechRecognition() async throws {
        legacyRecognitionTask?.cancel()
        legacyRecognitionTask = nil

        let ok = await AudioManager.shared.requestAudioSession(for: .recording)
        guard ok else {
            throw TranscriptionError.analyzerNotReady
        }

        legacyRecognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = legacyRecognitionRequest else {
            throw TranscriptionError.failedToCreateRequest
        }

        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false

        let inputNode = legacyAudioEngine.inputNode
        if isLegacyTapInstalled {
            inputNode.removeTap(onBus: 0)
            isLegacyTapInstalled = false
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { [weak self] buffer, _ in
            guard buffer.frameLength > 0 else { return }
            recognitionRequest.append(buffer)
            if self?.isTranscribing == false {
                // no-op, just ensures manager stays alive
            }
        }
        isLegacyTapInstalled = true

        legacyAudioEngine.prepare()
        try legacyAudioEngine.start()

        legacyRecognitionTask = legacySpeechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                if let result {
                    self?.transcript = result.bestTranscription.formattedString
                }
                if let error {
                    print("Speech recognition error: \(error)")
                    // Don't show transient errors
                    if (error as NSError).code != 216 {
                        self?.errorMessage = "Recognition error occurred"
                    }
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