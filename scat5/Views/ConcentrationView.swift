import SwiftUI
import SwiftData

struct ConcentrationView: View {
    @Bindable var concentrationResult: ConcentrationResult
    let onComplete: () -> Void

    @State private var currentStep: ConcentrationStep = .digitSpan
    
    enum ConcentrationStep {
        case digitSpan
        case monthsReverse
    }
    
    var body: some View {
        VStack {
            switch currentStep {
            case .digitSpan:
                DigitSpanView(concentrationResult: concentrationResult) {
                    currentStep = .monthsReverse
                }
            case .monthsReverse:
                MonthsReverseView(concentrationResult: concentrationResult) {
                    onComplete()
                }
            }
        }
    }
}

// MARK: - Digit Span Backwards View

struct DigitSpanView: View {
    @Bindable var concentrationResult: ConcentrationResult
    let onComplete: () -> Void
    
    @State private var currentSequenceIndex = 0
    @State private var consecutiveFails = 0
    // Simple text input for now, speech/keypad can be added later
    @State private var currentResponse: String = ""

    private var sequences: [[Int]] {
        concentrationResult.digitSequencesPresented
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Concentration: Digits Backwards")
                .font(.largeTitle)
            
            if currentSequenceIndex < sequences.count && consecutiveFails < 2 {
                let sequence = sequences[currentSequenceIndex]
                
                Text("Sequence \(currentSequenceIndex + 1): \(sequence.map(String.init).joined(separator: "-"))")
                    .font(.system(size: 30, weight: .bold, design: .monospaced))
                
                TextField("Enter reversed sequence (e.g., 4-2-7)", text: $currentResponse)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                
                Button("Submit Answer") {
                    processDigitResponse()
                }
                
                Text("Score: \(concentrationResult.digitScore)")
                    .font(.headline)
                
            } else {
                Text(consecutiveFails >= 2 ? "Stopping due to 2 consecutive errors." : "Digit Span Complete.")
                    .font(.headline)
                Button("Continue to Months") {
                    onComplete()
                }
                .buttonStyle(.borderedProminent)
            }
            Spacer()
        }
        .padding(30)
    }
    
    private func processDigitResponse() {
        let expectedResponse = sequences[currentSequenceIndex].reversed().map(String.init).joined()
        let actualResponse = currentResponse.filter("0123456789".contains)
        
        if expectedResponse == actualResponse {
            concentrationResult.digitScore += 1
            consecutiveFails = 0
        } else {
            consecutiveFails += 1
        }
        
        // Store the response (even if incorrect)
        concentrationResult.digitResponses[currentSequenceIndex] = actualResponse.map { Int(String($0))! }
        currentResponse = ""
        currentSequenceIndex += 1
    }
}


// MARK: - Months in Reverse View

struct MonthsReverseView: View {
    @Bindable var concentrationResult: ConcentrationResult
    let onComplete: () -> Void
    
    @State private var isCorrect: Bool = false
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Concentration: Months in Reverse")
                .font(.largeTitle)
            
            Text("Ask the athlete to recite the months of the year in reverse order (December to January).")
                .multilineTextAlignment(.center)
            
            Toggle("Sequence was correct?", isOn: $isCorrect)
                .onChange(of: isCorrect) {
                    concentrationResult.monthsCorrect = isCorrect
                }
            
            Button("Finish Concentration Test") {
                onComplete()
            }
            .buttonStyle(.borderedProminent)
            
            Spacer()
        }
        .padding(30)
    }
}

#Preview {
    let container = try! ModelContainer(for: ConcentrationResult.self)
    let sampleConcentrationResult = ConcentrationResult()
    
    ConcentrationView(
        concentrationResult: sampleConcentrationResult,
        onComplete: { print("Concentration test completed") }
    )
    .frame(width: 550, height: 600)
    .background(.black.opacity(0.3))
    .glassBackgroundEffect()
    .cornerRadius(20)
    .modelContainer(container)
}
