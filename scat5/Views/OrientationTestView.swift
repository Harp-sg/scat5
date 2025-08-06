import SwiftUI

struct OrientationTestView: View {
    @Bindable var cognitiveResult: CognitiveResult
    @State private var selections: [Bool]
    
    private let questions = [
        "What month is it?", "What is today's date?", "What day of the week is it?",
        "What year is it?", "What time is it (within 1 hour)?"
    ]

    init(cognitiveResult: CognitiveResult) {
        self._cognitiveResult = Bindable(wrappedValue: cognitiveResult)
        // Initialize state from the model, but only once.
        self._selections = State(initialValue: Array(repeating: false, count: questions.count))
    }
    
    var body: some View {
        Form {
            Section(header: Text("Orientation (1 point for each correct answer)")) {
                ForEach(0..<questions.count, id: \.self) { index in
                    Toggle(questions[index], isOn: $selections[index])
                }
            }
        }
        .navigationTitle("Orientation")
        .onChange(of: selections) {
            cognitiveResult.orientationScore = selections.filter { $0 }.count
        }
        .onAppear(perform: loadInitialScores)
    }

    private func loadInitialScores() {
        // This is a workaround to reflect the model's state if we re-enter the view.
        // A more robust solution might involve a custom binding.
        let score = cognitiveResult.orientationScore
        selections = (0..<questions.count).map { $0 < score }
    }
}