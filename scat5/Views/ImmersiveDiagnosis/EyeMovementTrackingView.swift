import SwiftUI
import SwiftData

struct EyeMovementTrackingView: View {
    @Environment(ViewRouter.self) private var viewRouter
    @Environment(SpeechControlCoordinator.self) private var speechCoordinator
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    
    @State private var analysisProgress: Double = 0.0
    @State private var currentStage = AnalysisStage.initialization
    @State private var isAnalyzing = false
    @State private var showResults = false
    
    enum AnalysisStage: String, CaseIterable {
        case initialization = "Initializing Eye Tracker"
        case dataCollection = "Collecting Eye Data"
        case patternAnalysis = "Analyzing Movements"
        case riskAssessment = "Assessing Visual Processing"
        case reportGeneration = "Generating Report"
        
        var icon: String {
            switch self {
            case .initialization: return "eye.fill"
            case .dataCollection: return "doc.text.magnifyingglass"
            case .patternAnalysis: return "waveform.path.ecg"
            case .riskAssessment: return "exclamationmark.triangle"
            case .reportGeneration: return "doc.plaintext"
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Immersive background with eye tracking visualization
            GeometryReader { geometry in
                ZStack {
                    // Dynamic gradient background
                    LinearGradient(
                        colors: [
                            Color.black,
                            Color.cyan.opacity(0.4),
                            Color.blue.opacity(0.3),
                            Color.black
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: isAnalyzing)
                    
                    // Eye tracking particle system
                    ForEach(0..<120, id: \.self) { index in
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.cyan.opacity(0.7), Color.blue.opacity(0.5)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: Double.random(in: 3...10), height: Double.random(in: 3...10))
                            .position(
                                x: Double.random(in: 0...geometry.size.width),
                                y: Double.random(in: 0...geometry.size.height)
                            )
                            .scaleEffect(isAnalyzing ? Double.random(in: 0.3...1.8) : 0.8)
                            .opacity(isAnalyzing ? Double.random(in: 0.4...0.9) : 0.2)
                            .animation(
                                Animation.easeInOut(duration: Double.random(in: 2.0...5.0))
                                .repeatForever(autoreverses: true),
                                value: isAnalyzing
                            )
                    }
                    
                    // Connection lines between particles
                    if isAnalyzing {
                        ForEach(0..<30, id: \.self) { index in
                            Path { path in
                                let startX = Double.random(in: 0...geometry.size.width)
                                let startY = Double.random(in: 0...geometry.size.height)
                                let endX = Double.random(in: 0...geometry.size.width)
                                let endY = Double.random(in: 0...geometry.size.height)
                                
                                path.move(to: CGPoint(x: startX, y: startY))
                                path.addLine(to: CGPoint(x: endX, y: endY))
                            }
                            .stroke(
                                LinearGradient(
                                    colors: [Color.cyan.opacity(0.3), Color.blue.opacity(0.2)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 1
                            )
                            .opacity(Double.random(in: 0.1...0.4))
                            .animation(.easeInOut(duration: Double.random(in: 3...8)).repeatForever(autoreverses: true), value: isAnalyzing)
                        }
                    }
                    
                    // Main content
                    VStack(spacing: 60) {
                        headerSection
                        
                        Spacer()
                        
                        if !showResults {
                            analysisInterface
                        } else {
                            resultsSection
                        }
                        
                        Spacer()
                        
                        controlPanel
                    }
                    .padding(.vertical, 80)
                    .padding(.horizontal, 120)
                }
            }
        }
        .onAppear {
            speechCoordinator.currentViewContext = .eyeMovementTracking
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 30) {
            // Exit button
            HStack {
                Button(action: {
                    Task {
                        await dismissImmersiveSpace()
                    }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                        Text("Exit")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                    .padding(20)
                    .background(.ultraThinMaterial.opacity(0.8), in: RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .buttonStyle(.plain)
                
                Spacer()
            }
            
            // Main title with eye visualization
            VStack(spacing: 20) {
                ZStack {
                    // Pulsing eye sphere
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.cyan.opacity(0.8), Color.blue.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 200, height: 200)
                        .scaleEffect(isAnalyzing ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnalyzing)
                        .shadow(color: .cyan.opacity(0.8), radius: 30, x: 0, y: 0)
                    
                    // Eye tracking rings
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.cyan.opacity(0.6), Color.blue.opacity(0.4)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 3
                            )
                            .frame(width: 250 + Double(index) * 50, height: 250 + Double(index) * 50)
                            .scaleEffect(isAnalyzing ? 1.1 + Double(index) * 0.1 : 1.0)
                            .opacity(isAnalyzing ? 0.8 - Double(index) * 0.2 : 0.3)
                            .animation(
                                Animation.easeOut(duration: 2.5)
                                .repeatForever(autoreverses: false)
                                .delay(Double(index) * 0.4),
                                value: isAnalyzing
                            )
                    }
                    
                    // Central eye icon
                    Image(systemName: "eye.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.white)
                        .scaleEffect(isAnalyzing ? 1.05 : 1.0)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnalyzing)
                }
                
                Text("Eye Movement Tracking")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 5, x: 0, y: 2)
                
                Text("Advanced saccadic and visual processing analysis")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 60)
            }
        }
    }
    
