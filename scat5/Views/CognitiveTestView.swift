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
        VStack(spacing: 0) {
            switch currentStep {
            case .orientation:
                OrientationQuestionView(
                    orientationResult: cognitiveResult.orientationResult!,
                    onComplete: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentStep = .immediateMemory
                        }
                    }
                )
            case .immediateMemory:
                VStack {
                    ImmediateMemoryView(
                        cognitiveResult: cognitiveResult,
                        onComplete: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep = .concentration
                            }
                        }
                    )
                    
                    // Back navigation
                    HStack {
                        Button("← Back to Orientation") {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep = .orientation
                            }
                        }
                        .buttonStyle(NavButtonStyle(enabled: true))
                        
                        Spacer()
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 20)
                }
            case .concentration:
                if let concentrationResult = cognitiveResult.concentrationResult {
                    VStack {
                        ConcentrationView(
                            concentrationResult: concentrationResult,
                            onComplete: onComplete
                        )
                        
                        // Back navigation
                        HStack {
                            Button("← Back to Memory") {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    currentStep = .immediateMemory
                                }
                            }
                            .buttonStyle(NavButtonStyle(enabled: true))
                            
                            Spacer()
                        }
                        .padding(.horizontal, 40)
                        .padding(.bottom, 20)
                    }
                } else {
                    Text("Error: Concentration Result not found.")
                        .font(.headline)
                        .foregroundColor(.red)
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: currentStep)
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
            // Clean header
            VStack(spacing: 12) {
                Text("Orientation")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.primary)
                
                Text("Question \(currentQuestionIndex + 1) of \(questions.count)")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 24)
            .padding(.bottom, 20)
            
            // Progress bar
            ProgressView(value: Double(currentQuestionIndex + 1), total: Double(questions.count))
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                .scaleEffect(x: 1, y: 2, anchor: .center)
                .padding(.horizontal, 40)
                .padding(.bottom, 32)
            
            // Question content
            VStack(spacing: 24) {
                let question = questions[currentQuestionIndex]
                
                Text(question.prompt)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 20)
                
                // Answer input based on question type
                Group {
                    switch question.answerType {
                    case .month:
                        ModernMonthInputView(selectedAnswer: Binding(
                            get: { orientationResult.answers[question.prompt] ?? "" },
                            set: { orientationResult.answers[question.prompt] = $0 }
                        ))
                    case .date:
                        ModernTextInputView(
                            placeholder: "Enter date (1-31)",
                            keyboardType: .numberPad,
                            selectedAnswer: Binding(
                                get: { orientationResult.answers[question.prompt] ?? "" },
                                set: { orientationResult.answers[question.prompt] = $0 }
                            )
                        )
                    case .day:
                        ModernDayInputView(selectedAnswer: Binding(
                            get: { orientationResult.answers[question.prompt] ?? "" },
                            set: { orientationResult.answers[question.prompt] = $0 }
                        ))
                    case .year:
                        ModernTextInputView(
                            placeholder: "Enter year",
                            keyboardType: .numberPad,
                            selectedAnswer: Binding(
                                get: { orientationResult.answers[question.prompt] ?? "" },
                                set: { orientationResult.answers[question.prompt] = $0 }
                            )
                        )
                    case .time:
                        ModernTextInputView(
                            placeholder: "Enter time (e.g., 2:30 PM)",
                            keyboardType: .default,
                            selectedAnswer: Binding(
                                get: { orientationResult.answers[question.prompt] ?? "" },
                                set: { orientationResult.answers[question.prompt] = $0 }
                            )
                        )
                    case .text:
                        ModernTextInputView(
                            placeholder: "Enter your answer",
                            keyboardType: .default,
                            selectedAnswer: Binding(
                                get: { orientationResult.answers[question.prompt] ?? "" },
                                set: { orientationResult.answers[question.prompt] = $0 }
                            )
                        )
                    }
                }
            }
            .padding(.bottom, 40)
            
            Spacer()
            
            // Navigation
            HStack(spacing: 30) {
                Button("← Previous") {
                    if currentQuestionIndex > 0 {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentQuestionIndex -= 1
                        }
                    }
                }
                .buttonStyle(NavButtonStyle(enabled: currentQuestionIndex > 0))
                .disabled(currentQuestionIndex <= 0)
                
                Spacer()
                
                if currentQuestionIndex == questions.count - 1 {
                    Button("Next Section") {
                        onComplete()
                    }
                    .buttonStyle(CompleteButtonStyle())
                } else {
                    Button("Next Question →") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentQuestionIndex += 1
                        }
                    }
                    .buttonStyle(NavButtonStyle(enabled: true))
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 20)
        }
    }
}

