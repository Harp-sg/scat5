import SwiftUI
import RealityKit
import ARKit
import simd
import Observation

struct SmoothPursuitScene: View {
    @Environment(ViewRouter.self) private var viewRouter
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openWindow) private var openWindow

    @State private var hud = HUDState()
    @State private var config = PursuitConfig()
    @StateObject private var controller = SmoothPursuitController()

    var body: some View {
        PursuitRealityView(config: config, controller: controller, hud: $hud)
        .task {
            await runTestSequence()
        }
        .animation(.easeInOut, value: hud.headHintVisible)
        .animation(.easeInOut, value: hud.phase)
    }

    private func runTestSequence() async {
        for i in (1...3).reversed() {
            hud.phase = .countdown(i)
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
        hud.phase = .running

        await controller.runProtocol(config: config)

        hud.phase = .results(controller.metrics.summary)
    }
}

// MARK: - Subviews

private struct PursuitRealityView: View {
    let config: PursuitConfig
    @ObservedObject var controller: SmoothPursuitController
    @Binding var hud: HUDState
    
    // Add these for button actions
    @Environment(ViewRouter.self) private var viewRouter
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openWindow) private var openWindow

    @FocusState private var orbFocused: Bool

    var body: some View {
        RealityView { content, attachments in
            setupRealityScene(content: content, attachments: attachments)
        } attachments: {
            // Focus probe - make it a Circle with proper opacity and contentShape
            Attachment(id: "focusProbe") {
                Circle()
                    .fill(orbFocused ? Color.green.opacity(0.35) : Color.white.opacity(0.001)) // keep a 0.1% alpha body
                    .overlay(
                        Circle().stroke(orbFocused ? .green : .clear, lineWidth: 2)
                    )
                    .frame(width: 60, height: 60)
                    .contentShape(Circle())
                    .focusable()                     // visionOS 2 syntax
                    .focused($orbFocused)
            }
            
            // Instructions HUD – show only, never focus
            Attachment(id: "instructionsHUD") {
                if case .running = hud.phase {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Keep your head still and track the ball")
                            .font(.headline)
                            .foregroundColor(.white)

                        HeadLevelIndicator(controller: controller)

                        HStack(spacing: 16) {
                            StatChip(title: "Focus", value: "\(Int(controller.metrics.currentFocusRatio * 100))%",
                                     color: controller.metrics.currentFocusRatio > 0.8 ? .green : .red)
                            StatChip(title: "Breaks", value: "\(controller.metrics.currentBreaks)",
                                     color: controller.metrics.currentBreaks < 3 ? .green : .orange)
                        }
                    }
                    .padding(12)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .focusEffectDisabled(true)
                    .allowsHitTesting(false)
                } else {
                    Color.clear.frame(width: 1, height: 1)
                }
            }
            
            // Countdown – never focus
            Attachment(id: "countdown") {
                if let n = hud.countdownNumber {
                    VStack(spacing: 16) {
                        Text("Get Ready")
                            .font(.title)
                            .foregroundColor(.white)
                        Text("Starting in \(n)…")
                            .font(.largeTitle)
                            .foregroundColor(.yellow)
                        Text("Keep your head still and follow the yellow ball with your eyes only")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(20)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .focusEffectDisabled(true)
                    .allowsHitTesting(false)
                } else {
                    Color.clear.frame(width: 1, height: 1)
                }
            }
            
            // Progress Bar
            Attachment(id: "progress") {
                if case .running = hud.phase {
                    TestProgressBar(controller: controller)
                        .focusEffectDisabled(true)
                        .allowsHitTesting(false)
                } else {
                    Color.clear.frame(width: 1, height: 1)
                }
            }
            
            // Results – focus only AFTER run
            Attachment(id: "results") {
                if let s = hud.resultsSummary {
                    ResultsPanel(summary: s) {
                        Task {
                            await viewRouter.closeImmersiveSpace(
                                dismissImmersiveSpace: { await dismissImmersiveSpace() },
                                openMainWindow: { openWindow(id: "MainWindow") }
                            )
                        }
                    }
                    .focusEffectDisabled(false)        // allow focus now
                } else {
                    Color.clear.frame(width: 1, height: 1)
                }
            }
            
            // Exit – hide or disable during run
            Attachment(id: "exitButton") {
                if hud.isRunning {
                    Color.clear.frame(width: 1, height: 1)
                        .focusEffectDisabled(true)
                        .allowsHitTesting(false)
                } else {
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
                            .padding(10)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .focusable(true) // only when NOT running
                }
            }
        }
        .onChange(of: orbFocused) { _, newValue in
            controller.metrics.tickFocus(isFocused: newValue)
            Task { @MainActor in controller.setOrbFocused(newValue) }
            print("🎯 GAZE:", newValue ? "FOCUSED" : "LOST FOCUS")
        }
    }

    private func setupRealityScene(content: RealityViewContent, attachments: RealityViewAttachments) {
        // Create head-anchored coordinate system for eye-level positioning
        let headAnchor = AnchorEntity(.head)
        headAnchor.anchoring.trackingMode = .once // Fixed position when test starts
        content.add(headAnchor)
        
        let root = Entity()
        root.position = [0, 0, 0]  // Changed: lowered from [0, 1.5, 0] to eye level

        let orb = ModelEntity(
            mesh: .generateSphere(radius: 0.015),
            materials: [SimpleMaterial(color: .yellow, isMetallic: false)]
        )
        orb.name = "smooth_pursuit_orb"

        // Make orb interactive
        orb.components.set(InputTargetComponent())
        orb.components.set(CollisionComponent(shapes: [.generateSphere(radius: 0.02)]))
        orb.components[HoverEffectComponent.self] = HoverEffectComponent()

        let z: Float = -config.zDistance
        let A: Float = config.zDistance * tanf(config.sweepDegrees * Float.pi / 180)
        orb.transform.translation = SIMD3(-A, 0, z)

        root.addChild(orb)
        headAnchor.addChild(root) // Changed: attach to head anchor instead of content

        // Attach focus probe to orb - proper scaling and positioning
        if let probe = attachments.entity(for: "focusProbe") {
            probe.components.set(BillboardComponent())
            probe.transform.scale = [0.06, 0.06, 0.06] // ≈6 cm
            probe.position = [0, 0, 0.01]              // pull 1 cm toward user
            orb.addChild(probe)
            print("✅ Focus probe attached to orb")
        } else {
            print("❌ Failed to get focus probe attachment")
        }
        
        // Position HUD elements relative to head anchor with consistent depth
        let depth: Float = -config.zDistance + 0.3 // Closer than the orb
        
        if let instructions = attachments.entity(for: "instructionsHUD") {
            instructions.components.set(BillboardComponent()) // Always face user
            instructions.position = [-0.6, 0.4, depth]
            headAnchor.addChild(instructions) // Changed: attach to head anchor
            print("✅ Instructions HUD positioned")
        }
        
        if let countdown = attachments.entity(for: "countdown") {
            countdown.components.set(BillboardComponent())
            countdown.position = [0, 0.2, depth]
            headAnchor.addChild(countdown) // Changed: attach to head anchor
            print("✅ Countdown positioned")
        }
        
        if let progress = attachments.entity(for: "progress") {
            progress.components.set(BillboardComponent())
            progress.position = [0, -0.2, depth]
            headAnchor.addChild(progress) // Changed: attach to head anchor
            print("✅ Progress bar positioned")
        }
        
        if let results = attachments.entity(for: "results") {
            results.components.set(BillboardComponent())
            results.position = [0, 0, depth]
            headAnchor.addChild(results) // Changed: attach to head anchor
            print("✅ Results panel positioned")
        }
        
        if let exitBtn = attachments.entity(for: "exitButton") {
            exitBtn.components.set(BillboardComponent())
            exitBtn.position = [0.6, 0.4, depth]
            headAnchor.addChild(exitBtn) // Changed: attach to head anchor
            print("✅ Exit button positioned")
        }

        controller.install(orb: orb, parent: root)

        controller.startHeadTracking(config: config) { axis, still, event in
            controller.metrics.tickHead(still: still, event: event, axis: axis)
            hud.headHintVisible = !still
        }
    }
}

