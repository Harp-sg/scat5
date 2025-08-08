import SwiftUI
import SwiftData
import AVFoundation
import Speech

// MARK: - Main View
struct DelayedRecallView: View {
    @Bindable var cognitiveResult: CognitiveResult
    let onComplete: () -> Void
    
    @State private var viewState: DelayedRecallState = .initialInstructions
    @State private var timeRemaining: Int = 300 // 5 minutes
    @State private var countdownTimer: Timer?
    
    enum DelayedRecallState {
        case initialInstructions
        case presentingWords
        case countdown
        case recallingInstructions
        case recalling
        case finished
    }
    
    var body: some View {
        VStack(spacing: 20) {
            HeaderView(viewState: viewState, timeRemaining: timeRemaining)
            
            Spacer()
            
            ZStack {
                switch viewState {
                case .initialInstructions:
                    InitialInstructionsView {
                        cognitiveResult.delayedRecallWordList = CognitiveResult.getWordList()
                        viewState = .presentingWords
                    }
                    
                case .presentingWords:
                    DelayedRecallWordPresentationView(words: cognitiveResult.delayedRecallWordList) {
                        viewState = .countdown
                        startCountdown()
                    }
                    
                case .countdown:
                    CountdownView(timeRemaining: timeRemaining)
                    
                case .recallingInstructions:
                    RecallingInstructionsView {
                        viewState = .recalling
                    }
                    
                case .recalling:
                    DelayedRecallTest(
                        originalWords: cognitiveResult.delayedRecallWordList,
                        cognitiveResult: cognitiveResult
                    ) {
                        viewState = .finished
                    }
                    
                case .finished:
                    FinishedView(
                        score: cognitiveResult.delayedRecallScore,
                        wordCount: cognitiveResult.delayedRecallWordList.count
                    ) {
                        onComplete()
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 32)
        .onDisappear(perform: cleanup)
    }
    
    private func startCountdown() {
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                cleanup()
                viewState = .recallingInstructions
            }
        }
    }
    
    private func cleanup() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }
}

// MARK: - State-Specific Subviews

private struct HeaderView: View {
    let viewState: DelayedRecallView.DelayedRecallState
    let timeRemaining: Int

    var body: some View {
        VStack(spacing: 12) {
            Text("Delayed Recall")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.primary)
            
            if viewState == .countdown {
                Text("Memorization period. Please wait \(timeRemaining / 60):\(String(format: "%02d", timeRemaining % 60))")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 24)
    }
}

private struct InitialInstructionsView: View {
    let onStart: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "text.book.closed")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            VStack(spacing: 16) {
                Text("Delayed Recall Test")
                    .font(.system(size: 24, weight: .bold))
                
                Text("First, you will be shown a list of words to memorize. After a 5-minute delay, you will be asked to recall them.")
                    .font(.system(size: 16))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            
            Button("Start Learning") {
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

private class SpeechCoordinator: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published var currentWordIndex = 0
    let words: [String]
    let onComplete: () -> Void
    private let synthesizer = AVSpeechSynthesizer()

    init(words: [String], onComplete: @escaping () -> Void) {
        self.words = words
        self.onComplete = onComplete
        super.init()
        self.synthesizer.delegate = self
    }

    func start() {
        presentNextWord()
    }

    private func presentNextWord() {
        guard currentWordIndex < words.count else {
            // All words have been presented.
            DispatchQueue.main.async {
                self.onComplete()
            }
            return
        }
        
        // Update the UI FIRST (dot glows as word starts being spoken)
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.2)) {
                // Don't increment here - the dot should light up for the CURRENT word
            }
        }
        
        let utterance = AVSpeechUtterance(string: words[currentWordIndex])
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.45
        utterance.postUtteranceDelay = 0.5
        synthesizer.speak(utterance)
    }

    // This delegate method is called when the synthesizer finishes speaking.
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        // Move to the next word index AFTER the current word finishes
        DispatchQueue.main.async {
            self.currentWordIndex += 1
            // Trigger the next word presentation
            self.presentNextWord()
        }
    }
}

private struct DelayedRecallWordPresentationView: View {
    @StateObject private var coordinator: SpeechCoordinator

    init(words: [String], onPresentationComplete: @escaping () -> Void) {
        _coordinator = StateObject(wrappedValue: SpeechCoordinator(words: words, onComplete: onPresentationComplete))
    }
    
    var body: some View {
        VStack(spacing: 40) {
            if coordinator.currentWordIndex < coordinator.words.count {
                Text(coordinator.words[coordinator.currentWordIndex])
                    .font(.system(size: 72, weight: .bold))
                    .transition(.opacity)
            } else {
                ProgressView("Starting timer...")
            }
            
            HStack(spacing: 8) {
                ForEach(0..<coordinator.words.count, id: \.self) { index in
                    Circle()
                        .fill(index <= coordinator.currentWordIndex ? Color.green : Color.gray.opacity(0.3))
                        .frame(width: 12, height: 12)
                }
            }
        }
        .onAppear {
            coordinator.start()
        }
    }
}

