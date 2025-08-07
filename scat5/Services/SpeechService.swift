import Foundation
import Speech
import AVFoundation
import SwiftUI
import Combine

// 1. Command Definition
enum VoiceCommand {
    case startTest
    case stopTest
    case next
    case previous
    case selectItem(String)
    case answer(String)
    case unknown
}

// 2. Audio Source for Speech Analysis
class AudioSource: AsyncSequence {
    typealias Element = AVAudioPCMBuffer
    typealias AsyncIterator = Iterator

    private let engine = AVAudioEngine()
    private let bus = 0
    private var continuation: AsyncStream<AVAudioPCMBuffer>.Continuation?
    private var stream: AsyncStream<AVAudioPCMBuffer>?

    init() {
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: bus)
        
        inputNode.installTap(onBus: bus, bufferSize: 1024, format: format) { buffer, _ in
            self.continuation?.yield(buffer)
        }
    }

    func makeAsyncIterator() -> Iterator {
        if stream == nil {
            stream = AsyncStream { continuation in
                self.continuation = continuation
                continuation.onTermination = { @Sendable _ in
                    self.engine.inputNode.removeTap(onBus: self.bus)
                    self.engine.stop()
                }
            }
        }
        return Iterator(stream!.makeAsyncIterator(), engine: engine)
    }
    
    func start() throws {
        try engine.start()
    }
    
    func stop() {
        continuation?.finish()
        engine.stop()
    }

    struct Iterator: AsyncIteratorProtocol {
        private var streamIterator: AsyncStream<AVAudioPCMBuffer>.Iterator
        let engine: AVAudioEngine

        init(_ streamIterator: AsyncStream<AVAudioPCMBuffer>.Iterator, engine: AVAudioEngine) {
            self.streamIterator = streamIterator
            self.engine = engine
        }
        
        mutating func next() async -> AVAudioPCMBuffer? {
            return await streamIterator.next()
        }
    }
}

// 3. Main Speech Service
@MainActor
class SpeechService: ObservableObject {
    @Published var isListening = false
    @Published var transcript = ""
    @Published var command: VoiceCommand?

    private let analyzer = SpeechAnalyzer()
    private let transcriber: SpeechTranscriber
    private var audioSource: AudioSource?
    private var analysisTask: Task<Void, Never>?

    init() {
        self.transcriber = SpeechTranscriber(locale: .autoupdatingCurrent)
        analyzer.addModule(transcriber)
    }

    func startListening() async {
        guard !isListening else { return }
        
        do {
            try await requestPermissionsAndEnsureModel()
            
            self.audioSource = AudioSource()
            try audioSource?.start()
            
            isListening = true
            transcript = "Listening..."
            
            analysisTask = Task {
                await self.analyzeAudio()
            }
        } catch {
            print("Error starting speech recognition: \(error.localizedDescription)")
            isListening = false
            transcript = "Error: \(error.localizedDescription)"
        }
    }

    func stopListening() {
        guard isListening else { return }
        
        analysisTask?.cancel()
        analysisTask = nil
        audioSource?.stop()
        audioSource = nil
        isListening = false
        transcript = ""
        
        Task {
            try? await analyzer.finish()
        }
    }

    private func requestPermissionsAndEnsureModel() async throws {
        // Request microphone permission
        await AVAudioApplication.requestRecordPermission()
        
        // Request speech recognition permission
        guard await SFSpeechRecognizer.hasAuthorizationToRecognize() else {
            throw NSError(domain: "SpeechService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Speech recognition authorization denied."])
        }

        // Ensure model is available
        guard await SpeechAnalyzer.supportedLocales().contains(.autoupdatingCurrent) else {
            throw NSError(domain: "SpeechService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Locale not supported"])
        }
        
        if let downloader = try await AssetInventory.assetInstallationRequest(supporting: [SpeechTranscriber.self]) {
            try await downloader.downloadAndInstall()
        }
    }

    private func analyzeAudio() async {
        guard let audioSource else { return }
        
        let resultTask = Task.detached {
            for await result in try! self.analyzer.results {
                await self.processResult(result)
            }
        }

        do {
            for try await buffer in audioSource {
                if Task.isCancelled { break }
                try? await analyzer.analyze(buffer)
            }
        } catch {
            print("Audio analysis error: \(error.localizedDescription)")
        }
        
        resultTask.cancel()
        try? await analyzer.finish()
    }
    
    private func processResult(_ result: SpeechAnalysisResult) {
        switch result {
        case .volatile(let interim):
            let formattedString = interim.bestTranscription.formattedString
            Task { @MainActor in
                self.transcript = formattedString
            }
        case .final(let final):
            let formattedString = final.bestTranscription.formattedString
            Task { @MainActor in
                self.transcript = formattedString
                self.mapToCommand(formattedString)
            }
        @unknown default:
            break
        }
    }

    private func mapToCommand(_ text: String) {
        let commandText = text.lowercased()
        
        if commandText.contains("start test") {
            command = .startTest
        } else if commandText.contains("stop test") {
            command = .stopTest
        } else if commandText.contains("next") {
            command = .next
        } else if commandText.contains("previous") {
            command = .previous
        } else if commandText.hasPrefix("select") {
            let item = commandText.replacingOccurrences(of: "select", with: "").trimmingCharacters(in: .whitespaces)
            command = .selectItem(item)
        } else if commandText.hasPrefix("answer") {
            let answer = commandText.replacingOccurrences(of: "answer", with: "").trimmingCharacters(in: .whitespaces)
            command = .answer(answer)
        } else {
            command = .unknown
        }
        
        // Automatically reset command after a short delay to allow re-triggering
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.command = nil
        }
    }
}