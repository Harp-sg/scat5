import SwiftUI

struct ImmediateMemoryTestView: View {
    @Bindable var cognitiveResult: CognitiveResult

    var body: some View {
        TabView {
            ForEach($cognitiveResult.immediateMemoryTrials) { $trial in
                MemoryTrialView(trial: $trial)
                    .tag(trial.trialNumber)
            }
        }
        .tabViewStyle(.page)
        .navigationTitle("Immediate Memory")
    }
}

private struct MemoryTrialView: View {
    @Binding var trial: MemoryTrial
    @State private var recalledWordsInput: String = ""

    var body: some View {
        Form {
            Section(header: Text("Trial \(trial.trialNumber)")) {
                Text("Read words: \(trial.words.joined(separator: ", "))")
            }
            
            Section(header: Text("Athlete's Response")) {
                TextField("Enter recalled words...", text: $recalledWordsInput, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: recalledWordsInput) {
                        trial.recalledWords = recalledWordsInput
                            .split(separator: " ")
                            .map { String($0).trimmingCharacters(in: .punctuationCharacters) }
                    }
            }
            
            Section(header: Text("Trial Score")) {
                Text("Score: \(trial.score) / 5").font(.headline)
            }
        }
        .onAppear {
            recalledWordsInput = trial.recalledWords.joined(separator: " ")
        }
    }
}