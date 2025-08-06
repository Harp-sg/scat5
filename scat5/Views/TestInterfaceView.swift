import SwiftUI

struct TestInterfaceView: View {
    @Bindable var session: TestSession
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthService.self) private var authService
    
    @State private var currentModule = ""
    @State private var currentQuestionIndex = 0
    @State private var isShowingQuestion = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                // Floating test window
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text(currentModule)
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button("×") {
                            dismiss()
                        }
                        .font(.title2)
                        .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.blue)
                    
                    // Content area
                    Group {
                        if isShowingQuestion {
                            QuestionView(
                                session: session,
                                module: currentModule,
                                questionIndex: currentQuestionIndex
                            ) { completed in
                                if completed {
                                    session.markModuleComplete(currentModule)
                                }
                                dismiss()
                            }
                        } else {
                            ModuleIntroView(moduleName: currentModule) {
                                isShowingQuestion = true
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                }
                .frame(width: 400, height: 500)
                .cornerRadius(12)
                .shadow(radius: 20)
            }
        }
        .onAppear {
            // Set the current module based on what was selected
            // This would be passed in from the calling view
        }
    }
}

struct ModuleIntroView: View {
    let moduleName: String
    let onStart: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: iconForModule(moduleName))
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text(moduleName)
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text(instructionsForModule(moduleName))
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Button("Begin Test") {
                onStart()
            }
            .buttonStyle(.borderedProminent)
            .font(.headline)
        }
        .padding()
    }
    
    private func iconForModule(_ module: String) -> String {
        switch module {
        case "Symptom": return "list.bullet.clipboard"
        case "Cognitive": return "brain"
        case "Balance": return "figure.stand"
        case "Coordination": return "hand.point.up.braille"
        case "DelayedRecall": return "clock.arrow.circlepath"
        default: return "questionmark.circle"
        }
    }
    
    private func instructionsForModule(_ module: String) -> String {
        switch module {
        case "Symptom":
            return "Rate your current symptoms on a scale of 0-6, where 0 means no symptoms and 6 means severe symptoms."
        case "Cognitive":
            return "Complete orientation, memory, and concentration tests. Follow the examiner's instructions carefully."
        case "Balance":
            return "Perform balance tests in different stances. Stay as still as possible during each 20-second trial."
        case "Coordination":
            return "Complete finger-to-nose and tandem gait tests. Follow the examiner's guidance."
        case "DelayedRecall":
            return "Try to recall the words from the earlier memory test. Say all the words you can remember."
        default:
            return "Follow the instructions provided by your examiner."
        }
    }
}

struct QuestionView: View {
    @Bindable var session: TestSession
    let module: String
    let questionIndex: Int
    let onComplete: (Bool) -> Void
    
    var body: some View {
        VStack {
            // This would contain the actual test content
            // For now, showing a placeholder
            Text("Question \(questionIndex + 1)")
                .font(.title)
            
            Text("Test content would go here")
                .foregroundColor(.secondary)
            
            Spacer()
            
            HStack {
                Button("Previous") {
                    // Handle previous question
                }
                .disabled(questionIndex == 0)
                
                Spacer()
                
                Button("Next") {
                    // Handle next question or completion
                    onComplete(true)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .padding()
    }
}