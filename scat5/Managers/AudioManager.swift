import Foundation
import AVFoundation

enum AudioSessionType {
    case playback
    case recording
}

@Observable
class AudioManager {
    static let shared = AudioManager()
    
    private var currentSessionType: AudioSessionType?
    private let audioSession = AVAudioSession.sharedInstance()
    
    private init() {}
    
    @MainActor
    func requestAudioSession(for type: AudioSessionType) async -> Bool {
        // Deactivate existing session if different type
        if let currentType = currentSessionType, currentType != type {
            await deactivateAudioSession()
        }
        
        // Configure and activate new session
        do {
            switch type {
            case .playback:
                try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
                print("🎤 AudioManager: Configured for playback")
            case .recording:
                try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .defaultToSpeaker])
                print("🎤 AudioManager: Configured for recording")
            }
            
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            currentSessionType = type
            print("✅ AudioManager: Session activated for \(type)")
            return true
            
        } catch {
            print("❌ AudioManager: Failed to activate session for \(type): \(error)")
            // Try a fallback for recording
            if type == .recording {
                do {
                    try audioSession.setCategory(.record, mode: .default, options: [])
                    try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
                    currentSessionType = type
                    print("✅ AudioManager: Fallback session activated for recording")
                    return true
                } catch {
                    print("❌ AudioManager: Fallback session failed: \(error)")
                    return false
                }
            }
            return false
        }
    }
    
    @MainActor
    func deactivateAudioSession() async {
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            print("🎤 AudioManager: Session deactivated")
            currentSessionType = nil
        } catch {
            print("❌ AudioManager: Failed to deactivate session: \(error)")
        }
    }
}