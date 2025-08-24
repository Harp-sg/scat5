import SwiftUI
import RealityKit
import ARKit

struct BalancePredictionView: View {
    // MARK: Entities
    @State private var plankEntity: Entity?
    @State private var startPlatformEntity: Entity?
    @State private var endPlatformEntity: Entity?
    @State private var environmentRoot: Entity?

    // MARK: Test state
    @State private var isTestActive = false
    @State private var hasStartedWalking = false
    @State private var hasCompletedWalk = false
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
    }

    // MARK: ARKit / pose
    @State private var arkitSession = ARKitSession()
    @State private var worldTracking = WorldTrackingProvider()
    @State private var headTask: Task<Void, Never>?
    @State private var headPosW: SIMD3<Float> = .zero
    @State private var headRefW: SIMD3<Float>?
    @State private var driftRadiusLimit: Float = 0.25        // keep within 25 cm of origin
    @State private var recenterOffset: SIMD3<Float> = .zero  // world shifts applied to keep head near origin

    // MARK: Virtual locomotion
    @State private var virtualForward: Float = 0             // meters "walked" along -Z
    @State private var stepLengthM: Float = 0.55             // meters per detected step
    @State private var minStepInterval: TimeInterval = 0.33  // debounce
    @State private var lastStepTime: TimeInterval = 0

    // Head-bob based step detection (simple peak detector on head Y)
    @State private var yHistory: [Float] = []
    private let yHistoryLen = 25                // ~0.4s at 60Hz
    private let bobThreshold: Float = 0.015     // ~1.5 cm vertical delta to count a peak

    // MARK: Metrics
    struct PathPoint { let t: TimeInterval; let devX: Float }
    @State private var path: [PathPoint] = []
    @State private var totalDev: Float = 0
    @State private var maxDev: Float = 0
    @State private var stepCount: Int = 0
    @State private var nearMisses: Int = 0
    @State private var isNearEdge = false
    @State private var lookDownTime: TimeInterval = 0
    @State private var lastTick: TimeInterval = CACurrentMediaTime()

    struct TestResults {
        let duration: TimeInterval
        let completed: Bool
        let averageDeviation: Float
        let maxDeviation: Float
        let stepCount: Int
        let nearMisses: Int
        let lookDownPct: Float
        let difficulty: String
    }
    @State private var results: TestResults?
    @State private var showResults = false

    // MARK: HUD anchors (to toggle visibility)
    @State private var hudAnchor: AnchorEntity?
    @State private var cardAnchor: AnchorEntity?

    // MARK: Body
    var body: some View {
        RealityView { content, attachments in
            // Scene
            let root = createEnvironment()
            environmentRoot = root
            content.add(root)

            // HUD
            if let panel = attachments.entity(for: "panel") {
                let a = AnchorEntity(.head, trackingMode: .continuous)
                panel.position = [0, 0, -1.0]
                panel.components.set(BillboardComponent())
                a.addChild(panel)
                hudAnchor = a
                content.add(a)
            }
            // Results card
            if let card = attachments.entity(for: "card") {
                let a = AnchorEntity(.head, trackingMode: .continuous)
                card.position = [0, 0, -1.2]
                card.components.set(BillboardComponent())
                a.addChild(card)
                cardAnchor = a
                content.add(a)
            }
        } update: { _, _ in
            // Optional sway on extreme
            if isTestActive, difficultyLevel.swayEnabled, let plank = plankEntity {
                let t = Float(CACurrentMediaTime() - testStartTime)
                plank.position.x = sin(t * 0.5) * 0.02
            }
            // Apply virtual forward each frame: move whole world toward user along +Z
            if let env = environmentRoot {
                env.position.z = recenterOffset.z + virtualForward
                env.position.x = recenterOffset.x
            }
        } attachments: {
            Attachment(id: "panel") {
                // Hide the panel while results are shown
                if !showResults {
                    VStack(spacing: 12) {
                        Text("Plank Walk Test").font(.title3).bold()

                        // Settings (when idle)
                        if !isTestActive {
                            Picker("Difficulty", selection: $difficultyLevel) {
                                ForEach(DifficultyLevel.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 260)
                            .onChange(of: difficultyLevel) { _, new in applyDifficulty(new) }

                            HStack {
                                Text("Step length")
                                Slider(value: Binding(
                                    get: { Double(stepLengthM) },
                                    set: { stepLengthM = Float($0) }),
                                    in: 0.4...0.8, step: 0.01)
                                Text(String(format: "%.2fm", stepLengthM))
                            }.frame(width: 260)
                        }

                        // Live stats (when active)
                        if isTestActive {
                            Text(String(format: "Time: %.1fs", testDuration)).monospacedDigit()

                            let progress = progressPercent()
                            ProgressView(value: progress).frame(width: 200)
                            Text("\(Int(progress*100))% complete").font(.caption)

                            // Drift meter
                            Text(String(format: "Drift: %.0f cm",
                                        Double(simd_length(headDriftXZ()))*100))
                                .font(.caption2)
                                .foregroundColor(.secondary)

                            // Tap-to-step (pinch == tap)
                            Button {
                                registerVirtualStep()
                            } label: {
                                Label("Step (Tap/Pinch)", systemImage: "shoeprints.fill")
                                    .frame(maxWidth: .infinity).padding(8)
                                    .background(Color.blue).foregroundColor(.white).cornerRadius(8)
                            }.frame(width: 220)

                            Button {
                                stopTest()
                            } label: {
                                Label("Stop", systemImage: "stop.fill")
                                    .frame(maxWidth: .infinity).padding(8)
                                    .background(Color.red).foregroundColor(.white).cornerRadius(8)
                            }.frame(width: 220)
                        } else {
                            Button {
                                startTest()
                            } label: {
                                Label("Start Test", systemImage: "figure.walk")
                                    .frame(maxWidth: .infinity).padding(10)
                                    .background(Color.green).foregroundColor(.white).cornerRadius(10)
                            }.frame(width: 260)
                        }

                        Text("Stand still; step/pinch to advance. Stay centered on the plank.")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    .padding().frame(width: 280)
                    .background(.regularMaterial).cornerRadius(16)
                } else { EmptyView() }
            }

            Attachment(id: "card") {
                if showResults, let r = results {
                    VStack(spacing: 12) {
                        Text(r.completed ? "✅ Test Completed!" : "Test Stopped")
                            .font(.title3).bold()
                        Grid(alignment: .leading, horizontalSpacing: 18) {
                            GridRow { Text("Duration:"); Text(String(format: "%.1fs", r.duration)) }
                            GridRow { Text("Difficulty:"); Text(r.difficulty) }
                            GridRow { Text("Steps:");     Text("\(r.stepCount)") }
                            GridRow { Text("Avg dev.:");  Text(String(format: "%.1f cm", r.averageDeviation*100))
                                    .foregroundColor(devColor(r.averageDeviation)) }
                            GridRow { Text("Max dev.:");  Text(String(format: "%.1f cm", r.maxDeviation*100))
                                    .foregroundColor(devColor(r.maxDeviation)) }
                            GridRow { Text("Near-edge:"); Text("\(r.nearMisses)") }
                            GridRow { Text("Looking down:"); Text(String(format: "%.0f%%", r.lookDownPct)) }
                        }.font(.system(size: 14))
                        Button("Close") {
                            showResults = false
                            resetTest()
                        }
                        .padding(8).background(Color.blue).foregroundColor(.white).cornerRadius(8)
                    }
                    .padding().frame(width: 360)
                    .background(.regularMaterial).cornerRadius(16)
                } else { EmptyView() }
            }
        }
        .onAppear { startHeadPose() }
        .onDisappear { stopHeadPose(); stopTest() }
        .onChange(of: showResults) { _, v in
            hudAnchor?.isEnabled = !v
            cardAnchor?.isEnabled = v
        }
    }

    // MARK: Environment
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

    // MARK: Start/stop
    private func startTest() {
        isTestActive = true
        hasStartedWalking = false
        hasCompletedWalk = false
        testStartTime = CACurrentMediaTime()
        testDuration = 0

        virtualForward = 0
        recenterOffset = .zero
        headRefW = headPosW

        path.removeAll(); totalDev = 0; maxDev = 0
        stepCount = 0; nearMisses = 0; isNearEdge = false
        lookDownTime = 0; lastTick = CACurrentMediaTime()
    }

    private func stopTest() {
        guard isTestActive else { return }
        isTestActive = false

        let avg = path.isEmpty ? 0 : totalDev / Float(path.count)
        results = TestResults(
            duration: testDuration,
            completed: hasCompletedWalk,
            averageDeviation: avg,
            maxDeviation: maxDev,
            stepCount: stepCount,
            nearMisses: nearMisses,
            lookDownPct: Float(lookDownTime / max(1, testDuration)) * 100,
            difficulty: difficultyLevel.rawValue
        )
        showResults = true
    }

    private func resetTest() {
        showResults = false
        results = nil
    }

    // MARK: Pose & locomotion
    private func startHeadPose() {
        headTask?.cancel()
        headTask = Task {
            do {
                try await arkitSession.requestAuthorization(for: [.worldSensing]) // plist key required
                try await arkitSession.run([worldTracking])

                var lastTime = CACurrentMediaTime()
                while !Task.isCancelled {
                    if let d = worldTracking.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()), d.isTracked {
                        let m = d.originFromAnchorTransform
                        let pos = SIMD3<Float>(m.columns.3.x, m.columns.3.y, m.columns.3.z)
                        let rot = simd_quatf(m)

                        // Track downward gaze very simply via pitch
                        let forward = simd_act(rot, SIMD3<Float>(0,0,-1))
                        let pitch = asin(-forward.y)
                        let now = CACurrentMediaTime()
                        let dt = now - lastTime
                        lastTime = now
                        if pitch < -0.35 { lookDownTime += dt }

                        await MainActor.run {
                            headPosW = pos
                            testTick(dt: dt)
                            if isTestActive { recenterForDriftIfNeeded() }
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

    // Called ~60 Hz on main
    private func testTick(dt: TimeInterval) {
        guard isTestActive else { return }
        testDuration = CACurrentMediaTime() - testStartTime

        // Start walking detection (moved 30cm in any direction) – just to change UI status
        if !hasStartedWalking, let ref = headRefW, simd_distance(headPosW, ref) > 0.3 {
            hasStartedWalking = true
        }

        // --- Step detection from head bobbing (Y axis) ---
        yHistory.append(headPosW.y)
        if yHistory.count > yHistoryLen { yHistory.removeFirst() }
        detectStepFromHeadBob()

        // --- Balance metrics vs plank center (X deviation) ---
        let devX = currentDeviationFromPlankCenterX()
        totalDev += abs(devX)
        maxDev = max(maxDev, abs(devX))
        let edgeThreshold = (plankWidth / 2) * 0.8
        let wasNear = isNearEdge
        isNearEdge = abs(devX) > edgeThreshold
        if isNearEdge && !wasNear { nearMisses += 1 }

        path.append(PathPoint(t: testDuration, devX: abs(devX)))

        // --- Completion: advance until we reach virtual distance ---
        if virtualForward >= (plankLength/2 + 0.5) + (plankLength/2 + 0.5) { // start->end distance
            hasCompletedWalk = true
            stopTest()
        }
    }

    // Simple peak detection on head Y to register a step
    private func detectStepFromHeadBob() {
        guard yHistory.count >= 5 else { return }
        let t = CACurrentMediaTime()
        // Look for local peak at y[-3] with neighbors lower by threshold
        let i = yHistory.count - 3
        let y0 = yHistory[i], yL = yHistory[i-2], yR = yHistory[i+2]
        if (y0 - yL) > bobThreshold && (y0 - yR) > bobThreshold {
            if (t - lastStepTime) > minStepInterval {
                lastStepTime = t
                registerVirtualStep()
            }
        }
    }

    private func registerVirtualStep() {
        // One virtual step forward (toward -Z), so move world +Z
        stepCount += 1
        virtualForward += stepLengthM
    }

    // Keep head near origin by shifting scene, without affecting virtual progress
    private func recenterForDriftIfNeeded() {
        guard let ref = headRefW, let env = environmentRoot else { return }
        let drift = headDriftXZ()
        let dist = simd_length(drift)
        guard dist > driftRadiusLimit else { return }
        let overshoot = dist - driftRadiusLimit
        let dir = drift / max(dist, 0.0001)
        let shift = -dir * overshoot
        env.position.x += shift.x
        env.position.z += shift.y
        recenterOffset.x += shift.x
        recenterOffset.z += shift.y
        // keep headRefW fixed (we want to hover around the original spot)
    }

    private func headDriftXZ() -> SIMD2<Float> {
        guard let ref = headRefW else { return .zero }
        return SIMD2<Float>(headPosW.x - ref.x, headPosW.z - ref.z)
    }

    // MARK: Helpers
    private func progressPercent() -> Double {
        // End-to-end span: start pad to end pad along the plank path
        let total = (plankLength/2 + 0.5) * 2
        return min(1.0, Double(max(0, virtualForward / total)))
    }

    private func currentDeviationFromPlankCenterX() -> Float {
        guard let plank = plankEntity else { return 0 }
        let m = plank.transformMatrix(relativeTo: nil)
        let plankX = m.columns.3.x
        return headPosW.x - plankX
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

    private func devColor(_ d: Float) -> Color {
        if d < 0.05 { return .green }
        if d < 0.10 { return .orange }
        return .red
    }
}