import SwiftUI
import RealityKit
import ARKit

struct BalanceRoomScaleView: View {
    @Environment(ViewRouter.self) private var viewRouter
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openWindow) private var openWindow
    
    // MARK: Entities
    @State private var plankEntity: Entity?
    @State private var environmentRoot: Entity?
    @State private var plankAnchor: AnchorEntity?

    // MARK: Test state
    @State private var isTestActive = false
    @State private var testStartTime: TimeInterval = 0
    @State private var testDuration: TimeInterval = 0

    // MARK: Plank config
    @State private var plankLength: Float = 6.0  // Longer for room-scale
    @State private var plankWidth:  Float = 0.30
    @State private var plankHeight: Float = 8.0
    @State private var difficultyLevel: DifficultyLevel = .medium

    enum DifficultyLevel: String, CaseIterable {
        case easy = "Easy", medium = "Medium", hard = "Hard", extreme = "Extreme"
        var plankWidth: Float  { switch self { case .easy: 0.60; case .medium: 0.40; case .hard: 0.25; case .extreme: 0.18 } }
        var plankHeight: Float { switch self { case .easy: 5;    case .medium: 8;    case .hard: 12;   case .extreme: 18   } }
        var swayEnabled: Bool { self == .extreme }
        var windEnabled: Bool { self == .hard || self == .extreme }
    }

    // MARK: ARKit tracking
    @State private var arkitSession = ARKitSession()
    @State private var worldTracking = WorldTrackingProvider()
    @State private var headTask: Task<Void, Never>?
    @State private var headPosW: SIMD3<Float> = .zero
    @State private var startPosition: SIMD3<Float>?
    @State private var lastPosition: SIMD3<Float>?

    // MARK: Movement tracking
    @State private var totalDistance: Float = 0
    @State private var forwardProgress: Float = 0
    @State private var pathPositions: [SIMD3<Float>] = []

    // MARK: Metrics
    struct PathPoint { 
        let t: TimeInterval
        let position: SIMD3<Float> 
        let devX: Float  // Lateral deviation from plank center
        let speed: Float // Movement speed
    }
    @State private var path: [PathPoint] = []
    @State private var totalDeviation: Float = 0
    @State private var maxDeviation: Float = 0
    @State private var nearMisses: Int = 0
    @State private var isNearEdge = false
    @State private var averageSpeed: Float = 0
    @State private var lookDownTime: TimeInterval = 0

    struct TestResults {
        let duration: TimeInterval
        let completed: Bool
        let distanceWalked: Float
        let averageDeviation: Float
        let maxDeviation: Float
        let nearMisses: Int
        let averageSpeed: Float
        let lookDownPct: Float
        let difficulty: String
        let balanceScore: Int
        let walkingConsistency: Float // How consistent was the walking speed
    }
    @State private var results: TestResults?
    @State private var showResults = false

    // Add motion manager for balance sensor data
    @State private var motionManager = MotionManager()

    var body: some View {
        RealityView { content, attachments in
            // Create room-scale plank environment
            let root = createRoomScaleEnvironment()
            environmentRoot = root
            content.add(root)

            // Control panel
            if let panel = attachments.entity(for: "panel") {
                let anchor = AnchorEntity(.head)
                panel.position = [0, -0.4, -1.8]
                panel.components.set(BillboardComponent())
                anchor.addChild(panel)
                content.add(anchor)
            }
            
            // Results panel
            if let card = attachments.entity(for: "card") {
                let anchor = AnchorEntity(.head)
                card.position = [0, 0, -1.5]
                card.components.set(BillboardComponent())
                anchor.addChild(card)
                content.add(anchor)
            }
            
            // Exit button - repositioned closer
            if let exit = attachments.entity(for: "exit") {
                let anchor = AnchorEntity(.head)
                exit.position = [0.4, 0.4, -1.2]  // Moved closer from 0.8 to 0.4
                exit.components.set(BillboardComponent())
                anchor.addChild(exit)
                content.add(anchor)
            }
            
        } update: { content, _ in
            // Update plank position to follow user's forward movement
            if isTestActive, let plank = plankEntity, let start = startPosition {
                let forwardMovement = headPosW.z - start.z
                
                // Keep plank aligned with user's walking path
                plank.position.z = start.z + forwardMovement
                plank.position.x = start.x // Keep X aligned to start position
                
                // Optional environmental effects
                if difficultyLevel.swayEnabled {
                    let t = Float(CACurrentMediaTime() - testStartTime)
                    plank.orientation = simd_quatf(angle: sin(t * 0.6) * 0.05, axis: [0, 0, 1]) // Roll sway
                }
                
                if difficultyLevel.windEnabled {
                    // Simulate wind with subtle lateral movement
                    let windT = Float(CACurrentMediaTime() - testStartTime)
                    plank.position.x += sin(windT * 1.5) * 0.008 // Subtle wind effect
                }
            }
            
        } attachments: {
            // Control Panel
            Attachment(id: "panel") {
                if !showResults {
                    VStack(spacing: 15) {
                        Text("Room-Scale Balance Walk")
                            .font(.title2)
                            .bold()

                        if !isTestActive {
                            VStack(spacing: 12) {
                                Text("Walk forward in your space while staying on the virtual plank")
                                    .font(.caption)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.secondary)
                                
                                // Replace finicky segmented picker with individual buttons
                                VStack(spacing: 12) {
                                    Text("Difficulty Level")
                                        .font(.headline)
                                    
                                    HStack(spacing: 12) {
                                        ForEach(DifficultyLevel.allCases, id: \.self) { level in
                                            Button {
                                                difficultyLevel = level
                                                applyDifficulty(level)
                                            } label: {
                                                Text(level.rawValue)
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundColor(difficultyLevel == level ? .white : .primary)
                                                    .frame(width: 65, height: 40)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 8)
                                                            .fill(difficultyLevel == level ? Color.blue : Color.gray.opacity(0.2))
                                                    )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }

                                // Better formatted difficulty info
                                VStack(spacing: 4) {
                                    Text("• Width: \(Int(difficultyLevel.plankWidth * 100))cm")
                                        .font(.caption)
                                    Text("• Length: \(Int(plankLength * 100))cm")
                                        .font(.caption)
                                    Text("• Height: \(Int(difficultyLevel.plankHeight))m")
                                        .font(.caption)
                                    if difficultyLevel.windEnabled {
                                        Text("• Wind effects enabled")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                            .fontWeight(.medium)
                                    }
                                    if difficultyLevel.swayEnabled {
                                        Text("• Plank sway enabled")
                                            .font(.caption)
                                            .foregroundColor(.red)
                                            .fontWeight(.medium)
                                    }
                                }
                                .foregroundColor(.secondary)
                                
                                Text("⚠️ Ensure you have 3+ meters of clear walking space")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 8)
                            }

                            Button {
                                startTest()
                            } label: {
                                Label("Start Room-Scale Test", systemImage: "figure.walk")
                                    .font(.system(size: 18, weight: .semibold))
                                    .frame(width: 300, height: 50)
                                    .background(Color.blue, in: RoundedRectangle(cornerRadius: 12))
                                    .foregroundColor(.white)
                            }
                            .buttonStyle(.plain)
                            .frame(width: 300)
                        } else {
                            // During test
                            VStack(spacing: 12) {
                                Text(String(format: "Time: %.1fs", testDuration))
                                    .font(.title2)
                                    .monospacedDigit()

                                let progress = progressPercent()
                                ProgressView(value: progress)
                                    .frame(width: 250)
                                Text("\(Int(progress*100))% Complete")
                                    .font(.caption)
                                
                                Text("Distance: \(String(format: "%.1f", totalDistance))m")
                                    .font(.caption)

                                // Live balance feedback with motion sensor data
                                VStack(spacing: 6) {
                                    Text("Balance Status")
                                        .font(.headline)
                                    
                                    let currentDev = currentDeviationFromPlankCenter()
                                    
                                    HStack(spacing: 16) {
                                        VStack {
                                            Text("Deviation:")
                                                .font(.caption)
                                            Text("\(Int(abs(currentDev) * 100))cm")
                                                .foregroundColor(balanceColor(abs(currentDev)))
                                                .fontWeight(.bold)
                                        }
                                        
                                        VStack {
                                            Text("Speed:")
                                                .font(.caption)
                                            Text(String(format: "%.1f m/s", averageSpeed))
                                                .foregroundColor(speedColor(averageSpeed))
                                        }
                                    }
                                    
                                    Divider()
                                    
                                    // Motion sensor data
                                    Text("Motion Sensors")
                                        .font(.caption.bold())
                                        .foregroundColor(.blue)
                                    
                                    HStack(spacing: 12) {
                                        VStack {
                                            Text("Pitch")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                            Text(String(format: "%.2f", motionManager.pitch))
                                                .font(.caption.bold())
                                                .foregroundColor(.primary)
                                        }
                                        
                                        VStack {
                                            Text("Roll")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                            Text(String(format: "%.2f", motionManager.roll))
                                                .font(.caption.bold())
                                                .foregroundColor(.primary)
                                        }
                                        
                                        VStack {
                                            Text("Yaw")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                            Text(String(format: "%.2f", motionManager.yaw))
                                                .font(.caption.bold())
                                                .foregroundColor(.primary)
                                        }
                                    }
                                    
                                    if isNearEdge {
                                        Text("⚠️ NEAR EDGE!")
                                            .foregroundColor(.red)
                                            .fontWeight(.bold)
                                            .background(Color.red.opacity(0.2))
                                            .cornerRadius(4)
                                    }
                                }
                                .padding(8)
                                .background(.ultraThinMaterial)
                                .cornerRadius(8)

                                Button {
                                    stopTest()
                                } label: {
                                    Text("Complete Test")
                                        .font(.system(size: 16, weight: .medium))
                                        .frame(width: 140, height: 45)
                                        .background(Color.green, in: RoundedRectangle(cornerRadius: 10))
                                        .foregroundColor(.white)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding()
                    .frame(width: 340)
                    .background(.regularMaterial)
                    .cornerRadius(16)
                } else {
                    Color.clear.frame(width: 1, height: 1)
                }
            }

            // Results Panel
            Attachment(id: "card") {
                if showResults, let r = results {
                    VStack(spacing: 16) {
                        Text("Room-Scale Balance Results")
                            .font(.title2)
                            .bold()
                        
                        // Balance Score
                        VStack(spacing: 8) {
                            Text("\(r.balanceScore)")
                                .font(.system(size: 48, weight: .bold))
                                .foregroundColor(scoreColor(r.balanceScore))
                            
                            Text(scoreDescription(r.balanceScore))
                                .font(.headline)
                                .foregroundColor(scoreColor(r.balanceScore))
                        }
                        .padding()
                        .background(scoreColor(r.balanceScore).opacity(0.1))
                        .cornerRadius(12)

                        Grid(alignment: .leading, horizontalSpacing: 20) {
                            GridRow {
                                Text("Duration:")
                                Text(String(format: "%.1fs", r.duration))
                            }
                            GridRow {
                                Text("Distance Walked:")
                                Text(String(format: "%.1f m", r.distanceWalked))
                                    .foregroundColor(.blue)
                            }
                            GridRow {
                                Text("Avg Speed:")
                                Text(String(format: "%.1f m/s", r.averageSpeed))
                                    .foregroundColor(speedColor(r.averageSpeed))
                            }
                            GridRow {
                                Text("Avg Deviation:")
                                Text(String(format: "%.1f cm", r.averageDeviation * 100))
                                    .foregroundColor(balanceColor(r.averageDeviation))
                            }
                            GridRow {
                                Text("Max Deviation:")
                                Text(String(format: "%.1f cm", r.maxDeviation * 100))
                                    .foregroundColor(balanceColor(r.maxDeviation))
                            }
                            GridRow {
                                Text("Near Misses:")
                                Text("\(r.nearMisses)")
                                    .foregroundColor(r.nearMisses > 2 ? .red : .green)
                            }
                            GridRow {
                                Text("Walking Consistency:")
                                Text(String(format: "%.0f%%", r.walkingConsistency * 100))
                                    .foregroundColor(r.walkingConsistency > 0.7 ? .green : .orange)
                            }
                            GridRow {
                                Text("Difficulty:")
                                Text(r.difficulty)
                            }
                        }
                        .font(.system(size: 14))

                        Button("Complete Test") {
                            Task {
                                await viewRouter.closeImmersiveSpace(
                                    dismissImmersiveSpace: { await dismissImmersiveSpace() },
                                    openMainWindow: { openWindow(id: "MainWindow") }
                                )
                            }
                        }
                        .font(.system(size: 16, weight: .medium))
                        .frame(width: 140, height: 45)
                        .background(Color.blue, in: RoundedRectangle(cornerRadius: 10))
                        .foregroundColor(.white)
                        .buttonStyle(.plain)
                    }
                    .padding()
                    .frame(width: 420)
                    .background(.regularMaterial)
                    .cornerRadius(20)
                } else {
                    Color.clear.frame(width: 1, height: 1)
                }
            }
            
            // Exit Button
            Attachment(id: "exit") {
                Button {
                    Task {
                        await viewRouter.closeImmersiveSpace(
                            dismissImmersiveSpace: { await dismissImmersiveSpace() },
                            openMainWindow: { openWindow(id: "MainWindow") }
                        )
                    }
                } label: {
                    Label("Exit", systemImage: "xmark.circle.fill")
                        .font(.title2)
                        .padding(12)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .onAppear { 
            startHeadPose()
            motionManager.startUpdates()  // Add motion updates
        }
        .onDisappear { 
            stopHeadPose()
            motionManager.stopUpdates()  // Stop motion updates
            stopTest() 
        }
    }

    // MARK: Environment Creation
    private func createRoomScaleEnvironment() -> Entity {
        let root = Entity()

        // Create plank that will follow user movement
        let plank = createPlank()
        plankEntity = plank
        root.addChild(plank)

        // Create environment effects
        createVoid(in: root)
        createAtmosphere(in: root)
        createDistanceMarkers(in: root)
        
        return root
    }

    private func createPlank() -> Entity {
        let e = Entity()
        let mesh = MeshResource.generateBox(width: plankWidth, height: 0.08, depth: plankLength)
        var mat = SimpleMaterial()
        // More visible plank but not overwhelming
        mat.color = .init(tint: UIColor(red: 0.8, green: 0.6, blue: 0.3, alpha: 0.9))
        mat.roughness = 0.5; mat.metallic = 0.4
        e.addChild(ModelEntity(mesh: mesh, materials: [mat]))

        // More prominent edge markers - safety critical
        let edgeMat = SimpleMaterial(color: UIColor.red.withAlphaComponent(0.95), isMetallic: false)
        let edgeH: Float = 0.04, edgeW: Float = 0.02
        let left  = ModelEntity(mesh: .generateBox(width: edgeW, height: edgeH, depth: plankLength), materials: [edgeMat])
        let right = ModelEntity(mesh: .generateBox(width: edgeW, height: edgeH, depth: plankLength), materials: [edgeMat])
        left.position  = [-plankWidth/2, 0.04, 0]
        right.position = [ plankWidth/2, 0.04, 0]
        e.addChild(left); e.addChild(right)

        // More visible center line
        let center = ModelEntity(mesh: .generateBox(width: 0.04, height: 0.003, depth: plankLength),
                             materials: [SimpleMaterial(color: .white.withAlphaComponent(0.95), isMetallic: false)])
        center.position.y = 0.042
        e.addChild(center)
        
        // More subtle distance markers on the plank
        for i in stride(from: -plankLength/2, through: plankLength/2, by: 1.0) {
            let marker = ModelEntity(mesh: .generateBox(width: 0.008, height: 0.001, depth: 0.08),
                                 materials: [SimpleMaterial(color: .yellow.withAlphaComponent(0.4), isMetallic: false)])
            marker.position = [0, 0.042, i]
            e.addChild(marker)
        }
        
        return e
    }

    private func createVoid(in root: Entity) {
        // No ground plane at all - users can see their real environment
    }

    private func createAtmosphere(in root: Entity) {
        // Keep only essential side barriers as subtle guides - no particles
        let barrierMat = SimpleMaterial(color: UIColor.blue.withAlphaComponent(0.1), isMetallic: false)
        let leftBarrier = ModelEntity(mesh: .generateBox(width: 0.02, height: 0.5, depth: plankLength * 1.2),
                                  materials: [barrierMat])
        leftBarrier.position = [-2.5, 0.25, 0]
        root.addChild(leftBarrier)
        
        let rightBarrier = ModelEntity(mesh: .generateBox(width: 0.02, height: 0.5, depth: plankLength * 1.2),
                                   materials: [barrierMat])
        rightBarrier.position = [2.5, 0.25, 0]
        root.addChild(rightBarrier)
    }
    
    private func createDistanceMarkers(in root: Entity) {
        // More subtle distance markers
        for i in stride(from: -8, through: 8, by: 2) {
            let marker = ModelEntity(mesh: .generateBox(width: 0.3, height: 0.05, depth: 0.05),
                                     materials: [SimpleMaterial(color: .green.withAlphaComponent(0.3), isMetallic: false)])
            marker.position = [0, -0.3, Float(i)]
            root.addChild(marker)
        }
    }

    // MARK: Test Control
    private func startTest() {
        isTestActive = true
        testStartTime = CACurrentMediaTime()
        testDuration = 0
        startPosition = headPosW
        lastPosition = headPosW
        totalDistance = 0
        forwardProgress = 0

        path.removeAll()
        pathPositions.removeAll()
        totalDeviation = 0
        maxDeviation = 0
        nearMisses = 0
        isNearEdge = false
        averageSpeed = 0
        lookDownTime = 0
        
        // Position plank at user's starting location
        if let plank = plankEntity {
            plank.position = [headPosW.x, 0, headPosW.z]
        }
    }

    private func stopTest() {
        guard isTestActive else { return }
        isTestActive = false

        let avgDev = path.isEmpty ? 0 : totalDeviation / Float(path.count)
        let walkingConsistency = calculateWalkingConsistency()
        let balanceScore = calculateBalanceScore(avgDev: avgDev, maxDev: maxDeviation, nearMisses: nearMisses, consistency: walkingConsistency)

        results = TestResults(
            duration: testDuration,
            completed: totalDistance >= 3.0, // 3 meters minimum
            distanceWalked: totalDistance,
            averageDeviation: avgDev,
            maxDeviation: maxDeviation,
            nearMisses: nearMisses,
            averageSpeed: averageSpeed,
            lookDownPct: Float(lookDownTime / max(1, testDuration)) * 100,
            difficulty: difficultyLevel.rawValue,
            balanceScore: balanceScore,
            walkingConsistency: walkingConsistency
        )
        showResults = true
    }

    // MARK: Head Tracking
    private func startHeadPose() {
        headTask?.cancel()
        headTask = Task {
            do {
                try await arkitSession.requestAuthorization(for: [.worldSensing])
                try await arkitSession.run([worldTracking])

                var lastTime = CACurrentMediaTime()
                while !Task.isCancelled {
                    if let d = worldTracking.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()), d.isTracked {
                        let m = d.originFromAnchorTransform
                        let pos = SIMD3<Float>(m.columns.3.x, m.columns.3.y, m.columns.3.z)
                        let rot = simd_quatf(m)

                        // Track downward gaze
                        let forward = simd_act(rot, SIMD3<Float>(0,0,-1))
                        let pitch = asin(-forward.y)
                        let now = CACurrentMediaTime()
                        let dt = now - lastTime
                        lastTime = now
                        if pitch < -0.35 { lookDownTime += dt }

                        await MainActor.run {
                            let oldPos = headPosW
                            headPosW = pos
                            testTick(oldPos: oldPos, dt: dt)
                        }
                    }
                    try? await Task.sleep(nanoseconds: 16_000_000) // ~60 Hz
                }
            } catch {
                print("ARKit error:", error)
            }
        }
    }

    private func stopHeadPose() {
        headTask?.cancel()
        headTask = nil
    }

    private func testTick(oldPos: SIMD3<Float>, dt: TimeInterval) {
        guard isTestActive, let start = startPosition else { return }
        testDuration = CACurrentMediaTime() - testStartTime

        // Calculate movement distance
        let movementDelta = simd_distance(headPosW, oldPos)
        if movementDelta < 0.5 { // Filter out tracking noise
            totalDistance += movementDelta
            pathPositions.append(headPosW)
        }

        // Calculate current speed (smoothed)
        let instantSpeed = movementDelta / Float(dt)
        averageSpeed = (averageSpeed * 0.9) + (instantSpeed * 0.1) // Smooth averaging

        // Balance metrics - deviation from plank centerline
        let deviation = currentDeviationFromPlankCenter()
        totalDeviation += abs(deviation)
        maxDeviation = max(maxDeviation, abs(deviation))
        
        // Near edge detection
        let edgeThreshold = (plankWidth / 2) * 0.9
        let wasNear = isNearEdge
        isNearEdge = abs(deviation) > edgeThreshold
        if isNearEdge && !wasNear { nearMisses += 1 }

        path.append(PathPoint(
            t: testDuration, 
            position: headPosW, 
            devX: abs(deviation),
            speed: instantSpeed
        ))

        // Auto-completion for longer walks
        if totalDistance >= 5.0 && testDuration > 30 {
            stopTest()
        }
    }

    // MARK: Helper Functions
    private func progressPercent() -> Double {
        let targetDistance: Float = 3.0 // 3 meters target
        return min(1.0, Double(totalDistance / targetDistance))
    }

    private func currentDeviationFromPlankCenter() -> Float {
        guard let plank = plankEntity else { return 0 }
        let plankWorldPos = plank.position(relativeTo: nil)
        return headPosW.x - plankWorldPos.x
    }

    private func applyDifficulty(_ d: DifficultyLevel) {
        plankWidth = d.plankWidth
        plankHeight = d.plankHeight
        if let root = environmentRoot, let old = plankEntity {
            let t = old.transform
            old.removeFromParent()
            let newPlank = createPlank()
            newPlank.transform = t
            plankEntity = newPlank
            root.addChild(newPlank)
        }
    }
    
    private func calculateWalkingConsistency() -> Float {
        guard path.count > 10 else { return 0 }
        
        let speeds = path.map { $0.speed }
        let avgSpeed = speeds.reduce(0, +) / Float(speeds.count)
        let variance = speeds.map { pow($0 - avgSpeed, 2) }.reduce(0, +) / Float(speeds.count)
        let stdDev = sqrt(variance)
        
        // Return consistency as 0-1 (1 = very consistent)
        return max(0, 1 - (stdDev / max(avgSpeed, 0.1)))
    }
    
    private func calculateBalanceScore(avgDev: Float, maxDev: Float, nearMisses: Int, consistency: Float) -> Int {
        var score = 100
        
        // Penalize for lateral deviation
        score -= Int(avgDev * 1500) // More strict for room-scale
        score -= Int(maxDev * 800)
        
        // Near miss penalty
        score -= nearMisses * 20
        
        // Reward walking consistency
        score += Int(consistency * 15)
        
        return max(0, min(100, score))
    }

    private func balanceColor(_ deviation: Float) -> Color {
        if deviation < 0.05 { return .green }      // < 5cm
        if deviation < 0.10 { return .yellow }     // 5-10cm
        if deviation < 0.15 { return .orange }     // 10-15cm
        return .red                                // > 15cm
    }
    
    private func speedColor(_ speed: Float) -> Color {
        if speed < 0.3 { return .orange }  // Too slow
        if speed > 1.5 { return .red }     // Too fast
        return .green                      // Good speed
    }
    
    private func scoreColor(_ score: Int) -> Color {
        if score >= 85 { return .green }
        if score >= 70 { return .yellow }
        if score >= 50 { return .orange }
        return .red
    }
    
    private func scoreDescription(_ score: Int) -> String {
        if score >= 90 { return "Excellent Room-Scale Balance" }
        if score >= 80 { return "Good Walking Balance" }
        if score >= 70 { return "Fair Balance Control" }
        if score >= 60 { return "Poor Balance" }
        return "Balance Issues - Consider Evaluation"
    }
}