// MARK: - Modern Input Views

struct ModernMonthInputView: View {
    @Binding var selectedAnswer: String
    let months = Calendar.current.monthSymbols
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
            ForEach(months, id: \.self) { month in
                Button(action: {
                    selectedAnswer = month
                }) {
                    Text(month)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(selectedAnswer == month ? .white : .primary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedAnswer == month ? Color.blue : Color(.systemGray6).opacity(0.5))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selectedAnswer == month ? Color.blue : Color.clear, lineWidth: 2)
                                )
                        )
                        .scaleEffect(selectedAnswer == month ? 1.05 : 1.0)
                        .shadow(
                            color: selectedAnswer == month ? Color.blue.opacity(0.3) : Color.clear,
                            radius: 8,
                            x: 0,
                            y: 4
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: selectedAnswer == month)
            }
        }
        .padding(.horizontal, 20)
    }
}

struct ModernDayInputView: View {
    @Binding var selectedAnswer: String
    let days = Calendar.current.weekdaySymbols
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
            ForEach(days, id: \.self) { day in
                Button(action: {
                    selectedAnswer = day
                }) {
                    Text(day)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(selectedAnswer == day ? .white : .primary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedAnswer == day ? Color.blue : Color(.systemGray6).opacity(0.5))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selectedAnswer == day ? Color.blue : Color.clear, lineWidth: 2)
                                )
                        )
                        .scaleEffect(selectedAnswer == day ? 1.05 : 1.0)
                        .shadow(
                            color: selectedAnswer == day ? Color.blue.opacity(0.3) : Color.clear,
                            radius: 8,
                            x: 0,
                            y: 4
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: selectedAnswer == day)
            }
        }
        .padding(.horizontal, 20)
    }
}

struct ModernTextInputView: View {
    let placeholder: String
    let keyboardType: UIKeyboardType
    @Binding var selectedAnswer: String
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            TextField(placeholder, text: $selectedAnswer)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .keyboardType(keyboardType)
                .focused($isFocused)
                .frame(maxWidth: 300, minHeight: 54)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6).opacity(0.5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isFocused ? Color.blue : Color.clear, lineWidth: 2)
                        )
                )
                .scaleEffect(isFocused ? 1.05 : 1.0)
                .shadow(
                    color: isFocused ? Color.blue.opacity(0.2) : Color.clear,
                    radius: 8,
                    x: 0,
                    y: 4
                )
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isFocused)
            
            // Helpful instruction text
            Text("Tap the field above to enter your answer")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
                .opacity(selectedAnswer.isEmpty ? 1.0 : 0.0)
                .animation(.easeInOut(duration: 0.3), value: selectedAnswer.isEmpty)
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Preview

#Preview {
    let container = try! ModelContainer(for: CognitiveResult.self, OrientationResult.self, ConcentrationResult.self, MemoryTrial.self)
    let sampleCognitiveResult = CognitiveResult()
    
    return CognitiveTestView(
        cognitiveResult: sampleCognitiveResult,
        onComplete: { print("Cognitive test completed") }
    )
    .frame(width: 550, height: 600)
    .glassBackgroundEffect()
    .cornerRadius(20)
    .modelContainer(container)
}