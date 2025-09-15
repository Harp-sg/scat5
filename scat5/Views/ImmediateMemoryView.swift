import SwiftUI
import SwiftData
import AVFoundation
import Speech

struct ImmediateMemoryView: View, TestController {
    @Bindable var cognitiveResult: CognitiveResult
    let onComplete: () -> Void
    
    @State private var currentTrialIndex = 0
    @State private var viewState: MemoryViewState = .instructions
    @Environment(SpeechControlCoordinator.self) private var speechCoordinator
    
    enum MemoryViewState {
        case instructions
        case presenting  
        case recalling
        case trialComplete
        case finished
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 12) {
                Text("Immediate Memory")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.primary)
                
                if viewState != .instructions {
                    Text("Trial \(currentTrialIndex + 1) of 3")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    // Progress indicator
                    HStack(spacing: 6) {
                        ForEach(0..<3) { index in
                            Circle()
                                .fill(index < currentTrialIndex ? Color.blue : 
                                     index == currentTrialIndex ? Color.blue.opacity(0.6) : 
                                     Color.gray.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }
                }
            }
            .padding(.top, 24)
            
            Spacer()
            
            // Main content
            switch viewState {
            case .instructions:
                InstructionsView {
                    viewState = .presenting
                }
            case .presenting:
                WordPresentationView(words: cognitiveResult.immediateMemoryTrials[currentTrialIndex].words) {
                    viewState = .recalling
                }
            case .recalling:
                FreeRecallView(trial: $cognitiveResult.immediateMemoryTrials[currentTrialIndex]) {
                    viewState = .trialComplete
                }
            case .trialComplete:
                TrialCompleteView(
                    trialNumber: currentTrialIndex + 1,
                    score: cognitiveResult.immediateMemoryTrials[currentTrialIndex].score
                ) {
                    if currentTrialIndex < 2 {
                        currentTrialIndex += 1
                        viewState = .presenting
                    } else {
                        viewState = .finished
                    }
                }
            case .finished:
                VStack(spacing: 24) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    
                    Text("Immediate Memory Complete")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Total Score: \(cognitiveResult.immediateMemoryTotalScore) / 15")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Button("Complete Test") {
                        onComplete()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(Color.blue, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 32)
        .onAppear {
            speechCoordinator.testController = self
        }
        .onDisappear {
            speechCoordinator.testController = nil
        }
    }
    
    // MARK: - Speech Control Integration
    func executeCommand(_ command: VoiceCommand) {
        switch command {
        case .startTest:
            if viewState == .instructions {
                viewState = .presenting
            }
        case .completeTest:
            onComplete()
        case .nextTrial:
            if viewState == .trialComplete {
                if currentTrialIndex < 2 {
                    currentTrialIndex += 1
                    viewState = .presenting
                } else {
                    viewState = .finished
                }
            }
        default:
            break
        }
    }
}

// MARK: - Instructions View

struct InstructionsView: View, TestController {
    let onStart: () -> Void
    @Environment(SpeechControlCoordinator.self) private var speechCoordinator
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            VStack(spacing: 16) {
                Text("Memory Test Instructions")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                
                VStack(spacing: 12) {
                    Text("You will see and hear 5 words, one at a time.")
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                    
                    Text("After all words are shown, you'll have 30 seconds to recall as many as you can.")
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                    
                    Text("This test will repeat 3 times with the same words.")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .multilineTextAlignment(.center)
            }
            
            Button("Start Test") {
                onStart()
            }
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 40)
            .padding(.vertical, 16)
            .background(Color.blue, in: RoundedRectangle(cornerRadius: 16))
        }
        .onAppear { speechCoordinator.testController = self }
        .onDisappear { speechCoordinator.testController = nil }
    }
    
    func executeCommand(_ command: VoiceCommand) {
        switch command {
        case .startTest, .selectItem, .startRecording:
            onStart()
        default: break
        }
    }
}

