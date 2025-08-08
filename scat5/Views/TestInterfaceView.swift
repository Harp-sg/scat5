import SwiftUI
import SwiftData
import RealityKit

struct TestInterfaceView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    
    // Computed properties to get state from the AppViewModel
    private var session: TestSession? {
        appViewModel.currentSession
    }
    private var module: TestModule? {
        appViewModel.currentModule
    }
    
    var body: some View {
        // We need to unwrap the optional session and module
        if let session = session, let module = module {
             switch module {
             case .symptoms:
                 if let symptomResult = session.symptomResult {
                     // Position symptom assessment at the exact same position as other fallback tests
                     RealityView { content, attachments in
                         let rootEntity = Entity()
                         rootEntity.position = [0, 1.5, -0.75] // Exact same as fallback tests

                         if let attachmentEntity = attachments.entity(for: "symptom_view") {
                             rootEntity.addChild(attachmentEntity)
                             content.add(rootEntity)
                         }
                     } attachments: {
                         Attachment(id: "symptom_view") {
                             SymptomTestView(symptomResult: symptomResult, onComplete: {
                                 session.markModuleComplete(module.rawValue)
                                 Task {
                                     await dismissImmersiveSpace()
                                     appViewModel.isImmersiveSpaceShown = false
                                 }
                             })
                         }
                     }
                 } else {
                     Text("Error: Symptom results not found.")
                 }
             default:
                // Other modules - keep the exact same positioning as before
                RealityView { content, attachments in
                    let rootEntity = Entity()
                    rootEntity.position = [0, 1.5, -0.75] // Position the view in front of the user

                    if let attachmentEntity = attachments.entity(for: "fallback_view") {
                        rootEntity.addChild(attachmentEntity)
                        content.add(rootEntity)
                    }
                } attachments: {
                    Attachment(id: "fallback_view") {
                        FallbackTestView(session: session, module: module)
                    }
                }
             }
        } else {
            Text("No module selected.")
        }
    }
}

// MARK: - Fallback for Non-Immersive Modules

struct FallbackTestView: View {
    @Bindable var session: TestSession
    let module: TestModule
    
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @State private var isShowingQuestions = false

    var body: some View {
        VStack(spacing: 0) {
            // Content
            if isShowingQuestions {
                // This switch statement now correctly routes to the 2D test views
                switch module {
                case .cognitive:
                    if let cognitiveResult = session.cognitiveResult {
                        CognitiveTestView(cognitiveResult: cognitiveResult, onComplete: {
                            session.markModuleComplete(module.rawValue)
                            closeImmersiveSpace()
                        })
                    }
                case .immediateMemory:
                    if let cognitiveResult = session.cognitiveResult {
                        ImmediateMemoryView(cognitiveResult: cognitiveResult, onComplete: {
                            session.markModuleComplete(module.rawValue)
                            closeImmersiveSpace()
                        })
                    }
                case .balance:
                    if let balanceResult = session.balanceResult {
                        BalanceTestView(balanceResult: balanceResult, onComplete: {
                            session.markModuleComplete(module.rawValue)
                            closeImmersiveSpace()
                        })
                    }
                case .coordination:
                    if let neuroResult = session.neurologicalResult {
                        CoordinationTestView(neuroResult: neuroResult, onComplete: {
                            session.markModuleComplete(module.rawValue)
                            closeImmersiveSpace()
                        })
                    }
                case .delayedRecall:
                    if let cognitiveResult = session.cognitiveResult {
                        DelayedRecallView(cognitiveResult: cognitiveResult, onComplete: {
                            session.markModuleComplete(module.rawValue)
                            closeImmersiveSpace()
                        })
                    }
                default:
                    Text("This module is not yet implemented.")
                }
            } else {
                ModuleIntroView(module: module) {
                    isShowingQuestions = true
                }
            }
        }
        .frame(width: 550, height: 600)
        .glassBackgroundEffect()
        .cornerRadius(20)
        .overlay(alignment: .topTrailing) {
            // Floating close button
            Button(action: { closeImmersiveSpace() }) {
                Image(systemName: "xmark")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(.white.opacity(0.1))
                    .clipShape(Circle())
            }
            .padding()
        }
    }
    
