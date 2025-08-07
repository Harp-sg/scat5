import SwiftUI
import SwiftData

struct DelayedRecallView: View {
    @Bindable var cognitiveResult: CognitiveResult
    let onComplete: () -> Void

    // The word list is sourced from the first memory trial.
    private var wordList: [String] {
        cognitiveResult.immediateMemoryTrials.first?.words ?? []
    }
    
    // Use a Set for efficient checking of recalled words
    @State private var recalledWordsSet: Set<String>

    init(cognitiveResult: CognitiveResult, onComplete: @escaping () -> Void) {
        self._cognitiveResult = Bindable(cognitiveResult)
        self.onComplete = onComplete
        self._recalledWordsSet = State(initialValue: Set(cognitiveResult.delayedRecalledWords))
    }

    var body: some View {
        VStack(spacing: 30) {
            Text("Delayed Recall")
                .font(.largeTitle)
                .padding()

            Text("Ask the athlete to recall the word list from the beginning of the cognitive test.")
                .font(.headline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // Toggles for scoring
            VStack {
                ForEach(wordList, id: \.self) { word in
                    Toggle(word, isOn: Binding(
                        get: { recalledWordsSet.contains(word) },
                        set: { isRecalled in
                            if isRecalled {
                                recalledWordsSet.insert(word)
                            } else {
                                recalledWordsSet.remove(word)
                            }
                            // Update the source of truth
                            cognitiveResult.delayedRecalledWords = Array(recalledWordsSet)
                        }
                    ))
                    .toggleStyle(.button)
                    .cornerRadius(8)
                }
            }
            .padding()
            .background(.thinMaterial)
            .cornerRadius(15)
            
            Text("Score: \(cognitiveResult.delayedRecallScore) / \(wordList.count)")
                .font(.headline)
                .padding(.top)

            Spacer()

            Button("Finish All Tests") {
                onComplete()
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .padding(30)
    }
}

#Preview {
    let container = try! ModelContainer(for: CognitiveResult.self, MemoryTrial.self)
    let sampleCognitiveResult = CognitiveResult()
    
    return DelayedRecallView(
        cognitiveResult: sampleCognitiveResult,
        onComplete: { print("Delayed recall completed") }
    )
    .frame(width: 550, height: 600)
    .background(.black.opacity(0.3))
    .glassBackgroundEffect()
    .cornerRadius(20)
    .modelContainer(container)
}