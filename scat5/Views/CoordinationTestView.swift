import SwiftUI
import SwiftData

struct CoordinationTestView: View {
    @Bindable var neuroResult: NeurologicalResult
    let onComplete: () -> Void

    var body: some View {
        VStack {
            Text("Neurological & Coordination Exam")
                .font(.largeTitle)
                .padding()
            
            TabView {
                NeckExamView(neuroResult: neuroResult)
                    .tabItem { Text("Neck Exam") }
                
                ReadingExamView(neuroResult: neuroResult)
                    .tabItem { Text("Reading") }
                    
                GazeExamView(neuroResult: neuroResult)
                    .tabItem { Text("Gaze Stability") }
                    
                FingerNoseExamView(neuroResult: neuroResult)
                    .tabItem { Text("Finger-to-Nose") }
                    
                TandemGaitExamView(neuroResult: neuroResult)
                    .tabItem { Text("Tandem Gait") }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            
            Button("Finish Neurological Exam") {
                onComplete()
            }
            .buttonStyle(.borderedProminent)
            .padding()
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
        onComplete: { print("Coordination test completed") }
    )
    .frame(width: 550, height: 600)
    .background(.black.opacity(0.3))
    .glassBackgroundEffect()
    .cornerRadius(20)
    .modelContainer(container)
}