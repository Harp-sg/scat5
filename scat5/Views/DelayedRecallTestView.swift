import SwiftUI

struct DelayedRecallTestView: View {
    @Bindable var cognitiveResult: CognitiveResult
    @State private var recalledWordsInput: String = ""
    
    private var originalWordList: [String] {
        cognitiveResult.immediateMemoryTrials.first?.words ?? []
    }

    var body: some View {
        Form {
            Section(header: Text("Examiner's Reference Word List")) {
                Text(originalWordList.joined(separator: ", ")).foregroundStyle(.secondary)
            }
            
            Section(header: Text("Athlete's Response")) {
                TextField("Enter recalled words...", text: $recalledWordsInput, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: recalledWordsInput) {
                        cognitiveResult.delayedRecalledWords = recalledWordsInput.split(separator: " ").map { String($0) }
                    }
            }
            
            Section(header: Text("Score")) {
                Text("Score: \(cognitiveResult.delayedRecallScore) / 5").font(.headline)
            }
        }
        .navigationTitle("Delayed Recall")
        .onAppear {
            recalledWordsInput = cognitiveResult.delayedRecalledWords.joined(separator: " ")
        }
    }
}