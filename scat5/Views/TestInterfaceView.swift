import SwiftUI
import SwiftData
import RealityKit

struct TestInterfaceView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(SpeechControlCoordinator.self) private var speechCoordinator
    
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
                             }, onSkip: {
                                 // Set default values for skipped symptom test
                                 setDefaultSymptomValues(symptomResult)
                                 session.markModuleSkipped(module.rawValue)
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
    
    // MARK: - Default Value Setters
    
    private func setDefaultSymptomValues(_ symptomResult: SymptomResult) {
        // Set all symptoms to 0 (no symptoms)
        for symptom in Symptom.allCases {
            symptomResult.ratings[symptom.rawValue] = 0
        }
        symptomResult.worsensWithPhysicalActivity = false
        symptomResult.worsensWithMentalActivity = false
        symptomResult.percentOfNormal = 100
    }
    
    private func setDefaultCognitiveValues(_ cognitiveResult: CognitiveResult) {
        // Set default orientation values (perfect score)
        if let orientationResult = cognitiveResult.orientationResult {
            orientationResult.correctCount = 5
            for question in OrientationQuestion.standardQuestions {
                orientationResult.answers[question.prompt] = "Skipped"
            }
        }
        
        // Set default concentration values (perfect score)
        if let concentrationResult = cognitiveResult.concentrationResult {
            concentrationResult.digitScore = 4
            concentrationResult.monthsCorrect = true
        }
        
        // Set default immediate memory values (perfect score)
        for trial in cognitiveResult.immediateMemoryTrials {
            trial.recalledWords = trial.words
        }
        
        // Set default delayed recall values (perfect score)
        cognitiveResult.delayedRecalledWords = cognitiveResult.delayedRecallWordList
    }
    
    private func setDefaultNeurologicalValues(_ neuroResult: NeurologicalResult) {
        // Set all neurological tests to normal
        neuroResult.neckPain = false
        neuroResult.readingNormal = true
        neuroResult.doubleVision = false
        neuroResult.fingerNoseNormal = true
        neuroResult.tandemGaitNormal = true
        neuroResult.tandemGaitTime = 0.0 // Perfect time
    }
    
    private func setDefaultBalanceValues(_ balanceResult: BalanceResult) {
        // Set no errors for all stances
        balanceResult.errorsByStance = [0, 0, 0]
        balanceResult.swayData = []
    }
}

// MARK: - Fallback for Non-Immersive Modules

struct FallbackTestView: View {
    @Bindable var session: TestSession
    let module: TestModule
    
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(SpeechControlCoordinator.self) private var speechCoordinator
    @Environment(AuthService.self) private var authService
    @Environment(ViewRouter.self) private var viewRouter
    @State private var isShowingQuestions = false

    var body: some View {
        VStack(spacing: 0) {
            if isShowingQuestions {
                switch module {
                case .cognitive:
                    if let cognitiveResult = session.cognitiveResult {
                        StandaloneCognitiveTestView(cognitiveResult: cognitiveResult, onComplete: {
                            session.markModuleComplete(module.rawValue)
                            closeImmersiveSpace()
                        }, onSkip: {
                            setDefaultCognitiveValues(cognitiveResult)
                            session.markModuleSkipped(module.rawValue)
                            closeImmersiveSpace()
                        })
                    }
                case .immediateMemory:
                    if let cognitiveResult = session.cognitiveResult {
                        ImmediateMemoryView(cognitiveResult: cognitiveResult, onComplete: {
                            session.markModuleComplete(module.rawValue)
                            closeImmersiveSpace()
                        }, onSkip: {
                            setDefaultImmediateMemoryValues(cognitiveResult)
                            session.markModuleSkipped(module.rawValue)
                            closeImmersiveSpace()
                        })
                    }
                case .balance:
                    if let balanceResult = session.balanceResult {
                        BalanceTestView(balanceResult: balanceResult, onComplete: {
                            session.markModuleComplete(module.rawValue)
                            closeImmersiveSpace()
                        }, onSkip: {
                            setDefaultBalanceValues(balanceResult)
                            session.markModuleSkipped(module.rawValue)
                            closeImmersiveSpace()
                        })
                    }
                case .coordination:
                    if let neuroResult = session.neurologicalResult {
                        CoordinationTestView(neuroResult: neuroResult, onComplete: {
                            session.markModuleComplete(module.rawValue)
                            closeImmersiveSpace()
                        }, onSkip: {
                            setDefaultNeurologicalValues(neuroResult)
                            session.markModuleSkipped(module.rawValue)
                            closeImmersiveSpace()
                        })
                    }
                case .delayedRecall:
                    if let cognitiveResult = session.cognitiveResult {
                        DelayedRecallView(cognitiveResult: cognitiveResult, onComplete: {
                            session.markModuleComplete(module.rawValue)
                            closeImmersiveSpace()
                        }, onSkip: {
                            setDefaultDelayedRecallValues(cognitiveResult)
                            session.markModuleSkipped(module.rawValue)
                            closeImmersiveSpace()
                        })
                    }
                default:
                    Text("This module is not yet implemented.")
                }
            } else {
                ModuleIntroView(module: module, onSkip: {
                    // Handle skip from intro screen
                    switch module {
                    case .cognitive:
                        if let cognitiveResult = session.cognitiveResult {
                            setDefaultCognitiveValues(cognitiveResult)
                        }
                    case .immediateMemory:
                        if let cognitiveResult = session.cognitiveResult {
                            setDefaultImmediateMemoryValues(cognitiveResult)
                        }
                    case .balance:
                        if let balanceResult = session.balanceResult {
                            setDefaultBalanceValues(balanceResult)
                        }
                    case .coordination:
                        if let neuroResult = session.neurologicalResult {
                            setDefaultNeurologicalValues(neuroResult)
                        }
                    case .delayedRecall:
                        if let cognitiveResult = session.cognitiveResult {
                            setDefaultDelayedRecallValues(cognitiveResult)
                        }
                    default:
                        break
                    }
                    session.markModuleSkipped(module.rawValue)
                    closeImmersiveSpace()
                }) {
                    isShowingQuestions = true
                }
            }
        }
        .frame(width: 700, height: 650)
        .glassBackgroundEffect()
        .cornerRadius(20)
        .overlay(alignment: .topTrailing) {
            Button(action: {
                if authService.isEmergencyMode {
                    exitEmergency()
                } else {
                    Task {
                        await dismissImmersiveSpace()
                        appViewModel.isImmersiveSpaceShown = false
                    }
                }
            }) {
                Image(systemName: "xmark")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .padding(12)
                    .background(.regularMaterial, in: Circle())
                    .overlay(
                        Circle()
                            .stroke(.primary.opacity(0.2), lineWidth: 1)
                    )
            }
            .padding(16)
            .buttonStyle(.plain)
        }
        .onAppear {
            speechCoordinator.currentViewContext = .testInterface
            if authService.isEmergencyMode {
                isShowingQuestions = true
            }
        }
    }
    
