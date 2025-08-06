import SwiftUI

struct BalanceTrialActiveView: View {
    @Bindable var trial: BalanceTrialResult
    @State private var motionManager = MotionManager()
    @State private var timerSeconds = 20
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 20) {
            Text(trial.stance.rawValue).font(.largeTitle)
            
            Text("Time: \(timerSeconds)s")
                .font(.title.monospacedDigit())
                .onReceive(timer) { _ in
                    guard timerSeconds > 0 else {
                        timer.upstream.connect().cancel()
                        return
                    }
                    timerSeconds -= 1
                }

            VStack {
                Text("Live Motion Data")
                HStack(spacing: 20) {
                    Text(String(format: "Pitch: %.2f", motionManager.pitch))
                    Text(String(format: "Roll: %.2f", motionManager.roll))
                    Text(String(format: "Yaw: %.2f", motionManager.yaw))
                }
            }
            .padding()
            .background(.thinMaterial)
            .cornerRadius(10)
            
            Stepper("Errors: \(trial.errorCount)", value: $trial.errorCount, in: 0...10)
                .font(.title2)
                .padding(.horizontal)

            Spacer()
        }
        .padding()
        .onAppear(perform: motionManager.startUpdates)
        .onDisappear(perform: motionManager.stopUpdates)
    }
}