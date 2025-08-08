import SwiftUI
import SwiftData
import AVFoundation
import Speech

struct ImmediateMemoryView: View {
    @Bindable var cognitiveResult: CognitiveResult
    let onComplete: () -> Void
    
    @State private var currentTrialIndex = 0
    @State private var viewState: MemoryViewState = .instructions
    
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
                    
                    Button("Continue") {
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
    }
}

// MARK: - Instructions View

struct InstructionsView: View {
    let onStart: () -> Void
    
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
    }
}

// MARK: - Word Presentation

struct WordPresentationView: View {
    let words: [String]
    let onPresentationComplete: () -> Void
    
    @State private var currentWordIndex = 0
    @State private var showGetReady = false
    private let synthesizer = AVSpeechSynthesizer()
    
    var body: some View {
        VStack(spacing: 40) {
            if !showGetReady {
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
            
            // Progress indicator during presentation
            if !showGetReady {
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
        .onAppear {
            startPresentation()
        }
    }
    
    private func startPresentation() {
        presentNextWord()
    }
    
    private func presentNextWord() {
        if currentWordIndex < words.count {
            // Speak the current word
            let utterance = AVSpeechUtterance(string: words[currentWordIndex])
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            utterance.rate = 0.45
            synthesizer.speak(utterance)
            
            // Move to next word after 1 second
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation {
                    if currentWordIndex < words.count - 1 {
                        currentWordIndex += 1
                        presentNextWord()
                    } else {
                        // All words presented, show "Get Ready" message
                        showGetReady = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            onPresentationComplete()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Free Recall View

struct FreeRecallView: View {
    @Binding var trial: MemoryTrial
    let onRecallComplete: () -> Void
    
    @StateObject private var speechRecognizer = SCAT5SpeechRecognizer()
    @State private var isRecording = false
    @State private var recalledWordsSet = Set<String>()
    @State private var recallTimeRemaining = 30
    @State private var recallTimer: Timer?
    @State private var hasStarted = false
    
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
            
            // Error message display
            if let errorMessage = speechRecognizer.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 14))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
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
            VStack(spacing: 16) {
                Button(action: {
                    toggleRecording()
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
                
                if !speechRecognizer.transcript.isEmpty {
                    Text("Heard: \(speechRecognizer.transcript)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
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
        .onAppear {
            startRecallTimer()
        }
        .onDisappear {
            cleanup()
        }
        .onReceive(speechRecognizer.$transcript) { transcript in
            processTranscript(transcript)
        }
    }
    
    private func startRecallTimer() {
        recallTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if recallTimeRemaining > 0 {
                recallTimeRemaining -= 1
            } else {
                completeRecall()
            }
        }
    }
    
    private func toggleRecording() {
        guard speechRecognizer.errorMessage == nil else {
            return
        }
        
        if isRecording {
            speechRecognizer.stopTranscribing()
            isRecording = false
        } else {
            speechRecognizer.transcribe()
            isRecording = true
            if !hasStarted {
                hasStarted = true
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
        speechRecognizer.stopTranscribing()
        isRecording = false
    }
}

// MARK: - Trial Complete View

struct TrialCompleteView: View {
    let trialNumber: Int
    let score: Int
    let onContinue: () -> Void
    
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