// MARK: - Controller and Metrics

@MainActor
final class SmoothPursuitController: ObservableObject {
    private(set) weak var orb: ModelEntity?
    private(set) weak var parent: Entity?

    private var session: ARKitSession?
    private var worldTracking: WorldTrackingProvider?
    
    @Published var shouldPause = false
    @Published var currentProgress: Double = 0.0
    @Published var testPhase: String = ""

    var metrics = Metrics()

    func install(orb: ModelEntity, parent: Entity) {
        self.orb = orb
        self.parent = parent
    }
    
    func setOrbFocused(_ focused: Bool) {
        guard let orb = orb else { return }
        let mat = SimpleMaterial(color: focused ? .green : .yellow, isMetallic: false)
        orb.model?.materials = [mat]
    }

    deinit {
        // Clean up
    }

    func startHeadTracking(config: PursuitConfig, onUpdate: @escaping (_ axis: SegmentKind?, _ still: Bool, _ event: Bool) -> Void) {
        let session = ARKitSession()
        let world = WorldTrackingProvider()
        self.session = session
        self.worldTracking = world

        Task {
            do {
                try await session.run([world])
                var initialRotation: simd_quatf?

                for await update in world.anchorUpdates {
                    guard let device = update.anchor as? DeviceAnchor else { continue }
                    let q = simd_quatf(device.originFromAnchorTransform)

                    if initialRotation == nil { initialRotation = q }

                    if let start = initialRotation {
                        let deltas = headDeltas(from: start, to: q)
                        let currentAxis = metrics.current

                        let relevantDelta: Double
                        if currentAxis == .horizontal {
                            relevantDelta = abs(deltas.yaw)
                        } else if currentAxis == .vertical {
                            relevantDelta = abs(deltas.pitch)
                        } else {
                            relevantDelta = max(abs(deltas.yaw), abs(deltas.pitch))
                        }

                        let still = (relevantDelta <= config.headWarnDeg)
                        let event = (relevantDelta >= config.headEventDeg)
                        
                        let wasPaused = self.shouldPause
                        Task { @MainActor in
                            self.shouldPause = !still // Pause when head moves too much
                            if wasPaused && still {
                                // Add a small delay after head becomes still to prevent jarring movement
                                try? await Task.sleep(nanoseconds: 150_000_000)
                            }
                        }
                        
                        onUpdate(currentAxis, still, event)
                    }
                }
            } catch {
                print("Head tracking failed: \(error)")
            }
        }
    }

