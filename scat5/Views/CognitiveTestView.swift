import SwiftUI
import SwiftData

struct CognitiveTestView: View {
    @Bindable var cognitiveResult: CognitiveResult
    let onComplete: () -> Void
    
    // State to manage which part of the test is active
    @State private var currentStep: CognitiveStep = .orientation
    
    enum CognitiveStep {
        case orientation
        case immediateMemory
        case concentration
    }
    
    var body: some View {
        VStack {
            switch currentStep {
            case .orientation:
                OrientationQuestionView(
                    orientationResult: cognitiveResult.orientationResult!,
                    onComplete: {
                        currentStep = .immediateMemory
                    }
                )
            case .immediateMemory:
                ImmediateMemoryView(
                    cognitiveResult: cognitiveResult,
                    onComplete: {
                        currentStep = .concentration
                    }
                )
                Button("Back to Orientation") {
                    currentStep = .orientation
                }
            case .concentration:
                if let concentrationResult = cognitiveResult.concentrationResult {
                    ConcentrationView(
                        concentrationResult: concentrationResult,
                        onComplete: onComplete
                    )
                    Button("Back to Immediate Memory") {
                        currentStep = .immediateMemory
                    }
                } else {
                    Text("Error: Concentration Result not found.")
                }
            }
        }
    }
}

// MARK: - Orientation View

struct OrientationQuestionView: View {
    @Bindable var orientationResult: OrientationResult
    let onComplete: () -> Void
    
    @State private var currentQuestionIndex = 0
    private let questions = OrientationQuestion.standardQuestions
    
    var body: some View {
        VStack {
            Text("Orientation")
                .font(.largeTitle)
                .padding()
            
            Text("Question \(currentQuestionIndex + 1) of \(questions.count)")
                .font(.headline)
            
            Spacer()
            
            // Display the current question prompt
            let question = questions[currentQuestionIndex]
            Text(question.prompt)
                .font(.title)
                .multilineTextAlignment(.center)
                .padding()

            // Display the appropriate input view based on the question type
            switch question.answerType {
            case .month:
                MonthInputView(selectedAnswer: Binding(
                    get: { orientationResult.answers[question.prompt] ?? "" },
                    set: { orientationResult.answers[question.prompt] = $0 }
                ))
            case .date:
                // Placeholder for Date keypad
                TextField("Enter Date", text: Binding(
                    get: { orientationResult.answers[question.prompt] ?? "" },
                    set: { orientationResult.answers[question.prompt] = $0 }
                )).keyboardType(.numberPad)
            case .day:
                DayInputView(selectedAnswer: Binding(
                    get: { orientationResult.answers[question.prompt] ?? "" },
                    set: { orientationResult.answers[question.prompt] = $0 }
                ))
            default:
                // Placeholder for Year and Time text fields
                TextField("Enter Answer", text: Binding(
                    get: { orientationResult.answers[question.prompt] ?? "" },
                    set: { orientationResult.answers[question.prompt] = $0 }
                ))
            }

            Spacer()
            
            // Navigation
            HStack {
                Button("Previous") {
                    if currentQuestionIndex > 0 {
                        currentQuestionIndex -= 1
                    }
                }
                .disabled(currentQuestionIndex == 0)
                
                Spacer()
                
                if currentQuestionIndex == questions.count - 1 {
                    Button("Next Section") {
                        // Before completing, we would calculate the `correctCount`
                        onComplete()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Next Question") {
                        currentQuestionIndex += 1
                    }
                }
            }
            .padding()
        }
        .padding()
    }
}

// MARK: - Input Sub-views for Orientation

struct MonthInputView: View {
    @Binding var selectedAnswer: String
    let months = Calendar.current.monthSymbols
    let columns = [GridItem(.adaptive(minimum: 100))]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(months, id: \.self) { month in
                Button(action: { selectedAnswer = month }) {
                    Text(month)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedAnswer == month ? Color.blue : Color.secondary.opacity(0.2))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
    }
}

struct DayInputView: View {
    @Binding var selectedAnswer: String
    let days = Calendar.current.weekdaySymbols
    let columns = [GridItem(.adaptive(minimum: 100))]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(days, id: \.self) { day in
                Button(action: { selectedAnswer = day }) {
                    Text(day)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedAnswer == day ? Color.blue : Color.secondary.opacity(0.2))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
    }
}

#Preview {
    let container = try! ModelContainer(for: CognitiveResult.self, OrientationResult.self, ConcentrationResult.self, MemoryTrial.self)
    let sampleCognitiveResult = CognitiveResult()
    
    return CognitiveTestView(
        cognitiveResult: sampleCognitiveResult,
        onComplete: { print("Cognitive test completed") }
    )
    .frame(width: 550, height: 600)
    .background(.black.opacity(0.3))
    .glassBackgroundEffect()
    .cornerRadius(20)
    .modelContainer(container)
}