    private func closeImmersiveSpace() {
        Task {
            await dismissImmersiveSpace()
            appViewModel.isImmersiveSpaceShown = false
        }
    }

    private func exitEmergency() {
        Task {
            await dismissImmersiveSpace()
            await MainActor.run {
                appViewModel.isImmersiveSpaceShown = false
                authService.logout()
                viewRouter.navigate(to: .login)
            }
        }
    }
    
    // Helper function to open immersive balance tests
    private func openImmersiveBalance(_ balanceType: AppView) async {
        // First close current immersive space
        await dismissImmersiveSpace()
        
        // Brief delay to ensure clean transition
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        // Open the appropriate balance test immersive space
        let spaceId: String
        switch balanceType {
        case .balanceStationary:
            spaceId = "BalanceStationary"
        case .balanceRoomScale:
            spaceId = "BalanceRoomScale"
        default:
            return
        }
        
        do {
            try await openImmersiveSpace(id: spaceId)
            // Mark module as complete when user completes the balance test
            // (This will be handled by the balance test views themselves)
        } catch {
            print("Failed to open balance test immersive space: \(error)")
            // Fall back to closing this space
            appViewModel.isImmersiveSpaceShown = false
        }
    }
    
    // MARK: - Default Value Setters
    
    private func setDefaultCognitiveValues(_ cognitiveResult: CognitiveResult) {
        // Set default orientation values (perfect score)
        if let orientationResult = cognitiveResult.orientationResult {
            orientationResult.correctCount = 5
            for question in OrientationQuestion.standardQuestions {
                orientationResult.answers[question.prompt] = "Skipped"
            }
        }
        
        // Set default concentration values (perfect score)
        if let concentrationResult = cognitiveResult.concentrationResult {
            concentrationResult.digitScore = 4
            concentrationResult.monthsCorrect = true
        }
    }
    
    private func setDefaultImmediateMemoryValues(_ cognitiveResult: CognitiveResult) {
        // Set default immediate memory values (perfect score)
        for trial in cognitiveResult.immediateMemoryTrials {
            trial.recalledWords = trial.words
        }
    }
    
    private func setDefaultNeurologicalValues(_ neuroResult: NeurologicalResult) {
        // Set all neurological tests to normal
        neuroResult.neckPain = false
        neuroResult.readingNormal = true
        neuroResult.doubleVision = false
        neuroResult.fingerNoseNormal = true
        neuroResult.tandemGaitNormal = true
        neuroResult.tandemGaitTime = 0.0 // Perfect time
    }
    
    private func setDefaultBalanceValues(_ balanceResult: BalanceResult) {
        // Set no errors for all stances
        balanceResult.errorsByStance = [0, 0, 0]
        balanceResult.swayData = []
    }
    
