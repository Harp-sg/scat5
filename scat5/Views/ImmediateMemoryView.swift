import SwiftUI
import SwiftData

struct ImmediateMemoryView: View {
    @Bindable var cognitiveResult: CognitiveResult
    let onComplete: () -> Void
    
    @State private var currentTrialIndex = 0
    @State private var viewState: MemoryViewState = .presenting
    
    enum MemoryViewState {
        case presenting
        case recalling
    }
    
    var body: some View {
        VStack {
            Text("Immediate Memory")
                .font(.largeTitle)
                .padding()
            
            Text("Trial \(currentTrialIndex + 1) of 3")
                .font(.headline)
            
            if viewState == .presenting {
                WordPresentationView(words: cognitiveResult.immediateMemoryTrials[currentTrialIndex].words) {
                    // When presentation is done, switch to recalling
                    viewState = .recalling
                }
            } else {
                RecallInputView(trial: $cognitiveResult.immediateMemoryTrials[currentTrialIndex]) {
                    // When recall is done, move to the next trial or finish
                    if currentTrialIndex < 2 {
                        currentTrialIndex += 1
                        viewState = .presenting // Start the next trial
                    } else {
                        onComplete() // All trials are done
                    }
                }
            }
        }
    }
}

// MARK: - Word Presentation View

struct WordPresentationView: View {
    let words: [String]
    let onPresentationComplete: () -> Void
    
    @State private var currentWordIndex = 0
    @State private var timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack {
            Spacer()
            if currentWordIndex < words.count {
                Text(words[currentWordIndex])
                    .font(.system(size: 60, weight: .bold))
                    .transition(.opacity.animation(.easeInOut(duration: 0.2)))
            } else {
                Text("Get Ready to Recall...")
                    .font(.title)
            }
            Spacer()
        }
        .id(currentWordIndex) // Ensures the view updates with the transition
        .onReceive(timer) { _ in
            if currentWordIndex < words.count {
                currentWordIndex += 1
            } else {
                timer.upstream.connect().cancel() // Stop the timer
                onPresentationComplete()
            }
        }
    }
}

// MARK: - Recall Input View

struct RecallInputView: View {
    @Binding var trial: MemoryTrial
    let onRecallComplete: () -> Void
    
    // Using a Set for efficient checking and modification of recalled words
    @State private var recalledWordsSet: Set<String>
    
    init(trial: Binding<MemoryTrial>, onRecallComplete: @escaping () -> Void) {
        self._trial = trial
        self.onRecallComplete = onRecallComplete
        // Initialize the local Set from the bound trial data
        self._recalledWordsSet = State(initialValue: Set(trial.wrappedValue.recalledWords))
    }
    
    var body: some View {
        VStack {
            Text("Select the words the athlete recalls:")
                .font(.headline)
                .padding()
            
            // Grid of word buttons
            let columns = [GridItem(.adaptive(minimum: 120))]
            LazyVGrid(columns: columns, spacing: 15) {
                ForEach(trial.words, id: \.self) { word in
                    Button(action: {
                        toggleWord(word)
                    }) {
                        Text(word)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(recalledWordsSet.contains(word) ? Color.green : Color.secondary.opacity(0.2))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
            }
            .padding()
            
            Spacer()
            
            Text("Score for this trial: \(trial.score)")
                .font(.headline)
            
            Button("Trial Complete") {
                // Save the local set back to the source of truth before completing
                trial.recalledWords = Array(recalledWordsSet)
                onRecallComplete()
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
    }
    
    private func toggleWord(_ word: String) {
        if recalledWordsSet.contains(word) {
            recalledWordsSet.remove(word)
        } else {
            recalledWordsSet.insert(word)
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
    .frame(width: 550, height: 600)
    .background(.black.opacity(0.3))
    .glassBackgroundEffect()
    .cornerRadius(20)
    .modelContainer(container)
}