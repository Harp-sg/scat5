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
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                HStack {
                    Button(action: {
                        // Navigate back to dashboard
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .medium))
                            Text("Dashboard")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    Button(action: {
                        // Close action
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 32, height: 32)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                Text("Orientation")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Question \(currentQuestionIndex + 1) of \(questions.count)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 20)
            }
            
            // Question Content
            VStack(spacing: 32) {
                // Question Text
                Text(questions[currentQuestionIndex].prompt)
                    .font(.system(size: 20, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 20)
                
                // Answer Input
                let question = questions[currentQuestionIndex]
                Group {
                    switch question.answerType {
                    case .month:
                        MonthInputView(selectedAnswer: Binding(
                            get: { orientationResult.answers[question.prompt] ?? "" },
                            set: { orientationResult.answers[question.prompt] = $0 }
                        ))
                    case .date:
                        DateInputView(selectedAnswer: Binding(
                            get: { orientationResult.answers[question.prompt] ?? "" },
                            set: { orientationResult.answers[question.prompt] = $0 }
                        ))
                    case .day:
                        DayInputView(selectedAnswer: Binding(
                            get: { orientationResult.answers[question.prompt] ?? "" },
                            set: { orientationResult.answers[question.prompt] = $0 }
                        ))
                    case .year:
                        YearInputView(selectedAnswer: Binding(
                            get: { orientationResult.answers[question.prompt] ?? "" },
                            set: { orientationResult.answers[question.prompt] = $0 }
                        ))
                    case .time:
                        TimeInputView(selectedAnswer: Binding(
                            get: { orientationResult.answers[question.prompt] ?? "" },
                            set: { orientationResult.answers[question.prompt] = $0 }
                        ))
                    default:
                        TextField("Enter Answer", text: Binding(
                            get: { orientationResult.answers[question.prompt] ?? "" },
                            set: { orientationResult.answers[question.prompt] = $0 }
                        ))
                    }
                }
                .padding(.horizontal, 20)
            }
            
            Spacer()
            
            // Navigation
            HStack(spacing: 16) {
                Button("Previous") {
                    if currentQuestionIndex > 0 {
                        currentQuestionIndex -= 1
                    }
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
                .frame(width: 120, height: 44)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .disabled(currentQuestionIndex == 0)
                .opacity(currentQuestionIndex == 0 ? 0.5 : 1.0)
                .buttonStyle(.plain)
                
                Spacer()
                
                if currentQuestionIndex == questions.count - 1 {
                    Button("Next Question") {
                        onComplete()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 140, height: 44)
                    .background(Color.blue, in: RoundedRectangle(cornerRadius: 12))
                    .buttonStyle(.plain)
                } else {
                    Button("Next Question") {
                        currentQuestionIndex += 1
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 140, height: 44)
                    .background(Color.blue, in: RoundedRectangle(cornerRadius: 12))
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(width: 600, height: 520)
        .glassBackgroundEffect()
    }
}

// MARK: - Input Sub-views for Orientation

struct MonthInputView: View {
    @Binding var selectedAnswer: String
    
    let months = [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]
    
    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)
    }
    
    var body: some View {
        LazyVGrid(columns: gridColumns, spacing: 8) {
            ForEach(months, id: \.self) { month in
                monthButton(for: month)
            }
        }
        .frame(maxWidth: 520)
    }
    
    @ViewBuilder
    private func monthButton(for month: String) -> some View {
        let isSelected = selectedAnswer == month
        
        Button(action: { 
            selectedAnswer = month 
        }) {
            Text(month)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? Color.blue : Color.gray.opacity(0.2))
                )
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? Color.blue : Color.primary.opacity(0.1), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: selectedAnswer)
    }
}

struct DateInputView: View {
    @Binding var selectedAnswer: String
    
    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    }
    
    var body: some View {
        LazyVGrid(columns: gridColumns, spacing: 6) {
            ForEach(1...31, id: \.self) { date in
                dateButton(for: date)
            }
        }
        .frame(maxWidth: 520)
    }
    
    @ViewBuilder
    private func dateButton(for date: Int) -> some View {
        let dateString = "\(date)"
        let isSelected = selectedAnswer == dateString
        
        Button(action: {
            selectedAnswer = dateString
        }) {
            Text(dateString)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : .primary)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(isSelected ? Color.blue : Color.gray.opacity(0.2))
                )
                .background(.ultraThinMaterial, in: Circle())
                .overlay(
                    Circle()
                        .stroke(isSelected ? Color.blue : Color.primary.opacity(0.1), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: selectedAnswer)
    }
}

struct DayInputView: View {
    @Binding var selectedAnswer: String
    
    let days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(days, id: \.self) { day in
                dayButton(for: day)
            }
        }
        .frame(maxWidth: 560)
    }
    
    @ViewBuilder
    private func dayButton(for day: String) -> some View {
        let isSelected = selectedAnswer == day
        
        Button(action: { 
            selectedAnswer = day 
        }) {
            Text(day)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isSelected ? .white : .primary)
                .frame(minWidth: 70, maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? Color.blue : Color.gray.opacity(0.2))
                )
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.blue : Color.primary.opacity(0.1), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: selectedAnswer)
    }
}

struct YearInputView: View {
    @Binding var selectedAnswer: String
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Enter the current year")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            
            TextField("2024", text: $selectedAnswer)
                .font(.system(size: 18, weight: .medium))
                .multilineTextAlignment(.center)
                .frame(width: 120, height: 50)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
                .keyboardType(.numberPad)
        }
    }
}

struct TimeInputView: View {
    @Binding var selectedAnswer: String
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Enter the current time (within ±1 hour)")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            TextField("2:30 PM", text: $selectedAnswer)
                .font(.system(size: 18, weight: .medium))
                .multilineTextAlignment(.center)
                .frame(width: 160, height: 50)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
        }
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