    private func headDeltas(from start: simd_quatf, to current: simd_quatf) -> (yaw: Double, pitch: Double, roll: Double) {
        let dq = current * start.inverse
        let m = simd_matrix4x4(dq)
        let sy = sqrt(m.columns.0.x * m.columns.0.x + m.columns.1.x * m.columns.1.x)
        let yaw   = atan2(m.columns.1.x, m.columns.0.x)
        let pitch = atan2(-m.columns.2.x, sy)
        let roll  = atan2(m.columns.2.y, m.columns.2.z)
        return (Double(yaw * 180 / .pi), Double(pitch * 180 / .pi), Double(roll * 180 / .pi))
    }

    func runProtocol(config: PursuitConfig) async {
        guard let orb, let parent else { return }

        let A: Float = config.zDistance * tanf(config.sweepDegrees * Float.pi / 180)
        let z: Float = -config.zDistance

        let left  = SIMD3<Float>(-A, 0, z)
        let right = SIMD3<Float>( A, 0, z)
        let up    = SIMD3<Float>(0,  A, z)
        let down  = SIMD3<Float>(0, -A, z)
        let near  = SIMD3<Float>(0, 0, -config.nearDepth)   // Added near position
        let far   = SIMD3<Float>(0, 0, -config.farDepth)    // Added far position

        let sweepDeg: Float = config.sweepDegrees * 2
        let durationPerSweep = Double(sweepDeg / config.degPerSec)
        
        let totalDuration = durationPerSweep * 6 + 0.8 // 6 movements + pauses

        // Horizontal phase
        testPhase = "Horizontal Tracking"
        metrics.begin(.horizontal)
        await moveOrbWithProgress(to: right, duration: durationPerSweep, totalDuration: totalDuration, startProgress: 0.0)
        await moveOrbWithProgress(to: left, duration: durationPerSweep, totalDuration: totalDuration, startProgress: 1.0/6.0)
        metrics.endSegment()

        try? await Task.sleep(nanoseconds: 400_000_000)
        currentProgress = 2.0/6.0

        // Vertical phase
        testPhase = "Vertical Tracking"
        metrics.begin(.vertical)
        await moveOrbWithProgress(to: down, duration: durationPerSweep, totalDuration: totalDuration, startProgress: 2.0/6.0)
        await moveOrbWithProgress(to: up, duration: durationPerSweep, totalDuration: totalDuration, startProgress: 3.0/6.0)
        metrics.endSegment()

        try? await Task.sleep(nanoseconds: 400_000_000)
        currentProgress = 4.0/6.0

        // Depth phase - NEW!
        testPhase = "Depth Tracking"
        metrics.begin(.depth)
        await moveOrbWithProgress(to: near, duration: durationPerSweep, totalDuration: totalDuration, startProgress: 4.0/6.0)
        await moveOrbWithProgress(to: far, duration: durationPerSweep, totalDuration: totalDuration, startProgress: 5.0/6.0)
        metrics.endSegment()

        currentProgress = 1.0
        testPhase = "Complete"
    }

