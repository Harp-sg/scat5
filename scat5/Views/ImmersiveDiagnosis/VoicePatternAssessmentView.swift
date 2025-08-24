import SwiftUI
import RealityKit
import RealityKitContent
import ARKit
import Combine
import Charts

struct VoicePatternAssessmentView: View {
    // Test configuration
    @State private var currentCondition: TestCondition = .feetTogetherOpen
    @State private var isTestActive = false
    @State private var isCalibrating = false
    @State private var testStartTime: TimeInterval = 0
    @State private var conditionStartTime: TimeInterval = 0
    @State private var elapsedTime: TimeInterval = 0
    
    // Head tracking
    @State private var arkitSession = ARKitSession()
    @State private var worldTracking = WorldTrackingProvider()
    @State private var headTrackingTask: Task<Void, Never>?
    @State private var currentHeadPosition: SIMD3<Float> = .zero
    @State private var calibrationOrigin: SIMD3<Float>?
    @State private var timer: Timer?
    
    // Data collection
    @State private var swayBuffer: [SwayPoint] = []
    @State private var calibrationNoise: NoiseProfile = NoiseProfile()
    @State private var currentMetrics: ConditionMetrics = ConditionMetrics()
    @State private var allResults: [TestCondition: ConditionMetrics] = [:]
    @State private var sparklineData: [SparklinePoint] = []
    
    // UI State
    @State private var showResults = false
    @State private var showInstructions = true
    @State private var feedbackMessage = ""
    @State private var stabilityIndicator: StabilityLevel = .stable
    
    enum TestCondition: String, CaseIterable {
        case feetTogetherOpen = "Feet Together - Eyes Open"
        case feetTogetherClosed = "Feet Together - Eyes Closed"
        case tandemOpen = "Tandem Stance - Eyes Open"
        case singleLeg = "Single Leg - Eyes Open"
        
        var duration: TimeInterval { 20.0 }
        var instruction: String {
            switch self {
            case .feetTogetherOpen:
                return "Stand with feet together, arms at sides, eyes open. Look straight ahead."
            case .feetTogetherClosed:
                return "Stand with feet together, arms at sides. Close your eyes when ready."
            case .tandemOpen:
                return "Place dominant foot directly behind other foot (heel-to-toe). Arms at sides, eyes open."
            case .singleLeg:
                return "Stand on dominant leg, other leg raised. Arms at sides, eyes open."
            }
        }
        
        var isEyesClosed: Bool {
            self == .feetTogetherClosed
        }
    }
    
    enum StabilityLevel {
        case stable, mild, moderate, unstable
        
        var color: Color {
            switch self {
            case .stable: return .green
            case .mild: return .yellow
            case .moderate: return .orange
            case .unstable: return .red
            }
        }
        
        var description: String {
            switch self {
            case .stable: return "Stable"
            case .mild: return "Mild Sway"
            case .moderate: return "Moderate Sway"
            case .unstable: return "Unstable"
            }
        }
    }
    
    struct SwayPoint {
        let timestamp: TimeInterval
        let position: SIMD2<Float>  // x (ML), z (AP) relative to calibration
        let velocity: SIMD2<Float>
        let jerk: Float
    }
    
    struct SparklinePoint: Identifiable {
        let id = UUID()
        let time: Double
        let apSway: Double
        let mlSway: Double
    }
    
    struct NoiseProfile {
        var baselineRMS: Float = 0.001
        var baselineMax: Float = 0.002
    }
    
    struct ConditionMetrics {
        var apRMS: Float = 0
        var mlRMS: Float = 0
        var pathLength: Float = 0
        var ellipseArea: Float = 0
        var instabilityEvents: Int = 0
        var maxDisplacement: Float = 0
        var meanVelocity: Float = 0
        var jerkScore: Float = 0
        var completionTime: TimeInterval = 0
        
        var compositeScore: Float {
            // Weighted composite score (lower is better)
            let rmsScore = (apRMS + mlRMS) / 2
            let pathScore = pathLength / 100  // Normalize to meters
            let instabilityScore = Float(instabilityEvents) * 0.1
            return rmsScore + pathScore * 0.5 + instabilityScore
        }
        