    private var analysisInterface: some View {
        VStack(spacing: 40) {
            // Current stage display
            HStack(spacing: 30) {
                ZStack {
                    Circle()
                        .fill(Color.cyan.opacity(0.7))
                        .frame(width: 120, height: 120)
                        .scaleEffect(isAnalyzing ? 1.3 : 1.0)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnalyzing)
                        .shadow(color: .cyan.opacity(0.8), radius: 20, x: 0, y: 0)
                    
                    Image(systemName: currentStage.icon)
                        .font(.system(size: 40))
                        .foregroundStyle(.white)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(currentStage.rawValue)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                    
                    Text("Processing eye movement patterns...")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: 600, alignment: .leading)
                }
                
                Spacer()
            }
            .padding(40)
            .background(.ultraThinMaterial.opacity(0.6), in: RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.2), radius: 15, x: 0, y: 8)
            
            // Analysis progress visualization
            if isAnalyzing {
                VStack(spacing: 30) {
                    Text("Analysis Progress: \(Int(analysisProgress * 100))%")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(.white)
                    
                    // Main progress ring
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 8)
                            .frame(width: 250, height: 250)
                        
                        Circle()
                            .trim(from: 0, to: analysisProgress)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.cyan, Color.blue, Color.purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .frame(width: 250, height: 250)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeOut(duration: 0.5), value: analysisProgress)
                        
                        // Inner progress percentage
                        VStack(spacing: 8) {
                            Text("\(Int(analysisProgress * 100))")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundStyle(.white)
                            Text("PERCENT")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    
                    // Stage indicators
                    HStack(spacing: 15) {
                        ForEach(Array(AnalysisStage.allCases.enumerated()), id: \.element) { index, stage in
                            let isCompleted = analysisProgress > Double(index) / Double(AnalysisStage.allCases.count - 1) * 0.8
                            let isCurrent = currentStage == stage
                            
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            isCompleted || isCurrent ?
                                            LinearGradient(
                                                colors: [Color.green.opacity(0.8), Color.blue.opacity(0.6)],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            ) :
                                            LinearGradient(
                                                colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.2)],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .frame(width: 60, height: 60)
                                        .scaleEffect(isCurrent ? 1.2 : 1.0)
                                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isCurrent)
                                        .shadow(
                                            color: (isCompleted || isCurrent) ? Color.green.opacity(0.6) : Color.clear,
                                            radius: isCurrent ? 10 : 5,
                                            x: 0, y: 0
                                        )
                                    
                                    Image(systemName: stage.icon)
                                        .font(.title3)
                                        .foregroundStyle(.white)
                                }
                                