private struct RecallingInstructionsView: View {
    let onStart: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            VStack(spacing: 16) {
                Text("Recall the Words")
                    .font(.system(size: 24, weight: .bold))
                
                Text("The 5-minute waiting period is over. Now, try to recall all the words you learned earlier.")
                    .font(.system(size: 16))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            
            Button("Start Recall Test") {
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


private struct FinishedView: View {
    let score: Int
    let wordCount: Int
    let onContinue: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Delayed Recall Complete")
                .font(.system(size: 28, weight: .bold))
            
            Text("Words recalled: \(score) / \(wordCount)")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.secondary)
            
            Button("Continue") {
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

// MARK: - Reusable components (Countdown, Test)

private struct CountdownView: View {
    let timeRemaining: Int
    
    private var minutes: Int { timeRemaining / 60 }
    private var seconds: Int { timeRemaining % 60 }
    private var progress: Double { max(0, 1.0 - Double(timeRemaining) / 300.0) }
    
    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: "clock")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            VStack(spacing: 16) {
                Text("Memory Retention Period")
                    .font(.system(size: 24, weight: .bold))
                
                Text("Please wait. The recall test will begin automatically when the timer reaches zero.")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            ZStack {
                Circle().stroke(Color.gray.opacity(0.3), lineWidth: 8)
                Circle().trim(from: 0, to: progress)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)
                
                Text("\(minutes):\(String(format: "%02d", seconds))")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
            }
            .frame(width: 120, height: 120)
        }
    }
}

private struct DelayedRecallTest: View {
    let originalWords: [String]
    @Bindable var cognitiveResult: CognitiveResult
    let onComplete: () -> Void
    
    @StateObject private var speechRecognizer = SCAT5SpeechRecognizer()
    @State private var isRecording = false
    @State private var recalledWordsSet = Set<String>()
    @State private var recallTimeRemaining = 30
    @State private var recallTimer: Timer?
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Time remaining: \(recallTimeRemaining)s")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(recallTimeRemaining <= 10 ? .red : .secondary)
            
            if let errorMessage = speechRecognizer.errorMessage {
                Text(errorMessage).foregroundColor(.red)
            }
            
            HStack(spacing: 12) {
                ForEach(0..<originalWords.count, id: \.self) { index in
                    ZStack {
                        RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial)
                        if index < recalledWordsSet.count {
                            RoundedRectangle(cornerRadius: 12).fill(Color.green.opacity(0.8))
                            Image(systemName: "checkmark").font(.system(size: 20, weight: .bold)).foregroundColor(.white)
                        } else {
                            Text("\(index + 1)").foregroundColor(.secondary)
                        }
                    }.frame(width: 60, height: 60)
                }
            }
            
            Spacer()
            
            Button(action: toggleRecording) {
                Image(systemName: isRecording ? "mic.slash.fill" : "mic.fill")
                    .font(.system(size: 48))
                    .foregroundColor(isRecording ? .red : .blue)
                    .frame(width: 120, height: 120)
                    .background(.ultraThinMaterial, in: Circle())
                    .shadow(color: (isRecording ? Color.red : Color.blue).opacity(0.4), radius: 8)
            }.buttonStyle(.plain)
            
            Text(isRecording ? "Listening..." : "Tap to start speaking")
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button("Complete Test", action: completeRecall)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(Color.blue, in: RoundedRectangle(cornerRadius: 16))
        }
        .onAppear(perform: startRecallTimer)
        .onDisappear(perform: cleanup)
        .onReceive(speechRecognizer.$transcript, perform: processTranscript)
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
        if isRecording {
            speechRecognizer.stopTranscribing()
        } else {
            speechRecognizer.transcribe()
        }
        isRecording.toggle()
    }
    
    private func processTranscript(_ transcript: String) {
        let spokenWords = transcript.lowercased().split(separator: " ").map { String($0) }
        for word in spokenWords {
            if let originalWord = originalWords.first(where: { $0.lowercased() == word }) {
                if !recalledWordsSet.contains(originalWord) {
                    withAnimation { recalledWordsSet.insert(originalWord) }
                }
            }
        }
    }
    
    private func completeRecall() {
        cleanup()
        cognitiveResult.delayedRecalledWords = Array(recalledWordsSet)
        onComplete()
    }
    
    private func cleanup() {
        recallTimer?.invalidate()
        recallTimer = nil
        if isRecording {
            speechRecognizer.stopTranscribing()
        }
    }
}


#Preview {
    let container = try! ModelContainer(for: CognitiveResult.self, MemoryTrial.self)
    let sampleCognitiveResult = CognitiveResult()
    
    return DelayedRecallView(
        cognitiveResult: sampleCognitiveResult,
        onComplete: { print("Delayed recall completed") }
    )
    .glassBackgroundEffect()
    .modelContainer(container)
}