    private func moveOrbWithProgress(to: SIMD3<Float>, duration: Double, totalDuration: Double, startProgress: Double) async {
        guard let orb, let parent else { return }

        let steps = max(1, Int(duration * 90)) // ~90 Hz
        let stepNS = UInt64((duration / Double(steps)) * 1_000_000_000)

        let startPos = orb.transform.translation
        let progressChunk = 0.25 / Double(steps)

        for i in 0...steps {
            while shouldPause {
                try? await Task.sleep(nanoseconds: 50_000_000)
            }

            let t = Float(i) / Float(steps)
            let newPos = simd_mix(startPos, to, SIMD3<Float>(repeating: t))
            orb.transform.translation = newPos

            await MainActor.run {
                currentProgress = min(1, startProgress + progressChunk * Double(i))
            }
            try? await Task.sleep(nanoseconds: stepNS)
        }
    }
}

struct PursuitConfig {
    var zDistance: Float = 1.0  // Changed: closer depth (was 1.5)
    var sweepDegrees: Float = 15
    var degPerSec: Float = 10
    var headWarnDeg: Double = 5
    var headEventDeg: Double = 8
    
    // New: depth motion parameters
    var nearDepth: Float = 0.6   // How close the ball comes
    var farDepth: Float = 1.8    // How far the ball goes
}

enum SegmentKind { 
    case horizontal, vertical, depth  // Added depth tracking
    
    var description: String {
        switch self {
        case .horizontal: return "Horizontal"
        case .vertical: return "Vertical"
        case .depth: return "Depth"
        }
    }
}

struct MetricsSummary: Equatable {
    let hDuration: Double
    let hFocusRatio: Double
    let hBreaks: Int
    let vDuration: Double
    let vFocusRatio: Double
    let vBreaks: Int
    let dDuration: Double        // Added depth metrics
    let dFocusRatio: Double
    let dBreaks: Int
    let headStillPercent: Double
    let headMotionEvents: Int
    var hValid: Bool { (hFocusRatio >= 0.8) && (headStillPercent >= 0.8) }
    var vValid: Bool { (vFocusRatio >= 0.8) && (headStillPercent >= 0.8) }
    var dValid: Bool { (dFocusRatio >= 0.8) && (headStillPercent >= 0.8) }  // Added depth validation
}

@MainActor
final class Metrics {
    struct Segment {
        var duration: Double = 0
        var focusSeconds: Double = 0
        var focusedNow: Bool = false
        var lastChangeTime: Double = CACurrentMediaTime()
        var breaks: Int = 0
        var ratio: Double { duration > 0 ? focusSeconds / duration : 0 }
    }

    var h = Segment()
    var v = Segment()
    var d = Segment()  // Added depth segment
    var current: SegmentKind?

    private(set) var headTotal: Double = 0
    private(set) var headStill: Double = 0
    private(set) var headEvents: Int = 0
    private var lastTickTime: Double = CACurrentMediaTime()

    // MARK: - Live Debug Properties
    var currentFocusRatio: Double {
        switch current {
        case .horizontal?: return h.ratio
        case .vertical?: return v.ratio
        case .depth?: return d.ratio  // Added depth case
        case .none: return 0
        }
    }
    
    var currentBreaks: Int {
        switch current {
        case .horizontal?: return h.breaks
        case .vertical?: return v.breaks
        case .depth?: return d.breaks  // Added depth case
        case .none: return 0
        }
    }
    
    var headStillPercent: Double {
        headTotal > 0 ? headStill / headTotal : 1.0
    }
    
    var headMotionEvents: Int {
        headEvents
    }

    func begin(_ segment: SegmentKind) {
        current = segment
        let now = CACurrentMediaTime()
        print("📊 Starting \(segment) segment")
        switch segment {
        case .horizontal:
            h.lastChangeTime = now
            h.focusedNow = false
        case .vertical:
            v.lastChangeTime = now
            v.focusedNow = false
        case .depth:  // Added depth case
            d.lastChangeTime = now
            d.focusedNow = false
        }
    }