// Helper to map "start" commands in instructions
private struct VoiceProxy: TestController {
    let start: () -> Void
    func executeCommand(_ command: VoiceCommand) {
        switch command {
        case .startTest, .startRecording, .selectItem:
            start()
        default: break
        }
    }
}

// MARK: - Word Presentation

struct WordPresentationView: View {
    let words: [String]
    let onPresentationComplete: () -> Void

    @State private var currentWordIndex = 0
    @State private var showGetReady = false
    @State private var synthesizer = AVSpeechSynthesizer()
    @State private var isPresenting = false
    @State private var audioSetupComplete = false
    @State private var speakerDelegate = SpeakerDelegate()

    var body: some View {
        VStack(spacing: 40) {
            if !audioSetupComplete {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Preparing audio...")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
            } else if !showGetReady {
                if currentWordIndex < words.count {
                    Text(words[currentWordIndex])
                        .font(.system(size: 72, weight: .bold))
                        .foregroundColor(.primary)
                        .transition(.opacity.animation(.easeInOut(duration: 0.2)))
                } else {
                    Color.clear.frame(height: 100)
                }
            } else {
                VStack(spacing: 16) {
                    Text("Get Ready to Recall...")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundColor(.primary)

                    Text("Remember as many words as you can")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .transition(.opacity.animation(.easeInOut(duration: 0.3)))
            }

            if audioSetupComplete && !showGetReady {
                HStack(spacing: 8) {
                    ForEach(0..<words.count, id: \.self) { index in
                        Circle()
                            .fill(index < currentWordIndex ? Color.green :
                                 index == currentWordIndex ? Color.blue :
                                 Color.gray.opacity(0.3))
                            .frame(width: 12, height: 12)
                    }
                }
            }
        }
        .task {
            await setupAudioAndStart()
        }
        .onDisappear {
            synthesizer.stopSpeaking(at: .immediate)
            isPresenting = false
            Task { await AudioManager.shared.deactivateAudioSession() }
        }
    }

    private func setupAudioAndStart() async {
        let success = await AudioManager.shared.requestAudioSession(for: .playback)
        await MainActor.run {
            audioSetupComplete = true
        }
        guard success else { return }

        await MainActor.run {
            // Ensure TTS uses our already-activated session
            synthesizer.usesApplicationAudioSession = true
        }

        // PREWARM: issue a silent, very short utterance to warm TTS
        await primeSynthesizer()

        await MainActor.run {
            startPresentation()
        }
    }

    private func primeSynthesizer() async {
        await withCheckedContinuation { continuation in
            let u = AVSpeechUtterance(string: "a")
            u.volume = 0.0                  // silent
            u.rate = 0.5
            u.preUtteranceDelay = 0
            u.postUtteranceDelay = 0
            synthesizer.speak(u)

            // Give the pipeline a brief moment to spin up
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                continuation.resume()
            }
        }
    }

    private func startPresentation() {
        guard !isPresenting else { return }
        isPresenting = true

        // Queue utterances; UI will update when each starts (delegate)
        for word in words {
            let utterance = AVSpeechUtterance(string: word)
            if let voice = AVSpeechSynthesisVoice(language: "en-US") {
                utterance.voice = voice
            }
            utterance.rate = 0.45
            utterance.volume = 1.0
            utterance.pitchMultiplier = 1.0
            utterance.preUtteranceDelay = 0
            utterance.postUtteranceDelay = 0
            synthesizer.speak(utterance)
        }
    }
}

final class SpeakerDelegate: NSObject, AVSpeechSynthesizerDelegate {
    private var onStartWord: ((Int) -> Void)?
    private var onAllFinished: (() -> Void)?
    private var index: Int = -1
    private var total: Int = 0

    func configure(total: Int, onStartWord: @escaping (Int) -> Void, onAllFinished: @escaping () -> Void) {
        self.total = total
        self.index = -1
        self.onStartWord = onStartWord
        self.onAllFinished = onAllFinished
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        index += 1
        onStartWord?(index)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        if index == total - 1 {
            onAllFinished?()
        }
    }
}