                                Text(stage.rawValue.components(separatedBy: " ").first ?? "")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.white.opacity(0.8))
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }
                }
                .padding(40)
                .background(.ultraThinMaterial.opacity(0.4), in: RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.2), radius: 15, x: 0, y: 8)
            }
        }
    }
    
    private var resultsSection: some View {
        VStack(spacing: 40) {
            // Success indicator
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.8))
                        .frame(width: 150, height: 150)
                        .shadow(color: Color.green.opacity(0.6), radius: 20, x: 0, y: 0)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 60, weight: .bold))
                        .foregroundStyle(.white)
                }
                
                Text("Tracking Complete")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white)
                
                Text("Eye movement analysis has been completed successfully")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            
            // Result cards
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 30), count: 2), spacing: 30) {
                resultCard(title: "Saccade Speed", value: "Normal", color: .green, icon: "speedometer")
                resultCard(title: "Pursuit Accuracy", value: "94%", color: .blue, icon: "target")
                resultCard(title: "Fixation Stability", value: "Good", color: .cyan, icon: "eye.fill")
                resultCard(title: "Overall Score", value: "89%", color: .purple, icon: "chart.bar.fill")
            }
        }
        .padding(40)
        .background(.ultraThinMaterial.opacity(0.3), in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.2), radius: 15, x: 0, y: 8)
    }
    
    private func resultCard(title: String, value: String, color: Color, icon: String) -> some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.8))
                    .frame(width: 80, height: 80)
                    .shadow(color: color.opacity(0.6), radius: 15, x: 0, y: 5)
                
                Image(systemName: icon)
                    .font(.system(size: 30))
                    .foregroundStyle(.white)
            }
            
            VStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                
                Text(title)
                    .font(.headline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(30)
        .background(.ultraThinMaterial.opacity(0.6), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    private var controlPanel: some View {
        HStack(spacing: 40) {
            if !showResults {
                Button(action: startAnalysis) {
                    HStack(spacing: 15) {
                        Image(systemName: isAnalyzing ? "stop.circle.fill" : "play.circle.fill")
                            .font(.system(size: 30))
                        Text(isAnalyzing ? "Stop Analysis" : "Start Analysis")
                            .font(.system(size: 20, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 20)
                    .background(
                        LinearGradient(
                            colors: isAnalyzing ? 
                                [Color.red.opacity(0.8), Color.red.opacity(0.6)] : 
                                [Color.cyan.opacity(0.8), Color.blue.opacity(0.6)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 16)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                    .scaleEffect(isAnalyzing ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: isAnalyzing)
                }
                .buttonStyle(.plain)
            } else {
                Button(action: resetAnalysis) {
                    HStack(spacing: 15) {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .font(.system(size: 30))
                        Text("New Analysis")
                            .font(.system(size: 20, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 20)
                    .background(
                        LinearGradient(
                            colors: [Color.green.opacity(0.8), Color.blue.opacity(0.6)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 16)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .buttonStyle(.plain)
                
                Button(action: exportResults) {
                    HStack(spacing: 15) {
                        Image(systemName: "square.and.arrow.up.circle.fill")
                            .font(.system(size: 30))
                        Text("Export Report")
                            .font(.system(size: 20, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 20)
                    .background(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.8), Color.pink.opacity(0.6)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 16)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func startAnalysis() {
        guard !isAnalyzing else {
            isAnalyzing = false
            return
        }
        
        isAnalyzing = true
        analysisProgress = 0.0
        currentStage = .initialization
        
        // Simulate analysis progression
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if !isAnalyzing {
                timer.invalidate()
                return
            }
            
            analysisProgress += 0.008
            
            // Update current stage based on progress
            let stageIndex = min(Int(analysisProgress * Double(AnalysisStage.allCases.count)), AnalysisStage.allCases.count - 1)
            currentStage = AnalysisStage.allCases[stageIndex]
            
            if analysisProgress >= 1.0 {
                timer.invalidate()
                isAnalyzing = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                        showResults = true
                    }
                }
            }
        }
    }
    
    private func resetAnalysis() {
        showResults = false
        analysisProgress = 0.0
        currentStage = .initialization
        isAnalyzing = false
    }
    
    private func exportResults() {
        print("Exporting eye movement tracking results...")
    }
}

#Preview("Eye Movement Tracking Immersive") {
    EyeMovementTrackingView()
        .environment(ViewRouter())
        .environment(SpeechControlCoordinator())
}