    private func closeImmersiveSpace() {
        Task {
            await dismissImmersiveSpace()
            appViewModel.isImmersiveSpaceShown = false
        }
    }
}

// MARK: - Symptom Test View (Clean & Simple)

struct SymptomTestView: View {
    @Bindable var symptomResult: SymptomResult
    let onComplete: () -> Void
    
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @State private var currentSymptomIndex = 0
    private let symptoms = Symptom.allCases
    
    var body: some View {
        VStack(spacing: 0) {
            // Clean header
            VStack(spacing: 12) {
                Text("Symptom Assessment")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.primary)
                
                Text("Question \(currentSymptomIndex + 1) of \(symptoms.count)")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 24)
            .padding(.bottom, 20)
            
            // Progress bar
            ProgressView(value: Double(currentSymptomIndex + 1), total: Double(symptoms.count))
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                .scaleEffect(x: 1, y: 2, anchor: .center)
                .padding(.horizontal, 40)
                .padding(.bottom, 32)
            
            // Current symptom
            VStack(spacing: 24) {
                Text(symptoms[currentSymptomIndex].rawValue)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 20)
                
                Text("Rate severity from 0 (none) to 6 (severe)")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 8)
                
                // Rating buttons - clean and simple
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 12) {
                    ForEach(0...6, id: \.self) { rating in
                        Button(action: {
                            symptomResult.ratings[symptoms[currentSymptomIndex].rawValue] = rating
                            
                            // Auto advance to next question
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                if currentSymptomIndex < symptoms.count - 1 {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        currentSymptomIndex += 1
                                    }
                                }
                            }
                        }) {
                            VStack(spacing: 4) {
                                Text("\(rating)")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text(getRatingLabel(rating))
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .frame(width: 50, height: 50)
                            .background(
                                Circle()
                                    .fill(getRatingColor(rating))
                                    .overlay(
                                        Circle()
                                            .stroke(.white.opacity(0.3), lineWidth: 1)
                                    )
                            )
                            .scaleEffect(
                                symptomResult.ratings[symptoms[currentSymptomIndex].rawValue] == rating ? 1.2 : 1.0
                            )
                            .shadow(
                                color: symptomResult.ratings[symptoms[currentSymptomIndex].rawValue] == rating ? getRatingColor(rating) : .clear,
                                radius: 8,
                                x: 0,
                                y: 4
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: symptomResult.ratings[symptoms[currentSymptomIndex].rawValue])
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 40)
            
            Spacer()
            
            // Navigation
            HStack(spacing: 30) {
                Button("← Previous") {
                    if currentSymptomIndex > 0 {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentSymptomIndex -= 1
                        }
                    }
                }
                .buttonStyle(NavButtonStyle(enabled: currentSymptomIndex > 0))
                .disabled(currentSymptomIndex <= 0)
                
                Spacer()
                
                Button("Next →") {
                    if currentSymptomIndex < symptoms.count - 1 {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentSymptomIndex += 1
                        }
                    }
                }
                .buttonStyle(NavButtonStyle(enabled: currentSymptomIndex < symptoms.count - 1))
                .disabled(currentSymptomIndex >= symptoms.count - 1)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 20)
            
            // Final controls (only show on last question)
            if currentSymptomIndex >= symptoms.count - 1 {
                VStack(spacing: 16) {
                    Divider()
                        .padding(.horizontal, 40)
                    
                    // Activity questions - simplified
                    HStack(spacing: 20) {
                        Toggle("Worse with physical activity?", isOn: Binding(
                            get: { symptomResult.worsensWithPhysicalActivity },
                            set: { symptomResult.worsensWithPhysicalActivity = $0 }
                        ))
                        .toggleStyle(SimpleToggleStyle())
                        
                        Toggle("Worse with mental activity?", isOn: Binding(
                            get: { symptomResult.worsensWithMentalActivity },
                            set: { symptomResult.worsensWithMentalActivity = $0 }
                        ))
                        .toggleStyle(SimpleToggleStyle())
                    }
                    .padding(.horizontal, 40)
                    
                    // Percent normal - simplified
                    VStack(spacing: 12) {
                        Text("Overall feeling: \(symptomResult.percentOfNormal)%")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Slider(
                            value: Binding(
                                get: { Double(symptomResult.percentOfNormal) },
                                set: { symptomResult.percentOfNormal = Int($0) }
                            ),
                            in: 0...100,
                            step: 5
                        ) {
                            Text("Percent Normal")
                        }
                        .accentColor(.blue)
                        .padding(.horizontal, 40)
                    }
                    
                    // Complete button
                    Button("Complete Assessment") {
                        onComplete()
                    }
                    .buttonStyle(CompleteButtonStyle())
                    .padding(.top, 8)
                }
                .padding(.bottom, 20)
                .transition(.opacity)
            }
        }
        .frame(width: 550, height: 600)
        .glassBackgroundEffect()
        .cornerRadius(20)
        .overlay(alignment: .topTrailing) {
            Button(action: {
                Task {
                    await dismissImmersiveSpace()
                    appViewModel.isImmersiveSpaceShown = false
                }
            }) {
                Image(systemName: "xmark")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(.white.opacity(0.1))
                    .clipShape(Circle())
            }
            .padding()
        }
    }
    
    private func getRatingLabel(_ rating: Int) -> String {
        switch rating {
        case 0: return "None"
        case 1: return "Mild"
        case 2: return "Mild+"
        case 3: return "Mod"
        case 4: return "Mod+"
        case 5: return "Severe"
        case 6: return "Max"
        default: return ""
        }
    }
    
    private func getRatingColor(_ rating: Int) -> Color {
        switch rating {
        case 0: return .green
        case 1...2: return .yellow
        case 3...4: return .orange
        case 5...6: return .red
        default: return .gray
        }
    }
}

