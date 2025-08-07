import SwiftUI
import SwiftData

struct BalanceTestView: View {
    @Bindable var balanceResult: BalanceResult
    let onComplete: () -> Void

    @State private var motionManager = MotionManager()
    @State private var currentStanceIndex = 0
    @State private var timerValue = 20
    @State private var isTimerRunning = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    private var currentStance: BalanceStance {
        BalanceStance.allCases[currentStanceIndex]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header Section
            VStack(spacing: 8) {
                Text("Balance Assessment")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                
                Text(currentStance.rawValue)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)
            .padding(.bottom, 16)
            
            // Timer Section
            Text("Time Remaining: \(timerValue)s")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .padding(.bottom, 32)
            
            // Error Counter Section
            VStack(spacing: 16) {
                Text("Errors: \(balanceResult.errorsByStance[currentStanceIndex])")
                    .font(.system(size: 72, weight: .heavy))
                    .foregroundColor(.white)
                
                Button("Add Error (+1)") {
                    if balanceResult.errorsByStance[currentStanceIndex] < 10 {
                        balanceResult.errorsByStance[currentStanceIndex] += 1
                    }
                }
                .buttonStyle(AddErrorButtonStyle())
                .disabled(balanceResult.errorsByStance[currentStanceIndex] >= 10)
            }
            .padding(.bottom, 40)
            
            // Motion Data Section
            VStack(spacing: 12) {
                Text("Live Head Sway Data")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                HStack(spacing: 32) {
                    MotionValueView(label: "Pitch", value: motionManager.pitch)
                    MotionValueView(label: "Roll", value: motionManager.roll)
                    MotionValueView(label: "Yaw", value: motionManager.yaw)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .background(.white.opacity(0.08))
                .cornerRadius(16)
            }
            .padding(.bottom, 40)
            
            Spacer()
            
            // Action Buttons
            VStack(spacing: 12) {
                if currentStanceIndex < BalanceStance.allCases.count - 1 && (timerValue < 20 || !isTimerRunning) {
                    Button("Finish Balance Test") {
                        onComplete()
                    }
                    .buttonStyle(FinishButtonStyle())
                }
                
                Button(timerValue == 20 ? "Start 20s Trial" : (isTimerRunning ? "Pause Trial" : "Resume Trial")) {
                    isTimerRunning.toggle()
                }
                .buttonStyle(StartButtonStyle(isActive: isTimerRunning))
                .disabled(timerValue == 0)
            }
            .padding(.bottom, 32)
        }
        .padding(.horizontal, 32)
        .onAppear {
            motionManager.startUpdates()
        }
        .onDisappear {
            motionManager.stopUpdates()
        }
        .onReceive(timer) { _ in
            guard isTimerRunning else { return }
            if timerValue > 0 {
                timerValue -= 1
            } else {
                isTimerRunning = false
                // Auto-advance to next stance when timer completes
                if currentStanceIndex < BalanceStance.allCases.count - 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        currentStanceIndex += 1
                        timerValue = 20
                    }
                }
            }
        }
    }
}

// MARK: - Custom Button Styles

struct AddErrorButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 12)
            .background(.white.opacity(configuration.isPressed ? 0.1 : 0.15))
            .cornerRadius(25)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct StartButtonStyle: ButtonStyle {
    let isActive: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .background(isActive ? .red.opacity(0.8) : .green.opacity(0.8))
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct FinishButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .background(.blue.opacity(0.8))
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Motion Value View

struct MotionValueView: View {
    let label: String
    let value: Double
    
    var body: some View {
        VStack(spacing: 8) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            
            Text(String(format: "%.2f", value))
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
        .frame(minWidth: 80)
    }
}

#Preview {
    let container = try! ModelContainer(for: BalanceResult.self)
    let sampleBalanceResult = BalanceResult()
    sampleBalanceResult.errorsByStance = [2, 0, 1]
    
    return BalanceTestView(
        balanceResult: sampleBalanceResult,
        onComplete: { print("Balance test completed") }
    )
    .frame(width: 550, height: 600)
    .background(.black.opacity(0.3))
    .glassBackgroundEffect()
    .cornerRadius(20)
    .modelContainer(container)
}