import SwiftUI
import SwiftData

struct StandaloneOrientationTestView: View, TestController {
    @Bindable var cognitiveResult: CognitiveResult
    let onComplete: () -> Void
    @Environment(SpeechControlCoordinator.self) private var speechCoordinator
    @State private var currentQuestionIndex = 0
    
    // Orientation-specific questions
    private let orientationQuestions = [
        "What venue are we at today?",
        "Which half of the field are we in right now?",
        "Who did you play last week?",
        "Did you win the last game?"
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Orientation Assessment")
                .font(.largeTitle)
                .padding(.top)
            
            Text("Question \(currentQuestionIndex + 1) of \(orientationQuestions.count)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            ProgressView(value: Double(currentQuestionIndex + 1), total: Double(orientationQuestions.count))
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                .padding(.horizontal, 40)
            
            Spacer()
            
            Text(orientationQuestions[currentQuestionIndex])
                .font(.title2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            
            Spacer()
            
            // Answer buttons
            HStack(spacing: 30) {
                Button("Incorrect") {
                    recordAnswer(correct: false)
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
                
                Button("Correct") {
                    recordAnswer(correct: true)
                }
                .buttonStyle(.borderedProminent)
                .foregroundColor(.white)
            }
            .padding(.bottom, 40)
        }
        .onAppear {
            speechCoordinator.testController = self
        }
        .onDisappear {
            speechCoordinator.testController = nil
        }
    }
    
    private func recordAnswer(correct: Bool) {
        // Record the answer to the orientation results
        
        if currentQuestionIndex < orientationQuestions.count - 1 {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentQuestionIndex += 1
            }
        } else {
            // Complete the test
            onComplete()
        }
    }
    
    func executeCommand(_ command: VoiceCommand) {
        switch command {
        case .markCorrect:
            recordAnswer(correct: true)
        case .markIncorrect:
            recordAnswer(correct: false)
        case .nextTrial:
            if currentQuestionIndex < orientationQuestions.count - 1 {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentQuestionIndex += 1
                }
            }
        case .previousItem:
            if currentQuestionIndex > 0 {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentQuestionIndex -= 1
                }
            }
        case .completeTest:
            onComplete()
        default:
            break
        }
    }
}