// MARK: - Button Styles

struct NavButtonStyle: ButtonStyle {
    let enabled: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(enabled ? .blue : .gray)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color.blue.opacity(enabled ? (configuration.isPressed ? 0.2 : 0.1) : 0.05))
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct CompleteButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(.green)
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SimpleToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(configuration.isOn ? "YES" : "NO")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(configuration.isOn ? .green : .red)
                .frame(width: 35)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6).opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(configuration.isOn ? .green.opacity(0.5) : .red.opacity(0.3), lineWidth: 1)
                )
        )
        .onTapGesture {
            configuration.isOn.toggle()
        }
    }
}

// MARK: - Module Introduction View

struct ModuleIntroView: View {
    let module: TestModule
    let onStart: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            Image(systemName: module.icon)
                .font(.system(size: 80, weight: .light))
                .foregroundColor(.primary)
            
            Text(module.rawValue)
                .font(.largeTitle)
            
            Text(module.instructions)
                .font(.headline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
            
            Button("Begin Test") {
                onStart()
            }
            .font(.headline)
            .padding()
            .frame(maxWidth: .infinity)

        }
        .padding(30)
    }
}

#Preview("Symptom Test") {
    let container = try! ModelContainer(for: TestSession.self, SymptomResult.self)
    let sampleSession = TestSession(date: .now, sessionType: .concussion)
    let sampleSymptomResult = SymptomResult()
    
    return SymptomTestView(
        symptomResult: sampleSymptomResult,
        onComplete: { print("Symptom test completed") }
    )
    .environment(AppViewModel())
    .modelContainer(container)
}

#Preview("Balance Test") {
    let container = try! ModelContainer(for: TestSession.self, BalanceResult.self)
    let sampleSession = TestSession(date: .now, sessionType: .concussion)
    
    return FallbackTestView(
        session: sampleSession,
        module: .balance
    )
    .environment(AppViewModel())
    .modelContainer(container)
}

#Preview("Cognitive Test") {
    let container = try! ModelContainer(for: TestSession.self, CognitiveResult.self)
    let sampleSession = TestSession(date: .now, sessionType: .concussion)
    
    return FallbackTestView(
        session: sampleSession,
        module: .cognitive
    )
    .environment(AppViewModel())
    .modelContainer(container)
}