// MARK: - Free Recall View

struct FreeRecallView: View, TestController {
    @Binding var trial: MemoryTrial
    let onRecallComplete: () -> Void
    
    @State private var speechTranscriptionManager = SpeechTranscriptionManager()
    @State private var isRecording = false
    @State private var recalledWordsSet = Set<String>()
    @State private var recallTimeRemaining = 30
    @State private var recallTimer: Timer?
    @State private var hasStarted = false
    @State private var setupComplete = false
    @State private var isSetupInProgress = false
    @Environment(SpeechControlCoordinator.self) private var speechCoordinator
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Text("Say all the words you can remember")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.primary)
                
                Text("Time remaining: \(recallTimeRemaining)s")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(recallTimeRemaining <= 10 ? .red : .secondary)
                    .animation(.easeInOut, value: recallTimeRemaining)
            }
            
            // Setup status
            if isSetupInProgress {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Setting up microphone...")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
            
            // Error message display with retry option
            if let errorMessage = speechTranscriptionManager.errorMessage {
                VStack(spacing: 12) {
                    Text(errorMessage)
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button("Retry Speech Setup") {
                        Task {
                            await restartSpeechRecognition()
                        }
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                }
            }
            
            // Word slots - show progress as words are recalled
            HStack(spacing: 12) {
                ForEach(0..<trial.words.count, id: \.self) { index in
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                            .frame(width: 60, height: 60)
                        
                        if index < recalledWordsSet.count {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.green.opacity(0.8))
                                .frame(width: 60, height: 60)
                                .transition(.scale.combined(with: .opacity))
                            
                            Image(systemName: "checkmark")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                        } else {
                            Text("\(index + 1)")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Speech recognition interface
            if setupComplete {
                VStack(spacing: 16) {
                    Button(action: {
                        Task {
                            await toggleRecording()
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 120, height: 120)
                                .shadow(color: isRecording ? .red.opacity(0.5) : .blue.opacity(0.3), radius: 12)
                            
                            Image(systemName: isRecording ? "mic.slash.fill" : "mic.fill")
                                .font(.system(size: 48))
                                .foregroundColor(isRecording ? .red : .blue)
                            
                            if isRecording {
                                Circle()
                                    .stroke(Color.red, lineWidth: 3)
                                    .frame(width: 120, height: 120)
                                    .opacity(0.8)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(isRecording ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: isRecording)
                    
                    Text(isRecording ? "Listening... Speak clearly" : "Tap to start speaking")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    if !speechTranscriptionManager.transcript.isEmpty {
                        Text("Heard: \(speechTranscriptionManager.transcript)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                    }
                }
            }
            
            Spacer()
            
            // Completion button
            Button("Complete Trial") {
                completeRecall()
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .background(Color.blue, in: RoundedRectangle(cornerRadius: 16))
            .buttonStyle(.plain)
        }
        .task {
            await initializeSpeechRecognition()
        }
        .onAppear {
            startRecallTimer()
            speechCoordinator.testController = self
        }
        .onDisappear {
            cleanup()
            speechCoordinator.testController = nil
        }
        .onChange(of: speechTranscriptionManager.transcript) { oldValue, newValue in
            processTranscript(newValue)
        }
    }
    
    func executeCommand(_ command: VoiceCommand) {
        switch command {
        case .startRecording, .startTest:
            if setupComplete && !isRecording { 
                Task { await toggleRecording() }
            }
        case .stopRecording:
            if isRecording { 
                Task { await toggleRecording() }
            }
        case .completeTest, .nextTrial:
            completeRecall()
        default: break
        }
    }
    
    private func initializeSpeechRecognition() async {
        guard !isSetupInProgress else { return }
        await MainActor.run {
            isSetupInProgress = true
        }

        // Use centralized audio session to avoid conflicts
        let success = await AudioManager.shared.requestAudioSession(for: .recording)
        guard success else {
            await MainActor.run {
                speechTranscriptionManager.errorMessage = "Failed to get microphone access"
                isSetupInProgress = false
                setupComplete = false
            }
            return
        }

        await MainActor.run {
            speechTranscriptionManager = SpeechTranscriptionManager()
        }

        // Small warm-up to ensure tap delivers buffers
        try? await Task.sleep(nanoseconds: 700_000_000)

        await MainActor.run {
            setupComplete = speechTranscriptionManager.errorMessage == nil
            isSetupInProgress = false
            print(setupComplete ? "✅ Speech recognition ready" : "❌ Speech recognition failed")
        }
    }
    
    private func restartSpeechRecognition() async {
        await MainActor.run {
            isSetupInProgress = true
            setupComplete = false
        }
        
        // Stop current recognition if running
        await speechTranscriptionManager.stopTranscribing()
        isRecording = false
        
        // Re-initialize
        await initializeSpeechRecognition()
    }
    
    private func startRecallTimer() {
        recallTimer?.invalidate() // Ensure no duplicate timers
        recallTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if recallTimeRemaining > 0 {
                recallTimeRemaining -= 1
            } else {
                completeRecall()
            }
        }
    }
    
    private func toggleRecording() async {
        guard setupComplete else {
            print("⚠️ Speech recognition not ready yet")
            return
        }
        
        if isRecording {
            await speechTranscriptionManager.stopTranscribing()
            await MainActor.run {
                isRecording = false
            }
        } else {
            await speechTranscriptionManager.startTranscribing()
            await MainActor.run {
                isRecording = true
                if !hasStarted {
                    hasStarted = true
                }
            }
        }
    }
    
    private func processTranscript(_ transcript: String) {
        // Clean and tokenize the transcript
        let cleanTranscript = transcript.lowercased()
            .replacingOccurrences(of: "[^a-z ]", with: "", options: .regularExpression)
        let spokenWords = cleanTranscript.split(separator: " ").map { String($0) }
        
        // Match against the original word list
        for word in spokenWords {
            if trial.words.map({ $0.lowercased() }).contains(word) {
                if let originalWord = trial.words.first(where: { $0.lowercased() == word }) {
                    if !recalledWordsSet.contains(originalWord) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            recalledWordsSet.insert(originalWord)
                        }
                        print("✅ Recognized word: \(originalWord)")
                    }
                }
            }
        }
    }
    
    private func completeRecall() {
        cleanup()
        trial.recalledWords = Array(recalledWordsSet)
        onRecallComplete()
    }
    
    private func cleanup() {
        recallTimer?.invalidate()
        recallTimer = nil
        Task {
            await speechTranscriptionManager.stopTranscribing()
            // Relinquish audio session
            await AudioManager.shared.deactivateAudioSession()
        }
        isRecording = false
    }
}

// MARK: - Trial Complete View

struct TrialCompleteView: View, TestController {
    let trialNumber: Int
    let score: Int
    let onContinue: () -> Void
    @Environment(SpeechControlCoordinator.self) private var speechCoordinator
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(.green)
            
            Text("Trial \(trialNumber) Complete")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)
            
            Text("Words recalled: \(score) / 5")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.secondary)
            
            Button(trialNumber < 3 ? "Continue to Next Trial" : "View Results") {
                onContinue()
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .background(Color.blue, in: RoundedRectangle(cornerRadius: 16))
        }
        .onAppear { speechCoordinator.testController = self }
        .onDisappear { speechCoordinator.testController = nil }
    }
    
    func executeCommand(_ command: VoiceCommand) {
        switch command {
        case .nextTrial, .completeTest, .selectItem, .startTest:
            onContinue()
        default: break
        }
    }
}

#Preview {
    let container = try! ModelContainer(for: CognitiveResult.self, MemoryTrial.self)
    let sampleCognitiveResult = CognitiveResult()
    
    ImmediateMemoryView(
        cognitiveResult: sampleCognitiveResult,
        onComplete: { print("Immediate memory completed") }
    )
    .glassBackgroundEffect()
    .modelContainer(container)
}