    func endSegment() {
        let now = CACurrentMediaTime()
        switch current {
        case .horizontal?:
            let dt = now - h.lastChangeTime
            if h.focusedNow { h.focusSeconds += dt }
            h.duration += dt
            print("📊 Horizontal complete: \(Int(h.ratio * 100))% focus, \(h.breaks) breaks")
        case .vertical?:
            let dt = now - v.lastChangeTime
            if v.focusedNow { v.focusSeconds += dt }
            v.duration += dt
            print("📊 Vertical complete: \(Int(v.ratio * 100))% focus, \(v.breaks) breaks")
        case .depth?:  // Added depth case
            let dt = now - d.lastChangeTime
            if d.focusedNow { d.focusSeconds += dt }
            d.duration += dt
            print("📊 Depth complete: \(Int(d.ratio * 100))% focus, \(d.breaks) breaks")
        default:
            break
        }
        current = nil
    }

    func tickFocus(isFocused: Bool) {
        let now = CACurrentMediaTime()
        switch current {
        case .horizontal?:
            if h.focusedNow != isFocused {
                let dt = now - h.lastChangeTime
                if h.focusedNow { h.focusSeconds += dt }
                if h.focusedNow && !isFocused { 
                    h.breaks += 1
                    print("💔 Horizontal focus break #\(h.breaks)")
                }
                h.focusedNow = isFocused
                h.lastChangeTime = now
            }
        case .vertical?:
            if v.focusedNow != isFocused {
                let dt = now - v.lastChangeTime
                if v.focusedNow { v.focusSeconds += dt }
                if v.focusedNow && !isFocused { 
                    v.breaks += 1
                    print("💔 Vertical focus break #\(v.breaks)")
                }
                v.focusedNow = isFocused
                v.lastChangeTime = now
            }
        case .depth?:  // Added depth case
            if d.focusedNow != isFocused {
                let dt = now - d.lastChangeTime
                if d.focusedNow { d.focusSeconds += dt }
                if d.focusedNow && !isFocused { 
                    d.breaks += 1
                    print("💔 Depth focus break #\(d.breaks)")
                }
                d.focusedNow = isFocused
                d.lastChangeTime = now
            }
        default:
            break
        }
    }

    func tickHead(still: Bool, event: Bool, axis: SegmentKind?) {
        let now = CACurrentMediaTime()
        let dt = now - lastTickTime
        lastTickTime = now

        headTotal += dt
        if still { headStill += dt }
        if event { 
            headEvents += 1
            print("⚠️ Head motion event #\(headEvents) during \(axis?.description ?? "unknown") segment")
        }
    }

    var summary: MetricsSummary {
        let result = MetricsSummary(
            hDuration: h.duration,
            hFocusRatio: h.ratio,
            hBreaks: h.breaks,
            vDuration: v.duration,
            vFocusRatio: v.ratio,
            vBreaks: v.breaks,
            dDuration: d.duration,       // Added depth metrics
            dFocusRatio: d.ratio,
            dBreaks: d.breaks,
            headStillPercent: headStillPercent,
            headMotionEvents: headEvents
        )
        print("📋 Final Results: H=\(Int(result.hFocusRatio*100))%, V=\(Int(result.vFocusRatio*100))%, D=\(Int(result.dFocusRatio*100))%, Head=\(Int(result.headStillPercent*100))%")
        return result
    }
}

// MARK: - HUD / Results

@Observable
final class HUDState {
    enum Phase: Equatable {
        case idle
        case countdown(Int)
        case running
        case results(MetricsSummary)
    }
    var phase: Phase = .idle {
        didSet {
            // Disable focus on the overlay only when the test is running
            if case .running = phase {
                // This state can be used to drive .focusDisabled
            }
        }
    }
    var headHintVisible: Bool = false

    var isRunningAndHeadMoving: Bool {
        if case .running = phase {
            return headHintVisible
        }
        return false
    }

    var countdownNumber: Int? {
        if case .countdown(let n) = phase { return n }
        return nil
    }

    var resultsSummary: MetricsSummary? {
        if case .results(let s) = phase { return s }
        return nil
    }

    var isRunning: Bool {
        if case .running = phase { return true }
        return false
    }
}

