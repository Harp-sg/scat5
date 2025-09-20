import SwiftUI
import SwiftData

struct BalanceTestView: View, TestController {
    @Bindable var balanceResult: BalanceResult
    let onComplete: () -> Void
    let onSkip: (() -> Void)?

    @State private var motionManager = MotionManager()
    @State private var currentStanceIndex = 0
    @State private var timerValue = 20
    @State private var isTimerRunning = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @Environment(SpeechControlCoordinator.self) private var speechCoordinator
    
    private var currentStance: BalanceStance {
        BalanceStance.allCases[currentStanceIndex]
    }

    var body: some View {
        VStack(spacing: 20) {
            // Header with progress indicator and skip button
            VStack(spacing: 8) {
                HStack {
                    Text("Balance Assessment")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.primary, .primary.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
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
                
                Text(currentStance.rawValue)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                
                // Progress indicator
                HStack(spacing: 4) {
                    ForEach(0..<BalanceStance.allCases.count, id: \.self) { index in
                        Circle()
                            .fill(index <= currentStanceIndex ? Color.blue : Color.gray.opacity(0.3))
                            .frame(width: 6, height: 6)
                    }
                }
                .padding(.top, 4)
            }
            .padding(.top, 16)
            
            // Main content in a more balanced grid
            VStack(spacing: 16) {
                // Timer and Errors - more proportional
                HStack(spacing: 16) {
                    // Timer Card
                    VStack(spacing: 8) {
                        Text("Time Remaining")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Text("\(timerValue)s")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.primary, .blue.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .blue.opacity(0.3), radius: 6, x: 0, y: 3)
                            .contentTransition(.numericText())
                        
                        // Timer progress bar
                        ProgressView(value: Double(20 - timerValue), total: 20.0)
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                            .scaleEffect(x: 1, y: 1.5)
                            .frame(height: 3)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(volumetricGlassBackground)
                    .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
                    
                    // Error Card with visual error indicators
                    VStack(spacing: 8) {
                        Text("Balance Errors")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Text("\(balanceResult.errorsByStance[currentStanceIndex])")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.primary, .red.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .red.opacity(0.3), radius: 6, x: 0, y: 3)
                            .contentTransition(.numericText())
                        
                        // Error dots visualization
                        HStack(spacing: 2) {
                            ForEach(0..<10, id: \.self) { index in
                                Circle()
                                    .fill(index < balanceResult.errorsByStance[currentStanceIndex] ? 
                                          Color.red.opacity(0.8) : Color.gray.opacity(0.2))
                                    .frame(width: 4, height: 4)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(volumetricGlassBackground)
                    .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
                }
                
                // Add Error Button
                Button("Add Error (+1)") {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        if balanceResult.errorsByStance[currentStanceIndex] < 10 {
                            balanceResult.errorsByStance[currentStanceIndex] += 1
                        }
                    }
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .frame(height: 44)
                .frame(maxWidth: 200)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.red, .red.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(0.3), .clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.6), .white.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                )
                .shadow(color: .red.opacity(0.4), radius: 10, x: 0, y: 5)
                .disabled(balanceResult.errorsByStance[currentStanceIndex] >= 10)
                .buttonStyle(LiquidButtonStyle())
                
                // Motion Data - polished edges
                VStack(spacing: 12) {
                    Text("Live Motion Data")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                        .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 0.5)
                    
                    HStack(spacing: 12) {
                        motionValueView("Pitch", motionManager.pitch)
                        motionValueView("Roll", motionManager.roll)
                        motionValueView("Yaw", motionManager.yaw)
                    }
                }
                .padding(.vertical, 16)
                .background(volumetricGlassBackground)
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
                
                // Control Buttons - fixed spacing
                VStack(spacing: 12) {
                    if currentStanceIndex < BalanceStance.allCases.count - 1 && (timerValue < 20 || !isTimerRunning) {
                        liquidButton(
                            "Finish Balance Test",
                            color: .blue,
                            action: { onComplete() }
                        )
                    }
                    
                    liquidButton(
                        timerValue == 20 ? "Start 20s Trial" : (isTimerRunning ? "Pause Trial" : "Resume Trial"),
                        color: isTimerRunning ? .red : .green,
                        action: { isTimerRunning.toggle() }
                    )
                    .disabled(timerValue == 0)
                    .opacity(timerValue == 0 ? 0.6 : 1.0)
                }
                .padding(.bottom, 20)
            }
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: 500)
        .onAppear {
            motionManager.startUpdates()
            speechCoordinator.testController = self
        }
        .onDisappear {
            motionManager.stopUpdates()
            speechCoordinator.testController = nil
        }
        .onReceive(timer) { _ in
            guard isTimerRunning else { return }
            if timerValue > 0 {
                timerValue -= 1
            } else {
                isTimerRunning = false
                if currentStanceIndex < BalanceStance.allCases.count - 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentStanceIndex += 1
                            timerValue = 20
                        }
                    }
                }
            }
        }
    }
    
    // Voice control - ENHANCED WITH ALL THE SEXY COMMANDS
    func executeCommand(_ command: VoiceCommand) {
        print("🎤 BalanceTestView executing command: \(command)")
        
        switch command {
        case .startTest, .startRecording, .startTimer:
            print("🎤 Starting timer/test")
            if !isTimerRunning && timerValue > 0 { 
                withAnimation(.easeInOut) {
                    isTimerRunning = true 
                }
            }
        case .stopRecording, .stopTimer, .pauseTest:
            print("🎤 Stopping/pausing timer")
            if isTimerRunning { 
                withAnimation(.easeInOut) {
                    isTimerRunning = false 
                }
            }
        case .resumeTest:
            print("🎤 Resuming timer")
            if !isTimerRunning && timerValue > 0 {
                withAnimation(.easeInOut) {
                    isTimerRunning = true
                }
            }
        case .nextTrial, .nextStance:
            print("🎤 Moving to next stance")
            advanceStance()
        case .previousStance:
            print("🎤 Moving to previous stance")
            if currentStanceIndex > 0 {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentStanceIndex -= 1
                    timerValue = 20
                    isTimerRunning = false
                }
            }
        case .addError:
            print("🎤 Adding balance error")
            if balanceResult.errorsByStance[currentStanceIndex] < 10 {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    balanceResult.errorsByStance[currentStanceIndex] += 1
                }
            }
        case .completeTest:
            print("🎤 Completing balance test")
            onComplete()
        case .skipModule:
            print("🎤 Skipping balance test")
            onSkip?()
        case .resetTest:
            print("🎤 Resetting current stance")
            withAnimation(.easeInOut) {
                timerValue = 20
                isTimerRunning = false
                balanceResult.errorsByStance[currentStanceIndex] = 0
            }
        case .exitTest, .closeTest:
            print("🎤 Exiting balance test")
            // This will be handled by SpeechControlCoordinator
            break
        default:
            print("🎤 Unhandled command in BalanceTestView: \(command)")
            break
        }
    }
    
    private func advanceStance() {
        if currentStanceIndex < BalanceStance.allCases.count - 1 {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStanceIndex += 1
                timerValue = 20
                isTimerRunning = false
            }
        }
    }
    
    // MARK: - Polished Glass Background
    
    private var volumetricGlassBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
            
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.15), .clear],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 120
                    )
                )
            
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.5), .white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        }
    }
    
    // MARK: - Polished Motion Value View
    
    private func motionValueView(_ label: String, _ value: Double) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
                .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 0.5)
            
            Text(String(format: "%.2f", value))
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.primary, .blue.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .blue.opacity(0.3), radius: 4, x: 0, y: 2)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.thinMaterial)
                
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [.white.opacity(0.2), .clear],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: 80
                        )
                    )
                
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.15), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.4), .white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            }
        )
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        .shadow(color: .white.opacity(0.05), radius: 4, x: 0, y: -2)
    }
    
    // MARK: - Enhanced Liquid Glass Button
    
    private func liquidButton(_ title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .frame(height: 48)
                .frame(maxWidth: .infinity)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [color, color.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(0.35), .clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.7), .white.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    }
                )
                .shadow(color: color.opacity(0.4), radius: 12, x: 0, y: 6)
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                .shadow(color: .white.opacity(0.1), radius: 4, x: 0, y: -2)
        }
        .buttonStyle(LiquidButtonStyle())
    }
}

// MARK: - Liquid Button Style

struct LiquidButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .brightness(configuration.isPressed ? -0.1 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

#Preview {
    let container = try! ModelContainer(for: BalanceResult.self)
    let sampleBalanceResult = BalanceResult()
    sampleBalanceResult.errorsByStance = [2, 0, 1]
    
    return BalanceTestView(
        balanceResult: sampleBalanceResult,
        onComplete: { print("Balance test completed") },
        onSkip: { print("Balance test skipped") }
    )
    .glassBackgroundEffect()
    .modelContainer(container)
}