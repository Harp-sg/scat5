import SwiftUI

struct ConcentrationTestView: View {
    @Bindable var cognitiveResult: CognitiveResult
    
    @State private var digitTrialsCorrect: [Bool]
    @State private var monthsInReverseCorrect: Bool

    private let digitTrials = ["4-9-3", "3-8-1-4", "6-2-9-7-1", "7-1-8-4-6-2"]

    init(cognitiveResult: CognitiveResult) {
        self._cognitiveResult = Bindable(wrappedValue: cognitiveResult)
        // A better approach would be to model this state inside CognitiveResult itself
        self._digitTrialsCorrect = State(initialValue: Array(repeating: false, count: 4))
        self._monthsInReverseCorrect = State(initialValue: false)
    }

    var body: some View {
        Form {
            Section(header: Text("Digits Backwards")) {
                ForEach(0..<digitTrials.count, id: \.self) { index in
                    Toggle(digitTrials[index], isOn: $digitTrialsCorrect[index])
                }
            }
            
            Section(header: Text("Months in Reverse")) {
                Toggle("December, November, October...", isOn: $monthsInReverseCorrect)
            }
        }
        .navigationTitle("Concentration")
        .onChange(of: digitTrialsCorrect) { updateTotalScore() }
        .onChange(of: monthsInReverseCorrect) { updateTotalScore() }
    }
    
    private func updateTotalScore() {
        let digitScore = digitTrialsCorrect.filter { $0 }.count
        let monthScore = monthsInReverseCorrect ? 1 : 0
        cognitiveResult.concentrationScore = digitScore + monthScore
    }
}