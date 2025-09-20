import SwiftUI
import SwiftData

struct StandaloneCognitiveTestView: View, TestController {
    @Bindable var cognitiveResult: CognitiveResult
    let onComplete: () -> Void
    let onSkip: (() -> Void)?
    @Environment(SpeechControlCoordinator.self) private var speechCoordinator
    @State private var currentQuestionIndex = 0
    
    // Cognitive screening questions with their answer types (same as CognitiveTestView)
    private let cognitiveQuestions = [
        ("What month is it?", CognitiveAnswerType.month),
        ("What is the date today?", CognitiveAnswerType.date),
        ("What is the day of the week?", CognitiveAnswerType.day),
        ("What year is it?", CognitiveAnswerType.year),
        ("What time is it right now? (within 1 hour)", CognitiveAnswerType.time)
    ]
    
    enum CognitiveAnswerType {
        case month, date, day, year, time
    }
    
    private var safeQuestionIndex: Int {
        guard !cognitiveQuestions.isEmpty else { return 0 }
        return max(0, min(currentQuestionIndex, cognitiveQuestions.count - 1))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header (clean) with skip button
            VStack(spacing: 12) {
                HStack {
                    Text("Cognitive Screening")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if let onSkip = onSkip {
                        Button("Skip Module") {
                            onSkip()
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.top, 16)
                
                Text("Question \(safeQuestionIndex + 1) of \(cognitiveQuestions.count)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 20)
            }
            
            // Question Content (same layout as CognitiveTestView)
            VStack(spacing: 32) {
                // Question Text
                Text(cognitiveQuestions[safeQuestionIndex].0)
                    .font(.system(size: 20, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 20)
                
                // Answer Input (using the same input views as CognitiveTestView)
                Group {
                    let answerType = cognitiveQuestions[safeQuestionIndex].1
                    switch answerType {
                    case .month:
                        MonthInputView(selectedAnswer: Binding(
                            get: { getAnswer() },
                            set: { setAnswer($0) }
                        ), speechCoordinator: speechCoordinator)
                    case .date:
                        DateInputView(selectedAnswer: Binding(
                            get: { getAnswer() },
                            set: { setAnswer($0) }
                        ), speechCoordinator: speechCoordinator)
                    case .day:
                        DayInputView(selectedAnswer: Binding(
                            get: { getAnswer() },
                            set: { setAnswer($0) }
                        ), speechCoordinator: speechCoordinator)
                    case .year:
                        YearInputView(selectedAnswer: Binding(
                            get: { getAnswer() },
                            set: { setAnswer($0) }
                        ), speechCoordinator: speechCoordinator)
                    case .time:
                        TimeInputView(selectedAnswer: Binding(
                            get: { getAnswer() },
                            set: { setAnswer($0) }
                        ))
                    }
                }
                .padding(.horizontal, 20)
            }
            
            Spacer()
            
            // Navigation (same as CognitiveTestView)
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
                
                if currentQuestionIndex == cognitiveQuestions.count - 1 {
                    Button("Complete Test") {
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
        .frame(width: 700, height: 650)
        .glassBackgroundEffect()
        .onAppear {
            speechCoordinator.testController = self
            
            // Initialize storage using orientation result structure
            if cognitiveResult.orientationResult == nil {
                cognitiveResult.orientationResult = OrientationResult()
            }
        }
        .onDisappear {
            speechCoordinator.testController = nil
        }
        .onChange(of: currentQuestionIndex) { oldValue, newValue in
            if cognitiveQuestions.isEmpty { currentQuestionIndex = 0; return }
            if newValue < 0 { currentQuestionIndex = 0 }
            if newValue >= cognitiveQuestions.count { currentQuestionIndex = cognitiveQuestions.count - 1 }
        }
    }
    
    private func getAnswer() -> String {
        let question = cognitiveQuestions[safeQuestionIndex].0
        
        // Use the orientation result for storage since it has the same structure
        if let orientationResult = cognitiveResult.orientationResult {
            return orientationResult.answers[question] ?? ""
        }
        return ""
    }
    
    private func setAnswer(_ answer: String) {
        let question = cognitiveQuestions[safeQuestionIndex].0
        
        // Use the orientation result for storage
        if cognitiveResult.orientationResult == nil {
            cognitiveResult.orientationResult = OrientationResult()
        }
        cognitiveResult.orientationResult?.answers[question] = answer
    }
    
    func executeCommand(_ command: VoiceCommand) {
        switch command {
        case .nextTrial:
            if currentQuestionIndex < cognitiveQuestions.count - 1 {
                currentQuestionIndex += 1
            }
        case .previousItem:
            if currentQuestionIndex > 0 {
                currentQuestionIndex -= 1
            }
        case .completeTest:
            onComplete()
        case .skipModule:
            onSkip?()
        default:
            break
        }
    }
}