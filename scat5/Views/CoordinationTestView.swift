import SwiftUI
import SwiftData

struct CoordinationTestView: View, TestController {
    @Bindable var neuroResult: NeurologicalResult
    let onComplete: () -> Void
    let onSkip: (() -> Void)?
    @State private var page = 0
    @Environment(SpeechControlCoordinator.self) private var speechCoordinator

    var body: some View {
        VStack {
            HStack {
                Text("Neurological & Coordination Exam")
                    .font(.largeTitle)
                    .padding()
                
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
                    .padding(.trailing, 16)
                }
            }
            
            TabView(selection: $page) {
                NeckExamView(neuroResult: neuroResult)
                    .tag(0)
                    .tabItem { Text("Neck Exam") }
                
                ReadingExamView(neuroResult: neuroResult)
                    .tag(1)
                    .tabItem { Text("Reading") }
                    
                GazeExamView(neuroResult: neuroResult)
                    .tag(2)
                    .tabItem { Text("Gaze Stability") }
                    
                FingerNoseExamView(neuroResult: neuroResult)
                    .tag(3)
                    .tabItem { Text("Finger-to-Nose") }
                    
                TandemGaitExamView(neuroResult: neuroResult)
                    .tag(4)
                    .tabItem { Text("Tandem Gait") }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            
            Button("Finish Neurological Exam") {
                onComplete()
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .onAppear { speechCoordinator.testController = self }
        .onDisappear { speechCoordinator.testController = nil }
    }
    
    func executeCommand(_ command: VoiceCommand) {
        switch command {
        case .nextItem, .nextTrial:
            if page < 4 { page += 1 }
        case .previousItem:
            if page > 0 { page -= 1 }
        case .completeTest:
            onComplete()
        case .skipModule:
            onSkip?()
        case .markCorrect:
            toggleCurrentTestResult(to: true)
        case .markIncorrect:
            toggleCurrentTestResult(to: false)
        case .selectItemByName(let name):
            navigateToTest(named: name)
        default: break
        }
    }
    
    private func navigateToTest(named name: String) {
        switch name {
        case "Neck Exam":
            page = 0
        case "Reading":
            page = 1
        case "Gaze Stability":
            page = 2
        case "Finger-to-Nose":
            page = 3
        case "Tandem Gait":
            page = 4
        default:
            break
        }
    }
    
    private func toggleCurrentTestResult(to value: Bool) {
        switch page {
        case 0: // Neck Exam
            neuroResult.neckPain = !value // Inverted because pain = not normal
        case 1: // Reading Exam
            neuroResult.readingNormal = value
        case 2: // Gaze Exam
            neuroResult.doubleVision = !value // Inverted because double vision = not normal
        case 3: // Finger-Nose Exam
            neuroResult.fingerNoseNormal = value
        case 4: // Tandem Gait Exam
            neuroResult.tandemGaitNormal = value
        default:
            break
        }
    }
}

// MARK: - Sub-test Views

struct NeckExamView: View {
    @Bindable var neuroResult: NeurologicalResult
    var body: some View {
        VStack(spacing: 20) {
            Text("Neck Examination")
                .font(.headline)
            Text("Assess for full, pain-free passive cervical range of motion.")
            Toggle("Athlete reports neck pain?", isOn: $neuroResult.neckPain)
            Spacer()
        }.padding(30)
    }
}

struct ReadingExamView: View {
    @Bindable var neuroResult: NeurologicalResult
    var body: some View {
        VStack(spacing: 20) {
            Text("Reading & Following Instructions")
                .font(.headline)
            Text("The quick brown fox jumps over the lazy dog.")
                .padding().border(Color.secondary)
            Text("Instruction: \"Touch your left ear when you finish.\"")
            Toggle("Reading and instructions followed normally?", isOn: $neuroResult.readingNormal)
            Spacer()
        }.padding(30)
    }
}

struct GazeExamView: View {
    @Bindable var neuroResult: NeurologicalResult
    var body: some View {
        VStack(spacing: 20) {
            Text("Gaze Stability")
                .font(.headline)
            Text("Examiner moves a dot/finger and checks for smooth pursuit. Ask about double vision.")
            // Placeholder for animated dot
            Circle().fill(.blue).frame(width: 50, height: 50)
            Toggle("Athlete reports double vision?", isOn: $neuroResult.doubleVision)
            Spacer()
        }.padding(30)
    }
}

struct FingerNoseExamView: View {
    @Bindable var neuroResult: NeurologicalResult
    var body: some View {
        VStack(spacing: 20) {
            Text("Finger-to-Nose Coordination")
                .font(.headline)
            Text("Athlete touches their nose 5 times with their index finger.")
            Toggle("Performance was normal?", isOn: $neuroResult.fingerNoseNormal)
            Spacer()
        }.padding(30)
    }
}

struct TandemGaitExamView: View {
    @Bindable var neuroResult: NeurologicalResult
    // Placeholder for timer logic
    @State private var time: Double = 0.0
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Tandem Gait")
                .font(.headline)
            Text("Athlete walks 3m heel-to-toe and returns.")
            Toggle("Performance was normal?", isOn: $neuroResult.tandemGaitNormal)
            TextField("Time taken (optional)", value: $time, format: .number)
                .keyboardType(.decimalPad)
                .onChange(of: time) {
                    neuroResult.tandemGaitTime = time
                }
            Spacer()
        }.padding(30)
    }
}

#Preview {
    let container = try! ModelContainer(for: NeurologicalResult.self)
    let sampleNeuroResult = NeurologicalResult()
    
    return CoordinationTestView(
        neuroResult: sampleNeuroResult,
        onComplete: { print("Coordination test completed") },
        onSkip: { print("Coordination test skipped") }
    )
    .frame(width: 550, height: 600)
    .background(.black.opacity(0.3))
    .glassBackgroundEffect()
    .cornerRadius(20)
    .modelContainer(container)
}