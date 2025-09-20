import SwiftUI
import RealityKit
import ARKit

struct BalanceStationaryView: View {
    @Environment(ViewRouter.self) private var viewRouter
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openWindow) private var openWindow
    
    // MARK: Entities
    @State private var plankEntity: Entity?
    @State private var startPlatformEntity: Entity?
    @State private var endPlatformEntity: Entity?
    @State private var environmentRoot: Entity?

    // MARK: Test state
    @State private var isTestActive = false
    @State private var isAutoWalking = false
    @State private var testStartTime: TimeInterval = 0
    @State private var testDuration: TimeInterval = 0

    // MARK: Plank config
    @State private var plankLength: Float = 4.0
    @State private var plankWidth:  Float = 0.30
    @State private var plankHeight: Float = 10.0
    @State private var difficultyLevel: DifficultyLevel = .medium

    enum DifficultyLevel: String, CaseIterable {
        case easy = "Easy", medium = "Medium", hard = "Hard", extreme = "Extreme"
        var plankWidth: Float  { switch self { case .easy: 0.50; case .medium: 0.30; case .hard: 0.20; case .extreme: 0.15 } }
        var plankHeight: Float { switch self { case .easy: 5;    case .medium: 10;   case .hard: 15;   case .extreme: 20   } }
        var swayEnabled: Bool { self == .extreme }
        var autoSpeed: Float { switch self { case .easy: 0.3; case .medium: 0.5; case .hard: 0.8; case .extreme: 1.2 } }
    }

    // MARK: ARKit / pose
    @State private var arkitSession = ARKitSession()
    @State private var worldTracking = WorldTrackingProvider()
    @State private var headTask: Task<Void, Never>?
    @State private var headPosW: SIMD3<Float> = .zero
    @State private var headRefW: SIMD3<Float>?

    // MARK: Virtual locomotion - automatic movement
    @State private var virtualForward: Float = 0
    @State private var walkingSpeed: Float = 0.5 // meters per second

    // MARK: Metrics
    struct PathPoint { let t: TimeInterval; let devX: Float; let devZ: Float }
    @State private var path: [PathPoint] = []
    @State private var totalDevX: Float = 0
    @State private var totalDevZ: Float = 0 // Forward/backward sway
    @State private var maxDevX: Float = 0
    @State private var maxDevZ: Float = 0
    @State private var nearMisses: Int = 0
    @State private var isNearEdge = false
    @State private var lookDownTime: TimeInterval = 0
    @State private var lastTick: TimeInterval = CACurrentMediaTime()

    struct TestResults {
        let duration: TimeInterval
        let completed: Bool
        let averageDeviationX: Float
        let maxDeviationX: Float
        let averageDeviationZ: Float
        let maxDeviationZ: Float
        let nearMisses: Int
        let lookDownPct: Float
        let difficulty: String
        let balanceScore: Int // 0-100
    }
    @State private var results: TestResults?
    @State private var showResults = false

    // Add motion manager for balance sensor data
    @State private var motionManager = MotionManager()

    var body: some View {
        RealityView { content, attachments in
            // Scene
            let root = createEnvironment()
            environmentRoot = root
            content.add(root)

            // Control panel
            if let panel = attachments.entity(for: "panel") {
                let anchor = AnchorEntity(.head)
                panel.position = [0, -0.3, -1.5]
                panel.components.set(BillboardComponent())
                anchor.addChild(panel)
                content.add(anchor)
            }
            
            // Results panel
            if let card = attachments.entity(for: "card") {
                let anchor = AnchorEntity(.head)
                card.position = [0, 0, -1.2]
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
            
        } update: { _, _ in
            // Auto-walking: move world toward user
            if isTestActive && isAutoWalking {
                let deltaTime = Float(1.0/90.0) // Assume 90fps
                virtualForward += walkingSpeed * deltaTime
                
                // Apply movement
                if let env = environmentRoot {
                    env.position.z = virtualForward
                }
            }
            
            // Optional sway on extreme
            if isTestActive, difficultyLevel.swayEnabled, let plank = plankEntity {
                let t = Float(CACurrentMediaTime() - testStartTime)
                plank.position.x = sin(t * 0.8) * 0.03 // More sway
                plank.position.y = sin(t * 1.2) * 0.01 // Vertical bob
            }
            
        } attachments: {
            // Control Panel
            Attachment(id: "panel") {
                if !showResults {
                    VStack(spacing: 15) {
                        Text("Stationary Balance Test")
                            .font(.title2)
                            .bold()

                        if !isTestActive {
                            VStack(spacing: 12) {
                                Text("Stand still while the plank moves beneath you")
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
                                                walkingSpeed = level.autoSpeed
                                            } label: {
                                                Text(level.rawValue)
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundColor(difficultyLevel == level ? .white : .primary)
                                                    .frame(width: 65, height: 40)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 8)
                                                            .fill(difficultyLevel == level ? Color.green : Color.gray.opacity(0.2))
                                                    )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }

                                // Replace finicky slider with +/- buttons
                                VStack(spacing: 8) {
                                    Text("Walking Speed: \(String(format: "%.1f", walkingSpeed)) m/s")
                                        .font(.system(size: 16, weight: .medium))
                                    
                                    HStack(spacing: 12) {
                                        Button("-0.1") {
                                            walkingSpeed = max(0.2, walkingSpeed - 0.1)
                                        }
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                        .frame(width: 50, height: 36)
                                        .background(Color.blue, in: RoundedRectangle(cornerRadius: 6))
                                        .buttonStyle(.plain)
                                        
                                        Text("\(String(format: "%.1f", walkingSpeed))")
                                            .font(.system(size: 18, weight: .bold))
                                            .frame(width: 60)
                                        
                                        Button("+0.1") {
                                            walkingSpeed = min(1.5, walkingSpeed + 0.1)
                                        }
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                        .frame(width: 50, height: 36)
                                        .background(Color.blue, in: RoundedRectangle(cornerRadius: 6))
                                        .buttonStyle(.plain)
                                    }
                                }
                                
                                // Difficulty info - better formatted
                                VStack(spacing: 4) {
                                    Text("• Width: \(Int(difficultyLevel.plankWidth * 100))cm")
                                        .font(.caption)
                                    Text("• Height: \(Int(difficultyLevel.plankHeight))m")
                                        .font(.caption)
                                    if difficultyLevel.swayEnabled {
                                        Text("• Plank sway enabled")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                            .fontWeight(.medium)
                                    }
                                }
                                .foregroundColor(.secondary)
                            }

                            Button {
                                startTest()
                            } label: {
                                Label("Start Stationary Test", systemImage: "figure.stand")
                                    .font(.system(size: 18, weight: .semibold))
                                    .frame(width: 280, height: 50)
                                    .background(Color.green, in: RoundedRectangle(cornerRadius: 12))
                                    .foregroundColor(.white)
                            }
                            .buttonStyle(.plain)
                            .frame(width: 280)
                        } else {
                            // During test
                            VStack(spacing: 12) {
                                Text(String(format: "Time: %.1fs", testDuration))
                                    .font(.title2)
                                    .monospacedDigit()

                                let progress = progressPercent()
                                ProgressView(value: progress)
                                    .frame(width: 220)
                                Text("\(Int(progress*100))% Complete")
                                    .font(.caption)

                                // Live balance feedback with motion sensor data
                                VStack(spacing: 6) {
                                    Text("Balance Status")
                                        .font(.headline)
                                    
                                    let devX = currentDeviationFromPlankCenterX()
                                    let devZ = currentDeviationZ()
                                    
                                    // Position deviation
                                    HStack(spacing: 16) {
                                        VStack {
                                            Text("L-R:")
                                                .font(.caption)
                                            Text("\(Int(abs(devX) * 100))cm")
                                                .foregroundColor(balanceColor(abs(devX)))
                                                .fontWeight(.bold)
                                        }
                                        
                                        VStack {
                                            Text("F-B:")
                                                .font(.caption)
                                            Text("\(Int(abs(devZ) * 100))cm")
                                                .foregroundColor(balanceColor(abs(devZ)))
                                                .fontWeight(.bold)
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
                                    }
                                }
                                .padding(8)
                                .background(.ultraThinMaterial)
                                .cornerRadius(8)

                                HStack(spacing: 16) {
                                    Button {
                                        isAutoWalking.toggle()
                                    } label: {
                                        Image(systemName: isAutoWalking ? "pause.fill" : "play.fill")
                                            .font(.system(size: 18))
                                            .frame(width: 60, height: 45)
                                            .background(Color.orange, in: RoundedRectangle(cornerRadius: 10))
                                            .foregroundColor(.white)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Button {
                                        stopTest()
                                    } label: {
                                        Text("Stop")
                                            .font(.system(size: 16, weight: .medium))
                                            .frame(width: 80, height: 45)
                                            .background(Color.red, in: RoundedRectangle(cornerRadius: 10))
                                            .foregroundColor(.white)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding()
                    .frame(width: 320)
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
                        Text("Balance Test Results")
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
                                Text("Difficulty:")
                                Text(r.difficulty)
                            }
                            GridRow {
                                Text("Avg L-R Dev:")
                                Text(String(format: "%.1f cm", r.averageDeviationX * 100))
                                    .foregroundColor(balanceColor(r.averageDeviationX))
                            }
                            GridRow {
                                Text("Max L-R Dev:")
                                Text(String(format: "%.1f cm", r.maxDeviationX * 100))
                                    .foregroundColor(balanceColor(r.maxDeviationX))
                            }
                            GridRow {
                                Text("Avg F-B Dev:")
                                Text(String(format: "%.1f cm", r.averageDeviationZ * 100))
                                    .foregroundColor(balanceColor(r.averageDeviationZ))
                            }
                            GridRow {
                                Text("Near Misses:")
                                Text("\(r.nearMisses)")
                                    .foregroundColor(r.nearMisses > 3 ? .red : .green)
                            }
                            GridRow {
                                Text("Looking Down:")
                                Text(String(format: "%.0f%%", r.lookDownPct))
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
                    .frame(width: 400)
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
            walkingSpeed = difficultyLevel.autoSpeed
        }
        .onDisappear { 
            stopHeadPose()
            motionManager.stopUpdates()  // Stop motion updates
            stopTest() 
        }
    }

    // MARK: Environment Creation (same as original)
    private func createEnvironment() -> Entity {
        let root = Entity()

        let plank = createPlank()
        plankEntity = plank
        root.addChild(plank)

        let start = createPlatform(isStart: true)
        start.position = [0, 0, plankLength/2 + 0.5]
        startPlatformEntity = start
        root.addChild(start)

        let end = createPlatform(isStart: false)
        end.position = [0, 0, -plankLength/2 - 0.5]
        endPlatformEntity = end
        root.addChild(end)

        createVoid(in: root)
        createAtmosphere(in: root)
        return root
    }

    private func createPlank() -> Entity {
        let e = Entity()
        let mesh = MeshResource.generateBox(width: plankWidth, height: 0.05, depth: plankLength)
        var mat = SimpleMaterial()
        // Make plank more visible but not overwhelming
        mat.color = .init(tint: UIColor(red: 0.8, green: 0.6, blue: 0.3, alpha: 0.9))
        mat.roughness = 0.6; mat.metallic = 0.3
        e.addChild(ModelEntity(mesh: mesh, materials: [mat]))

        // More prominent edge markers for safety
        let edgeMat = SimpleMaterial(color: UIColor.red.withAlphaComponent(0.9), isMetallic: false)
        let edgeH: Float = 0.03, edgeW: Float = 0.02
        let left  = ModelEntity(mesh: .generateBox(width: edgeW, height: edgeH, depth: plankLength), materials: [edgeMat])
        let right = ModelEntity(mesh: .generateBox(width: edgeW, height: edgeH, depth: plankLength), materials: [edgeMat])
        left.position  = [-plankWidth/2, 0.03, 0]
        right.position = [ plankWidth/2, 0.03, 0]
        e.addChild(left); e.addChild(right)

        // More visible center line
        let center = ModelEntity(mesh: .generateBox(width: 0.03, height: 0.002, depth: plankLength),
                                 materials: [SimpleMaterial(color: .white.withAlphaComponent(0.9), isMetallic: false)])
        center.position.y = 0.026
        e.addChild(center)
        return e
    }

    private func createPlatform(isStart: Bool) -> Entity {
        let e = Entity()
        let size: Float = 1.5
        let mesh = MeshResource.generateBox(width: size, height: 0.1, depth: size)
        var m = SimpleMaterial()
        m.color = .init(tint: (isStart ? UIColor.green : UIColor.blue).withAlphaComponent(0.8))
        e.addChild(ModelEntity(mesh: mesh, materials: [m]))
        return e
    }

    private func createVoid(in root: Entity) {
        // Just keep minimal reference elements if needed
        
        // Optional: Just a few very small reference markers at plank level instead
        for i in stride(from: -2, through: 2, by: 2) {
            let marker = ModelEntity(mesh: .generateSphere(radius: 0.02),
                                   materials: [SimpleMaterial(color: .blue.withAlphaComponent(0.3), isMetallic: false)])
            marker.position = [Float(i), -plankHeight + 0.1, 0]
            root.addChild(marker)
        }
    }

    private func createAtmosphere(in root: Entity) {
        // Keep the environment completely clean - just the plank
    }

    // MARK: Test Control
    private func startTest() {
        isTestActive = true
        isAutoWalking = true
        testStartTime = CACurrentMediaTime()
        testDuration = 0
        virtualForward = 0
        headRefW = headPosW

        path.removeAll()
        totalDevX = 0; totalDevZ = 0
        maxDevX = 0; maxDevZ = 0
        nearMisses = 0; isNearEdge = false
        lookDownTime = 0
        lastTick = CACurrentMediaTime()
    }

    private func stopTest() {
        guard isTestActive else { return }
        isTestActive = false
        isAutoWalking = false

        let avgX = path.isEmpty ? 0 : totalDevX / Float(path.count)
        let avgZ = path.isEmpty ? 0 : totalDevZ / Float(path.count)
        
        // Calculate balance score (0-100)
        let balanceScore = calculateBalanceScore(avgX: avgX, avgZ: avgZ, maxX: maxDevX, nearMisses: nearMisses)

        results = TestResults(
            duration: testDuration,
            completed: virtualForward >= plankLength,
            averageDeviationX: avgX,
            maxDeviationX: maxDevX,
            averageDeviationZ: avgZ,
            maxDeviationZ: maxDevZ,
            nearMisses: nearMisses,
            lookDownPct: Float(lookDownTime / max(1, testDuration)) * 100,
            difficulty: difficultyLevel.rawValue,
            balanceScore: balanceScore
        )
        showResults = true
    }

    // MARK: Head Tracking and Metrics
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
                            headPosW = pos
                            testTick(dt: dt)
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

    private func testTick(dt: TimeInterval) {
        guard isTestActive else { return }
        testDuration = CACurrentMediaTime() - testStartTime

        // Balance metrics
        let devX = currentDeviationFromPlankCenterX()
        let devZ = currentDeviationZ()
        
        totalDevX += abs(devX)
        totalDevZ += abs(devZ)
        maxDevX = max(maxDevX, abs(devX))
        maxDevZ = max(maxDevZ, abs(devZ))
        
        let edgeThreshold = (plankWidth / 2) * 0.85
        let wasNear = isNearEdge
        isNearEdge = abs(devX) > edgeThreshold
        if isNearEdge && !wasNear { nearMisses += 1 }

        path.append(PathPoint(t: testDuration, devX: abs(devX), devZ: abs(devZ)))

        // Auto-completion
        if virtualForward >= plankLength + 1.0 {
            stopTest()
        }
    }

    // MARK: Helper Functions
    private func progressPercent() -> Double {
        let total = plankLength + 1.0
        return min(1.0, Double(max(0, virtualForward / total)))
    }

    private func currentDeviationFromPlankCenterX() -> Float {
        guard let plank = plankEntity else { return 0 }
        let m = plank.transformMatrix(relativeTo: nil)
        let plankX = m.columns.3.x
        return headPosW.x - plankX
    }
    
    private func currentDeviationZ() -> Float {
        guard let ref = headRefW else { return 0 }
        return headPosW.z - ref.z
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
    
    private func calculateBalanceScore(avgX: Float, avgZ: Float, maxX: Float, nearMisses: Int) -> Int {
        var score = 100
        
        // Penalize for lateral deviation (most important)
        score -= Int(avgX * 1000) // 1cm = 10 points
        score -= Int(maxX * 500)  // Max deviation penalty
        
        // Penalize for forward/backward sway
        score -= Int(avgZ * 800)
        
        // Near miss penalty
        score -= nearMisses * 15
        
        return max(0, min(100, score))
    }

    private func balanceColor(_ deviation: Float) -> Color {
        if deviation < 0.03 { return .green }      // < 3cm
        if deviation < 0.06 { return .yellow }     // 3-6cm
        if deviation < 0.10 { return .orange }     // 6-10cm
        return .red                                // > 10cm
    }
    
    private func scoreColor(_ score: Int) -> Color {
        if score >= 85 { return .green }
        if score >= 70 { return .yellow }
        if score >= 50 { return .orange }
        return .red
    }
    
    private func scoreDescription(_ score: Int) -> String {
        if score >= 90 { return "Excellent Balance" }
        if score >= 80 { return "Good Balance" }
        if score >= 70 { return "Fair Balance" }
        if score >= 60 { return "Poor Balance" }
        return "Balance Issues"
    }
}