struct ResultsPanel: View {
    let summary: MetricsSummary
    let onClose: () -> Void
    
    private var overallScore: Int {
        let hScore = Int(summary.hFocusRatio * 100)
        let vScore = Int(summary.vFocusRatio * 100)
        let dScore = Int(summary.dFocusRatio * 100)  // Added depth score
        let headScore = Int(summary.headStillPercent * 100)
        
        // Penalize for breaks and head motion
        let breakPenalty = (summary.hBreaks + summary.vBreaks + summary.dBreaks) * 5  // Include depth breaks
        let headPenalty = summary.headMotionEvents * 10
        
        let rawScore = (hScore + vScore + dScore + headScore) / 4  // Changed from /3 to /4
        return max(0, rawScore - breakPenalty - headPenalty)
    }
    
    private var scoreColor: Color {
        switch overallScore {
        case 90...100: return .green
        case 70...89: return .yellow
        default: return .red
        }
    }
    
    private var interpretation: String {
        switch overallScore {
        case 90...100: return "Excellent smooth pursuit"
        case 80...89: return "Good smooth pursuit"
        case 70...79: return "Fair smooth pursuit"
        case 60...69: return "Poor smooth pursuit"
        default: return "Abnormal - Consider medical evaluation"
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Smooth Pursuit Results")
                .font(.title2.weight(.bold))

            // Overall Score
            VStack(spacing: 8) {
                Text("\(overallScore)")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(scoreColor)
                
                Text(interpretation)
                    .font(.headline)
                    .foregroundColor(scoreColor)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(scoreColor.opacity(0.1))
            .cornerRadius(12)

            // Detailed metrics
            VStack(spacing: 12) {
                HStack(spacing: 24) {
                    metric("Horizontal Focus", "\(Int(summary.hFocusRatio * 100))%", 
                           summary.hValid ? .green : .red)
                    metric("H Breaks", "\(summary.hBreaks)", 
                           summary.hBreaks <= 2 ? .green : .orange)
                }
                
                HStack(spacing: 24) {
                    metric("Vertical Focus", "\(Int(summary.vFocusRatio * 100))%", 
                           summary.vValid ? .green : .red)
                    metric("V Breaks", "\(summary.vBreaks)", 
                           summary.vBreaks <= 2 ? .green : .orange)
                }

                HStack(spacing: 24) {
                    metric("Depth Focus", "\(Int(summary.dFocusRatio * 100))%", 
                           summary.dValid ? .green : .red)
                    metric("D Breaks", "\(summary.dBreaks)", 
                           summary.dBreaks <= 2 ? .green : .orange)
                }

                HStack(spacing: 24) {
                    metric("Head Stillness", "\(Int(summary.headStillPercent * 100))%", 
                           summary.headStillPercent >= 0.8 ? .green : .red)
                    metric("Head Events", "\(summary.headMotionEvents)", 
                           summary.headMotionEvents <= 1 ? .green : .red)
                }
            }

            Button("Complete Test") { onClose() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(scoreColor, lineWidth: 2)
        )
    }

    private func metric(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 100)
    }
}

// MARK: - UI Components

struct HeadLevelIndicator: View {
    @ObservedObject var controller: SmoothPursuitController
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "gyroscope")
                .foregroundColor(controller.shouldPause ? .red : .green)
            
            Text("Head Level")
                .font(.caption)
            
            // Simple level indicator
            RoundedRectangle(cornerRadius: 4)
                .fill(controller.shouldPause ? Color.red : Color.green)
                .frame(width: 60, height: 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.white, lineWidth: 1)
                )
            
            if controller.shouldPause {
                Text("KEEP HEAD STILL")
                    .font(.caption2)
                    .foregroundColor(.red)
                    .fontWeight(.bold)
            }
        }
        .padding(8)
        .background(controller.shouldPause ? Color.red.opacity(0.2) : Color.green.opacity(0.2))
        .cornerRadius(8)
    }
}

struct StatChip: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(color)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(6)
    }
}

struct TestProgressBar: View {
    @ObservedObject var controller: SmoothPursuitController
    
    var body: some View {
        VStack(spacing: 8) {
            Text(controller.testPhase)
                .font(.headline)
                .foregroundColor(.white)
            
            ProgressView(value: controller.currentProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                .frame(width: 300, height: 8)
                .background(Color.gray.opacity(0.3))
                .cornerRadius(4)
            
            Text("\(Int(controller.currentProgress * 100))% Complete")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}