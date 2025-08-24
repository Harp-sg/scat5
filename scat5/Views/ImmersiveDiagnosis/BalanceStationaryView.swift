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
            
            // Exit button
            if let exit = attachments.entity(for: "exit") {
                let anchor = AnchorEntity(.head)
                exit.position = [0.8, 0.4, -1.2]
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
                                
                                Picker("Difficulty", selection: $difficultyLevel) {
                                    ForEach(DifficultyLevel.allCases, id: \.self) { 
                                        Text($0.rawValue).tag($0) 
                                    }
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 280)
                                .onChange(of: difficultyLevel) { _, new in 
                                    applyDifficulty(new)
                                    walkingSpeed = new.autoSpeed
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Walking Speed: \(String(format: "%.1f", walkingSpeed)) m/s")
                                        .font(.caption)
                                    Slider(value: $walkingSpeed, in: 0.2...1.5, step: 0.1)
                                        .frame(width: 260)
                                }
                                
                                Text("• Width: \(Int(difficultyLevel.plankWidth * 100))cm")
                                    .font(.caption2)
                                Text("• Height: \(Int(difficultyLevel.plankHeight))m")
                                    .font(.caption2)
                                if difficultyLevel.swayEnabled {
                                    Text("• Plank sway enabled")
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                }
                            }

                            Button {
                                startTest()
                            } label: {
                                Label("Start Stationary Test", systemImage: "figure.stand")
                                    .font(.title3)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
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

                                // Live balance feedback
                                VStack(spacing: 6) {
                                    Text("Balance Status")
                                        .font(.headline)
                                    
                                    let devX = currentDeviationFromPlankCenterX()
                                    let devZ = currentDeviationZ()
                                    
                                    HStack {
                                        Text("L-R:")
                                        Text("\(Int(abs(devX) * 100))cm")
                                            .foregroundColor(balanceColor(abs(devX)))
                                            .fontWeight(.bold)
                                    }
                                    
                                    HStack {
                                        Text("F-B:")
                                        Text("\(Int(abs(devZ) * 100))cm")
                                            .foregroundColor(balanceColor(abs(devZ)))
                                            .fontWeight(.bold)
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
                                            .frame(width: 50, height: 40)
                                            .background(Color.orange)
                                            .foregroundColor(.white)
                                            .cornerRadius(8)
                                    }
                                    
                                    Button {
                                        stopTest()
                                    } label: {
                                        Text("Stop")
                                            .frame(width: 80, height: 40)
                                            .background(Color.red)
                                            .foregroundColor(.white)
                                            .cornerRadius(8)
                                    }
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
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
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
            walkingSpeed = difficultyLevel.autoSpeed
        }
        .onDisappear { 
            stopHeadPose()
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
        mat.color = .init(tint: UIColor(red: 0.6, green: 0.4, blue: 0.2, alpha: 1))
        mat.roughness = 0.8; mat.metallic = 0.1
        e.addChild(ModelEntity(mesh: mesh, materials: [mat]))

        let edgeMat = SimpleMaterial(color: UIColor.red.withAlphaComponent(0.8), isMetallic: false)
        let edgeH: Float = 0.02, edgeW: Float = 0.01
        let left  = ModelEntity(mesh: .generateBox(width: edgeW, height: edgeH, depth: plankLength), materials: [edgeMat])
        let right = ModelEntity(mesh: .generateBox(width: edgeW, height: edgeH, depth: plankLength), materials: [edgeMat])
        left.position  = [-plankWidth/2, 0.03, 0]
        right.position = [ plankWidth/2, 0.03, 0]
        e.addChild(left); e.addChild(right)

        let center = ModelEntity(mesh: .generateBox(width: 0.02, height: 0.001, depth: plankLength),
                                 materials: [SimpleMaterial(color: .white.withAlphaComponent(0.5), isMetallic: false)])
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
        let void = ModelEntity(mesh: .generatePlane(width: 50, depth: 50),
                               materials: [SimpleMaterial(color: .black, isMetallic: false)])
        void.position.y = -plankHeight
        void.orientation = simd_quatf(angle: -.pi/2, axis: [1,0,0])
        root.addChild(void)
        for i in 1...5 {
            let mist = ModelEntity(mesh: .generatePlane(width: 30, depth: 30),
                                   materials: [SimpleMaterial(color: UIColor.gray.withAlphaComponent(0.1), isMetallic: false)])
            mist.position.y = -Float(i) * 2
            mist.orientation = simd_quatf(angle: -.pi/2, axis: [1,0,0])
            root.addChild(mist)
        }
    }

    private func createAtmosphere(in root: Entity) {
        for _ in 0..<20 {
            let cube = ModelEntity(mesh: .generateBox(size: 0.5),
                                   materials: [SimpleMaterial(color: UIColor.white.withAlphaComponent(0.3), isMetallic: false)])
            cube.position = [Float.random(in: -10...10), Float.random(in: -plankHeight...5), Float.random(in: -10...10)]
            if abs(cube.position.x) < 2 && abs(cube.position.z) < plankLength/2 + 2 {
                cube.position.x = cube.position.x < 0 ? -3 : 3
            }
            root.addChild(cube)
        }
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