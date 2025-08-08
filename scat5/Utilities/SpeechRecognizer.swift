import Foundation
import SwiftUI
import AVFoundation
import Speech

class SCAT5SpeechRecognizer: ObservableObject {
    @Published var transcript: String = ""
    @Published var errorMessage: String?
    
    private var audioEngine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let recognizer: SFSpeechRecognizer?
    
    init() {
        recognizer = SFSpeechRecognizer()
        requestSpeechAuthorization()
    }
    
    deinit {
        stopTranscribing()
    }
    
    private func requestSpeechAuthorization() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async { [weak self] in
                switch authStatus {
                case .authorized:
                    print("Speech recognition authorized")
                    self?.errorMessage = nil
                case .denied:
                    self?.errorMessage = "Speech recognition access denied. Please enable in Settings."
                case .restricted:
                    self?.errorMessage = "Speech recognition restricted on this device."
                case .notDetermined:
                    self?.errorMessage = "Speech recognition not determined."
                @unknown default:
                    self?.errorMessage = "Unknown speech recognition status."
                }
            }
        }
    }
    
    func transcribe() {
        guard let recognizer, recognizer.isAvailable else {
            DispatchQueue.main.async {
                self.errorMessage = "Speech recognizer not available."
            }
            return
        }
        
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            DispatchQueue.main.async {
                self.errorMessage = "Speech recognition not authorized."
            }
            return
        }
        
        // Stop any existing transcription
        stopTranscribing()
        
        do {
            let (audioEngine, request) = try Self.prepareEngine()
            self.audioEngine = audioEngine
            self.request = request
            
            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                DispatchQueue.main.async {
                    if let result = result {
                        self?.transcript = result.bestTranscription.formattedString
                        self?.errorMessage = nil
                    } else if let error = error {
                        print("Recognition error: \(error)")
                        self?.errorMessage = "Speech recognition error occurred."
                        self?.stopTranscribing()
                    }
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Error starting speech recognition: \(error.localizedDescription)"
            }
        }
    }
    
    func stopTranscribing() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        
        audioEngine = nil
        request = nil
        task = nil
        
        // Reset audio session safely
        DispatchQueue.global(qos: .background).async {
            do {
                try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            } catch {
                print("Error deactivating audio session: \(error)")
            }
        }
    }
    
    private static func prepareEngine() throws -> (AVAudioEngine, SFSpeechAudioBufferRecognitionRequest) {
        let audioEngine = AVAudioEngine()
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        
        // Configure audio session more safely for visionOS
        let audioSession = AVAudioSession.sharedInstance()
        do {
            #if os(visionOS)
            // visionOS specific audio session configuration
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth])
            #else
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .allowBluetooth])
            #endif
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Audio session configuration error: \(error)")
            throw error
        }
        
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        // Validate audio format more thoroughly
        guard inputFormat.sampleRate > 0 && inputFormat.channelCount > 0 else {
            throw NSError(domain: "SCAT5SpeechRecognizer", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Invalid audio format: sampleRate=\(inputFormat.sampleRate), channels=\(inputFormat.channelCount)"
            ])
        }
        
        // Create a proper recording format if needed - visionOS compatible
        let recordingFormat: AVAudioFormat?
        
        #if os(visionOS)
        // visionOS may have different preferred formats
        recordingFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)
        #else
        recordingFormat = inputFormat.sampleRate == 16000 ? inputFormat :
            AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)
        #endif
        
        guard let format = recordingFormat else {
            throw NSError(domain: "SCAT5SpeechRecognizer", code: -2, userInfo: [
                NSLocalizedDescriptionKey: "Could not create recording format"
            ])
        }
        
        // Install tap with proper format handling
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        
        // Prepare and start the audio engine
        audioEngine.prepare()
        try audioEngine.start()
        
        return (audioEngine, request)
    }
}