    private func setDefaultDelayedRecallValues(_ cognitiveResult: CognitiveResult) {
        // Set default delayed recall values (perfect score)
        cognitiveResult.delayedRecalledWords = cognitiveResult.delayedRecallWordList
    }
}

// MARK: - Symptom Test View (Clean & Simple)

struct SymptomTestView: View, TestController {
    @Bindable var symptomResult: SymptomResult
    let onComplete: () -> Void
    let onSkip: () -> Void
    
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(SpeechControlCoordinator.self) private var speechCoordinator
    @Environment(AuthService.self) private var authService
    @Environment(ViewRouter.self) private var viewRouter
    @State private var currentSymptomIndex = 0
    private let symptoms = Symptom.allCases
    
    var body: some View {
        VStack(spacing: 0) {
            // Clean header with skip button
            VStack(spacing: 12) {
                HStack {
                    Text("Symptom Assessment")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button("Skip Module") {
                        onSkip()
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    .padding(.trailing, 50) // Add space to avoid overlap with X button
                }
                
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
        .frame(width: 700, height: 650)
        .glassBackgroundEffect()
        .cornerRadius(20)
        .overlay(alignment: .topTrailing) {
            Button(action: {
                if authService.isEmergencyMode {
                    exitEmergency()
                } else {
                    Task {
                        await dismissImmersiveSpace()
                        appViewModel.isImmersiveSpaceShown = false
                    }
                }
            }) {
                Image(systemName: "xmark")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .padding(12)
                    .background(.regularMaterial, in: Circle())
                    .overlay(
                        Circle()
                            .stroke(.primary.opacity(0.2), lineWidth: 1)
                    )
            }
            .padding(16)
            .buttonStyle(.plain)
        }
        .onAppear {
            speechCoordinator.testController = self
        }
        
        .onDisappear {
            speechCoordinator.testController = nil
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
    
    func executeCommand(_ command: VoiceCommand) {
        switch command {
        case .rate(let value):
            guard (0...6).contains(value) else { return }
            let key = symptoms[currentSymptomIndex].rawValue
            symptomResult.ratings[key] = value
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if currentSymptomIndex < symptoms.count - 1 {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentSymptomIndex += 1
                    }
                }
            }
        case .nextTrial, .nextItem:
            if currentSymptomIndex < symptoms.count - 1 {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentSymptomIndex += 1
                }
            }
        case .previousItem:
            if currentSymptomIndex > 0 {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentSymptomIndex -= 1
                }
            }
        case .completeTest, .submitAnswer:
            onComplete()
        case .startTest:
            // If intro were present, ensure we're on the first question
            if currentSymptomIndex != 0 {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentSymptomIndex = 0
                }
            }
        // Add symptom-specific voice commands
        case .setSymptomRating(let symptom, let rating):
            if let index = symptoms.firstIndex(where: { $0.rawValue == symptom }) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentSymptomIndex = index
                    symptomResult.ratings[symptom] = rating
                }
            }
        case .setToggle(let question, let value):
            if question == "physical" {
                symptomResult.worsensWithPhysicalActivity = value
            } else if question == "mental" {
                symptomResult.worsensWithMentalActivity = value
            }
        case .setPercentNormal(let value):
            symptomResult.percentOfNormal = value
        default:
            break
        }
    }
    
    private func exitEmergency() {
        Task {
            await dismissImmersiveSpace()
            await MainActor.run {
                appViewModel.isImmersiveSpaceShown = false
                authService.logout()
                viewRouter.navigate(to: .login)
            }
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

struct ModuleIntroView: View, TestController {
    let module: TestModule
    let onSkip: () -> Void
    let onStart: () -> Void
    
    @Environment(SpeechControlCoordinator.self) private var speechCoordinator
    
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
            VStack(spacing: 16) {
                Button("Begin Test") {
                    onStart()
                }
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity)
                .background(.blue, in: RoundedRectangle(cornerRadius: 12))
                .foregroundColor(.white)
                
                Button("Skip Module") {
                    onSkip()
                }
                .font(.subheadline)
                .padding()
                .frame(maxWidth: .infinity)
                .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                .foregroundColor(.orange)
            }
        }
        .padding(30)
        .onAppear {
            speechCoordinator.testController = self
        }
        .onDisappear {
            speechCoordinator.testController = nil
        }
    }
    
    func executeCommand(_ command: VoiceCommand) {
        switch command {
        case .startTest, .selectItem, .startRecording:
            onStart()
        default:
            break
        }
    }
}

#Preview("Symptom Test") {
    let container = try! ModelContainer(for: TestSession.self, SymptomResult.self)
    let sampleSession = TestSession(date: .now, sessionType: .concussion)
    let sampleSymptomResult = SymptomResult()
    
    return SymptomTestView(
        symptomResult: sampleSymptomResult,
        onComplete: { print("Symptom test completed") },
        onSkip: { print("Symptom test skipped") }
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