        func zScore(against baseline: ConditionMetrics) -> Float {
            guard baseline.compositeScore > 0 else { return 0 }
            return (compositeScore - baseline.compositeScore) / baseline.compositeScore
        }
    }
    
    var body: some View {
        RealityView { content, attachments in
            // Add minimal reference markers for mixed reality
            let origin = createOriginMarker()
            content.add(origin)
            
            // Add control panel
            if let controlPanel = attachments.entity(for: "controlPanel") {
                let anchor = AnchorEntity(.head)
                controlPanel.position = [0, 0, -1.2]
                controlPanel.components.set(BillboardComponent())
                anchor.addChild(controlPanel)
                content.add(anchor)
            }
            
            // Add metrics display
            if let metricsPanel = attachments.entity(for: "metricsPanel") {
                let anchor = AnchorEntity(.head)
                metricsPanel.position = [0.6, 0, -1.2]
                metricsPanel.components.set(BillboardComponent())
                anchor.addChild(metricsPanel)
                content.add(anchor)
            }
            
            // Add results panel
            if let resultsPanel = attachments.entity(for: "resultsPanel") {
                let anchor = AnchorEntity(.head)
                resultsPanel.position = [0, 0, -1.5]
                resultsPanel.components.set(BillboardComponent())
                anchor.addChild(resultsPanel)
                content.add(anchor)
            }
            
        } attachments: {
            // Control Panel
            Attachment(id: "controlPanel") {
                VStack(spacing: 15) {
                    Text("Balance Assessment")
                        .font(.title2)
                        .bold()
                    
                    if !isTestActive {
                        // Test selection
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Select Conditions:")
                                .font(.headline)
                            
                            ForEach(TestCondition.allCases, id: \.self) { condition in
                                HStack {
                                    Image(systemName: allResults[condition] != nil ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(allResults[condition] != nil ? .green : .gray)
                                    Text(condition.rawValue)
                                        .font(.caption)
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    currentCondition = condition
                                }
                                .background(currentCondition == condition ? Color.blue.opacity(0.2) : Color.clear)
                                .cornerRadius(5)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                        
                        Button(action: startTest) {
                            Label("Start Test", systemImage: "play.fill")
                                .font(.title3)
                                .frame(width: 200)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        
                    } else {
                        // During test
                        VStack(spacing: 10) {
                            Text(currentCondition.rawValue)
                                .font(.headline)
                            
                            if isCalibrating {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Calibrating...")
                                }
                                .foregroundColor(.orange)
                            } else {
                                // Timer
                                ZStack {
                                    Circle()
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                                        .frame(width: 80, height: 80)
                                    
                                    Circle()
                                        .trim(from: 0, to: CGFloat(elapsedTime / currentCondition.duration))
                                        .stroke(Color.blue, lineWidth: 8)
                                        .frame(width: 80, height: 80)
                                        .rotationEffect(.degrees(-90))
                                    
                                    Text(String(format: "%.1f", currentCondition.duration - elapsedTime))
                                        .font(.title2)
                                        .monospacedDigit()
                                }
                                
                                // Stability indicator
                                HStack {
                                    Circle()
                                        .fill(stabilityIndicator.color)
                                        .frame(width: 12, height: 12)
                                    Text(stabilityIndicator.description)
                                        .font(.caption)
                                }
                            }
                            
                            Button(action: skipCondition) {
                                Text("Skip Condition")
                                    .font(.caption)
                                    .padding(8)
                                    .background(Color.orange)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                            
                            Button(action: stopTest) {
                                Label("Stop Test", systemImage: "stop.fill")
                                    .padding(8)
                                    .background(Color.red)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    
                    if showInstructions && !isTestActive {
                        Text(currentCondition.instruction)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .padding()
                .frame(width: 320)
                .background(.regularMaterial)
                .cornerRadius(15)
            }
            
            // Real-time Metrics Panel
            Attachment(id: "metricsPanel") {
                if isTestActive && !isCalibrating {
                    VStack(spacing: 12) {
                        Text("Live Metrics")
                            .font(.headline)
                        
                        // Sway visualization
                        ZStack {
                            // Target circles
                            ForEach([30, 20, 10], id: \.self) { radius in
                                Circle()
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                    .frame(width: CGFloat(radius * 2), height: CGFloat(radius * 2))
                            }
                            
                            // Current position
                            Circle()
                                .fill(stabilityIndicator.color)
                                .frame(width: 8, height: 8)
                                .offset(
                                    x: CGFloat(currentHeadPosition.x * 1000),
                                    y: CGFloat(-currentHeadPosition.z * 1000)
                                )
                        }
                        .frame(width: 100, height: 100)
                        .background(Color.black.opacity(0.05))
                        .cornerRadius(10)
                        
                        // Numeric metrics
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text("AP Sway:")
                                Text(String(format: "%.1f cm", currentMetrics.apRMS * 100))
                                    .bold()
                            }
                            HStack {
                                Text("ML Sway:")
                                Text(String(format: "%.1f cm", currentMetrics.mlRMS * 100))
                                    .bold()
                            }
                            HStack {
                                Text("Path:")
                                Text(String(format: "%.0f cm", currentMetrics.pathLength))
                                    .bold()
                            }
                            HStack {
                                Text("Events:")
                                Text("\(currentMetrics.instabilityEvents)")
                                    .bold()
                                    .foregroundColor(currentMetrics.instabilityEvents > 2 ? .orange : .green)
                            }
                        }
                        .font(.caption)
                        
                        // Sparkline chart
                        if !sparklineData.isEmpty {
                            Chart(sparklineData.suffix(60)) { point in
                                LineMark(
                                    x: .value("Time", point.time),
                                    y: .value("AP", point.apSway)
                                )
                                .foregroundStyle(.blue)
                                
                                LineMark(
                                    x: .value("Time", point.time),
                                    y: .value("ML", point.mlSway)
                                )
                                .foregroundStyle(.green)
                            }
                            .frame(width: 200, height: 60)
                            .chartXAxis(.hidden)
                            .chartYScale(domain: -5...5)
                        }
                    }
                    .padding()
                    .frame(width: 250)
                    .background(.regularMaterial)
                    .cornerRadius(15)
                } else {
                    EmptyView()
                }
            }
            
            // Results Panel
            Attachment(id: "resultsPanel") {
                if showResults && !allResults.isEmpty {
                    VStack(spacing: 15) {
                        Text("Assessment Results")
                            .font(.title2)
                            .bold()
                        
                        // Condition comparison
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(allResults.keys.sorted(by: { $0.rawValue < $1.rawValue })), id: \.self) { condition in
                                if let metrics = allResults[condition] {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(condition.rawValue)
                                            .font(.headline)
                                        
                                        HStack(spacing: 20) {
                                            VStack(alignment: .leading) {
                                                Text("RMS (AP/ML)")
                                                Text(String(format: "%.1f/%.1f cm",
                                                          metrics.apRMS * 100,
                                                          metrics.mlRMS * 100))
                                                    .bold()
                                            }
                                            
                                            VStack(alignment: .leading) {
                                                Text("Path Length")
                                                Text(String(format: "%.0f cm", metrics.pathLength))
                                                    .bold()
                                            }
                                            
                                            VStack(alignment: .leading) {
                                                Text("95% Ellipse")
                                                Text(String(format: "%.0f cm²", metrics.ellipseArea))
                                                    .bold()
                                            }
                                            
                                            VStack(alignment: .leading) {
                                                Text("Score")
                                                Text(String(format: "%.2f", metrics.compositeScore))
                                                    .bold()
                                                    .foregroundColor(scoreColor(metrics.compositeScore))
                                            }
                                        }
                                        .font(.caption)
                                    }
                                    .padding()
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                                }
                            }
                        }
                        
                        // Overall assessment
                        VStack(spacing: 5) {
                            Text("Clinical Assessment")
                                .font(.headline)
                            Text(getOverallAssessment())
                                .font(.caption)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                        
                        HStack(spacing: 20) {
                            Button("Export Data") {
                                exportResults()
                            }
                            .padding(8)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            
                            Button("Close") {
                                showResults = false
                                resetTest()
                            }
                            .padding(8)
                            .background(Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                    .frame(width: 500)
                    .background(.regularMaterial)
                    .cornerRadius(15)
                } else {
                    EmptyView()
                }
            }
        }
        .onAppear {
            startHeadTracking()
        }
        .onDisappear {
            stopHeadTracking()
            stopTest()
        }
    }
    
    // MARK: - Test Control
    
    private func startTest() {
        isTestActive = true
        isCalibrating = true
        testStartTime = CACurrentMediaTime()
        swayBuffer.removeAll()
        sparklineData.removeAll()
        currentMetrics = ConditionMetrics()
        feedbackMessage = "Stand still for calibration..."
        
        // 1 second calibration
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            finishCalibration()
            startCondition()
        }
    }
    
    private func finishCalibration() {
        guard !swayBuffer.isEmpty else { return }
        
        // Calculate baseline noise
        let positions = swayBuffer.map { $0.position }
        let meanX = positions.map { $0.x }.reduce(0, +) / Float(positions.count)
        let meanZ = positions.map { $0.y }.reduce(0, +) / Float(positions.count)
        
        calibrationOrigin = SIMD3<Float>(meanX, currentHeadPosition.y, meanZ)
        
        // Calculate noise profile
        let deviations = positions.map { point in
            sqrt(pow(point.x - meanX, 2) + pow(point.y - meanZ, 2))
        }
        calibrationNoise.baselineRMS = deviations.reduce(0, +) / Float(deviations.count)
        calibrationNoise.baselineMax = deviations.max() ?? 0.002
        
        isCalibrating = false
        print("Calibration complete. Baseline RMS: \(calibrationNoise.baselineRMS * 100) cm")
    }
    
    private func startCondition() {
        conditionStartTime = CACurrentMediaTime()
        swayBuffer.removeAll()
        currentMetrics = ConditionMetrics()
        elapsedTime = 0
        
        // Start update timer
        timer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { _ in
            updateMetrics()
        }
    }
    
    private func updateMetrics() {
        guard isTestActive && !isCalibrating else { return }
        
        let currentTime = CACurrentMediaTime()
        elapsedTime = currentTime - conditionStartTime
        
        // Record sway point
        if let origin = calibrationOrigin {
            let relativePos = SIMD2<Float>(
                currentHeadPosition.x - origin.x,
                currentHeadPosition.z - origin.z
            )
            
            // Calculate velocity and jerk
            var velocity = SIMD2<Float>.zero
            var jerk: Float = 0
            
            if let lastPoint = swayBuffer.last {
                let dt = Float(currentTime - testStartTime) - Float(lastPoint.timestamp)
                if dt > 0 {
                    velocity = (relativePos - lastPoint.position) / dt
                    
                    if swayBuffer.count > 1 {
                        let lastVelocity = lastPoint.velocity
                        let acceleration = (velocity - lastVelocity) / dt
                        jerk = simd_length(acceleration)
                    }
                }
            }
            
            let swayPoint = SwayPoint(
                timestamp: currentTime - testStartTime,
                position: relativePos,
                velocity: velocity,
                jerk: jerk
            )
            swayBuffer.append(swayPoint)
            
            // Update sparkline data
            sparklineData.append(SparklinePoint(
                time: elapsedTime,
                apSway: Double(relativePos.y * 100),  // Convert to cm
                mlSway: Double(relativePos.x * 100)
            ))
            
            // Keep only recent sparkline data
            if sparklineData.count > 180 {  // 3 seconds at 60Hz
                sparklineData.removeFirst()
            }
            
            // Calculate real-time metrics
            updateRealtimeMetrics()
            
            // Check for instability events
            checkInstabilityEvents(swayPoint)
            
            // Update stability indicator
            updateStabilityIndicator(relativePos)
        }
        
        // Check if condition complete
        if elapsedTime >= currentCondition.duration {
            completeCondition()
        }
    }
    
    private func updateRealtimeMetrics() {
        guard swayBuffer.count > 2 else { return }
        
        let positions = swayBuffer.map { $0.position }
        
        // RMS sway
        let apSquared = positions.map { $0.y * $0.y }.reduce(0, +)
        let mlSquared = positions.map { $0.x * $0.x }.reduce(0, +)
        currentMetrics.apRMS = sqrt(apSquared / Float(positions.count))
        currentMetrics.mlRMS = sqrt(mlSquared / Float(positions.count))
        
        // Path length
        var pathLength: Float = 0
        for i in 1..<positions.count {
            pathLength += simd_distance(positions[i], positions[i-1])
        }
        currentMetrics.pathLength = pathLength * 100  // Convert to cm
        
        // Max displacement
        let displacements = positions.map { simd_length($0) }
        currentMetrics.maxDisplacement = displacements.max() ?? 0
        
        // 95% confidence ellipse area
        currentMetrics.ellipseArea = calculate95EllipseArea(positions)
    }
    
    private func calculate95EllipseArea(_ positions: [SIMD2<Float>]) -> Float {
        guard positions.count > 2 else { return 0 }
        
        // Calculate covariance matrix
        let meanX = positions.map { $0.x }.reduce(0, +) / Float(positions.count)
        let meanY = positions.map { $0.y }.reduce(0, +) / Float(positions.count)
        
        var covXX: Float = 0
        var covYY: Float = 0
        var covXY: Float = 0
        
        for pos in positions {
            let dx = pos.x - meanX
            let dy = pos.y - meanY
            covXX += dx * dx
            covYY += dy * dy
            covXY += dx * dy
        }
        
        let n = Float(positions.count - 1)
        covXX /= n
        covYY /= n
        covXY /= n
        
        // Calculate eigenvalues
        let trace = covXX + covYY
        let det = covXX * covYY - covXY * covXY
        let lambda1 = trace/2 + sqrt(max(0, trace*trace/4 - det))
        let lambda2 = trace/2 - sqrt(max(0, trace*trace/4 - det))
        
        // 95% confidence ellipse area (chi-square value for 2 DOF at 95% = 5.991)
        let area = Float.pi * sqrt(lambda1) * sqrt(lambda2) * 5.991 * 10000  // Convert to cm²
        return area
    }
    
    private func checkInstabilityEvents(_ point: SwayPoint) {
        // Check for sudden displacement
        let displacement = simd_length(point.position)
        if displacement > calibrationNoise.baselineMax * 10 {  // 10x baseline noise
            currentMetrics.instabilityEvents += 1
        }
        
        // Check for high jerk (sudden acceleration change)
        if point.jerk > 0.5 {  // Threshold in m/s³
            currentMetrics.instabilityEvents += 1
        }
    }
    
    private func updateStabilityIndicator(_ position: SIMD2<Float>) {
        let displacement = simd_length(position) * 100  // Convert to cm
        
        if displacement < 2 {
            stabilityIndicator = .stable
        } else if displacement < 5 {
            stabilityIndicator = .mild
        } else if displacement < 10 {
            stabilityIndicator = .moderate
        } else {
            stabilityIndicator = .unstable
        }
    }
    
    private func completeCondition() {
        timer?.invalidate()
        
        // Store final metrics
        currentMetrics.completionTime = elapsedTime
        allResults[currentCondition] = currentMetrics
        
        // Move to next condition or finish
        if let nextCondition = getNextCondition() {
            currentCondition = nextCondition
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                startCondition()
            }
            feedbackMessage = "Prepare for next condition..."
        } else {
            stopTest()
            showResults = true
        }
    }
    
    private func skipCondition() {
        completeCondition()
    }
    
    private func stopTest() {
        isTestActive = false
        timer?.invalidate()
        timer = nil
        
        if !allResults.isEmpty {
            showResults = true
        }
    }
    
    private func resetTest() {
        allResults.removeAll()
        sparklineData.removeAll()
        swayBuffer.removeAll()
        currentMetrics = ConditionMetrics()
    }
    
    private func getNextCondition() -> TestCondition? {
        let allConditions = TestCondition.allCases
        guard let currentIndex = allConditions.firstIndex(of: currentCondition) else { return nil }
        
        for i in (currentIndex + 1)..<allConditions.count {
            if allResults[allConditions[i]] == nil {
                return allConditions[i]
            }
        }
        return nil
    }
    
    // MARK: - Head Tracking
    
    private func startHeadTracking() {
        headTrackingTask = Task {
            do {
                try await arkitSession.run([worldTracking])
                
                for await update in worldTracking.anchorUpdates {
                    guard let deviceAnchor = update.anchor as? DeviceAnchor else { continue }
                    
                    let transform = deviceAnchor.originFromAnchorTransform
                    let position = SIMD3<Float>(
                        transform.columns.3.x,
                        transform.columns.3.y,
                        transform.columns.3.z
                    )
                    
                    await MainActor.run {
                        currentHeadPosition = position
                    }
                }
            } catch {
                print("ARKit error: \(error)")
            }
        }
    }
    
    private func stopHeadTracking() {
        headTrackingTask?.cancel()
        headTrackingTask = nil
    }
    
    // MARK: - Helpers
    
    private func createOriginMarker() -> Entity {
        // Simple floor marker for reference
        let marker = ModelEntity(
            mesh: .generateCylinder(height: 0.001, radius: 0.5),
            materials: [SimpleMaterial(color: UIColor.blue.withAlphaComponent(0.2), isMetallic: false)]
        )
        marker.position.y = 0
        return marker
    }
    
    private func scoreColor(_ score: Float) -> Color {
        if score < 0.5 { return .green }
        if score < 1.0 { return .yellow }
        if score < 2.0 { return .orange }
        return .red
    }
    
    private func getOverallAssessment() -> String {
        guard !allResults.isEmpty else { return "No data available" }
        
        var assessment = ""
        
        // Compare eyes open vs closed
        if let openMetrics = allResults[.feetTogetherOpen],
           let closedMetrics = allResults[.feetTogetherClosed] {
            let rombergRatio = closedMetrics.compositeScore / max(0.01, openMetrics.compositeScore)
            
            if rombergRatio > 3.0 {
                assessment += "Significant visual dependency detected (Romberg ratio: \(String(format: "%.1f", rombergRatio))). "
            } else if rombergRatio > 2.0 {
                assessment += "Moderate visual dependency (Romberg ratio: \(String(format: "%.1f", rombergRatio))). "
            } else {
                assessment += "Good proprioceptive/vestibular function. "
            }
        }
        
        // Check tandem stance
        if let tandemMetrics = allResults[.tandemOpen] {
            if tandemMetrics.instabilityEvents > 5 {
                assessment += "Balance challenges in tandem stance suggest vestibular or cerebellar involvement. "
            }
        }
        
        // Overall stability
        let avgScore = allResults.values.map { $0.compositeScore }.reduce(0, +) / Float(allResults.count)
        if avgScore < 0.5 {
            assessment += "Overall excellent balance control."
        } else if avgScore < 1.0 {
            assessment += "Overall good balance with mild impairments."
        } else {
            assessment += "Significant balance impairments detected. Consider comprehensive evaluation."
        }
        
        return assessment
    }
    
    private func exportResults() {
        // In production, implement CSV/JSON export
        print("Exporting results...")
        for (condition, metrics) in allResults {
            print("\(condition.rawValue):")
            print("  AP RMS: \(metrics.apRMS * 100) cm")
            print("  ML RMS: \(metrics.mlRMS * 100) cm")
            print("  Path Length: \(metrics.pathLength) cm")
            print("  Ellipse Area: \(metrics.ellipseArea) cm²")
            print("  Instability Events: \(metrics.instabilityEvents)")
        }
    }
}