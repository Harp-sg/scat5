import SwiftUI
import SwiftData
import RealityKit
import ARKit
import simd
import Observation

struct SaccadesTestView: View {
    @Environment(ViewRouter.self) private var viewRouter
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openWindow) private var openWindow
    @Environment(\.modelContext) private var modelContext
    
    @State private var controller = SaccadesController()
    @State private var showInstructions = true
    @State private var showResults = false
    @State private var testResults: SaccadesTestResults?
    
    var body: some View {
        RealityView { content, attachments in
            setupScene(content: content, attachments: attachments)
        } update: { content, attachments in
            updateScene(content: content, attachments: attachments)
        } attachments: {
            // Instructions overlay - only UI element as attachment
            Attachment(id: "instructions") {
                if showInstructions {
                    SaccadesInstructionsView {
                        showInstructions = false
                        controller.startTest()
                    }
                } else {
                    Color.clear.frame(width: 1, height: 1)
                }
            }
            
            // HUD overlay - floating in 3D space
            Attachment(id: "hud") {
                if !showInstructions && !showResults {
                    TestHUDView(controller: controller)
                } else {
                    Color.clear.frame(width: 1, height: 1)
                }
            }
            
            // Results view
            Attachment(id: "results") {
                if let results = testResults, showResults {
                    SaccadesResultsView(results: results) {
                        Task {
                            await viewRouter.closeImmersiveSpace(
                                dismissImmersiveSpace: { await dismissImmersiveSpace() },
                                openMainWindow: { openWindow(id: "MainWindow") }
                            )
                        }
                    }
                } else {
                    Color.clear.frame(width: 1, height: 1)
                }
            }
            
            // Exit button
            Attachment(id: "exit") {
                if !controller.isRunning {
                    Button {
                        Task {
                            await viewRouter.closeImmersiveSpace(
                                dismissImmersiveSpace: { await dismissImmersiveSpace() },
                                openMainWindow: { openWindow(id: "MainWindow") }
                            )
                        }
                    } label: {
                        Label("Exit", systemImage: "xmark.circle.fill")
                            .font(.title3)
                            .padding(12)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                } else {
                    Color.clear.frame(width: 1, height: 1)
                }
            }
        }
        .gesture(
            SpatialTapGesture(coordinateSpace: .local)
                .targetedToAnyEntity()
                .onEnded { value in
                    // Handle interaction with 3D targets
                    controller.handleTargetInteraction(entity: value.entity)
                }
        )
        .onAppear {
            controller.onTestComplete = { results in
                testResults = results
                saveResults(results)
                showResults = true
            }
        }
    }
    
    private func setupScene(content: RealityViewContent, attachments: RealityViewAttachments) {
        // Create head-anchored coordinate system for eye-level positioning
        let headAnchor = AnchorEntity(.head)
        headAnchor.anchoring.trackingMode = .once // Fixed position when test starts
        content.add(headAnchor)
        
        // Setup controller with content references
        controller.setupRealityContent(content: content, headAnchor: headAnchor)
        
        // Position only UI attachments - 3D targets are created as RealityKit entities
        let config = SaccadesConfig()
        let depth: Float = -config.targetDepthM
        
        if let instructions = attachments.entity(for: "instructions") {
            instructions.position = SIMD3<Float>(0, 0.2, depth)
            instructions.components.set(BillboardComponent())
            headAnchor.addChild(instructions)
        }
        
        if let hud = attachments.entity(for: "hud") {
            hud.position = SIMD3<Float>(-0.8, 0.4, depth + 0.3)
            hud.components.set(BillboardComponent())
            headAnchor.addChild(hud)
        }
        
        if let results = attachments.entity(for: "results") {
            results.position = SIMD3<Float>(0, 0, depth)
            results.components.set(BillboardComponent())
            headAnchor.addChild(results)
        }
        
        if let exit = attachments.entity(for: "exit") {
            exit.position = SIMD3<Float>(0.8, 0.4, depth + 0.3)
            exit.components.set(BillboardComponent())
            headAnchor.addChild(exit)
        }
    }
    
    private func updateScene(content: RealityViewContent, attachments: RealityViewAttachments) {
        // Updates handled by controller
        controller.updateVisualStates()
    }
    
    private func saveResults(_ results: SaccadesTestResults) {
        let saccadesResult = SaccadesResult()
        saccadesResult.updateFromTestResults(results)
        
        modelContext.insert(saccadesResult)
        
        do {
            try modelContext.save()
            print("✅ Saccades test results saved successfully")
        } catch {
            print("❌ Failed to save saccades test results: \(error)")
        }
    }
}

// MARK: - Controller

@MainActor
@Observable
final class SaccadesController {
    // Test state
    var isRunning = false
    var currentPhase: TestPhase = .waitingToStart
    var currentCue: SaccadeDirection?
    var showFixation = true
    var progress: Double = 0.0
    
    // Head tracking with proper initialization
    var currentHeadYaw: Double = 0
    var currentHeadPitch: Double = 0
    var headMotionExceeded = false
    var isHeadTrackingActive = false
    
    // Gaze feedback - much more prominent
    var lastGazedTarget: SaccadeDirection?
    var gazeConfidence: Double = 0.0
    var currentlyFocusedTarget: SaccadeDirection?
    
    // Visual feedback for user
    var gazeIndicatorText = "3D Volumetric Saccades Test - Look at 3D targets in space!"
    var headMotionWarning = ""
    
    // 3D RealityKit entities
    private var realityContent: RealityViewContent?
    private var headAnchor: AnchorEntity?
    private var targetEntities: [SaccadeDirection: ModelEntity] = [:]
    private var fixationEntity: ModelEntity?
    private var targetGlowEntities: [SaccadeDirection: ModelEntity] = [:]
    
    // Data collection
    private var trials: [SaccadeTrial] = []
    private var pendingTrials: [SaccadeDirection] = []
    private var currentTrialIndex = 0
    private var cueStartTime: TimeInterval = 0
    private var testStartTime = Date()
    private var baselineHeadTransform: simd_float4x4?
    
    // ARKit session for head tracking
    private var session: ARKitSession?
    private var worldTracking: WorldTrackingProvider?
    private var headTrackingTask: Task<Void, Never>?
    
    // Callback
    var onTestComplete: ((SaccadesTestResults) -> Void)?
    
    enum TestPhase {
        case waitingToStart
        case horizontalPhase
        case verticalPhase
        case completed
    }
    
    func setupRealityContent(content: RealityViewContent, headAnchor: AnchorEntity) {
        self.realityContent = content
        self.headAnchor = headAnchor
        
        // Create 3D target entities
        create3DTargetEntities()
        
        // Start head tracking immediately
        startHeadTracking()
    }
    
    private func create3DTargetEntities() {
        guard let headAnchor = headAnchor else { return }
        
        let config = SaccadesConfig()
        let depth: Float = -config.targetDepthM
        
        // Create 3D volumetric targets positioned in 3D space
        let targetPositions: [(SaccadeDirection, SIMD3<Float>)] = [
            (.left, SIMD3<Float>(-config.horizontalOffsetM, 0, depth)),
            (.right, SIMD3<Float>(config.horizontalOffsetM, 0, depth)),
            (.up, SIMD3<Float>(0, config.verticalOffsetM, depth)),
            (.down, SIMD3<Float>(0, -config.verticalOffsetM, depth))
        ]
        
        for (direction, position) in targetPositions {
            let (targetEntity, glowEntity) = create3DTargetEntity(for: direction, at: position)
            targetEntities[direction] = targetEntity
            targetGlowEntities[direction] = glowEntity
            
            // Add both target and glow to scene
            headAnchor.addChild(targetEntity)
            headAnchor.addChild(glowEntity)
        }
        
        // Create 3D fixation sphere
        let fixationEntity = create3DFixationEntity(at: SIMD3<Float>(0, 0, depth))
        self.fixationEntity = fixationEntity
        headAnchor.addChild(fixationEntity)
        
        print("✅ Created \(targetEntities.count) 3D target entities and fixation sphere")
    }
    
    private func create3DTargetEntity(for direction: SaccadeDirection, at position: SIMD3<Float>) -> (ModelEntity, ModelEntity) {
        // Main 3D target sphere - much smaller and more precise
        let targetRadius: Float = 0.025 // 5cm diameter (was 10cm)
        let targetEntity = ModelEntity(
            mesh: .generateSphere(radius: targetRadius),
            materials: [create3DMaterial(for: direction, isActive: false)]
        )
        
        targetEntity.name = "\(direction.rawValue)Target"
        targetEntity.position = position
        
        // Essential for interaction - enable gaze and spatial tap
        targetEntity.components.set(InputTargetComponent(allowedInputTypes: .indirect))
        targetEntity.generateCollisionShapes(recursive: false)
        
        // Add 3D glow sphere that surrounds the target - also smaller
        let glowRadius: Float = 0.035 // Smaller glow sphere (was 0.08)
        let glowEntity = ModelEntity(
            mesh: .generateSphere(radius: glowRadius),
            materials: [createGlowMaterial(for: direction)]
        )
        
        glowEntity.name = "\(direction.rawValue)Glow"
        glowEntity.position = position
        glowEntity.isEnabled = false // Initially hidden
        
        print("📍 Created small 3D target entity for \(direction.displayName) at position \(position)")
        
        return (targetEntity, glowEntity)
    }
    
    private func create3DFixationEntity(at position: SIMD3<Float>) -> ModelEntity {
        let entity = ModelEntity(
            mesh: .generateSphere(radius: 0.015), // Smaller fixation sphere (was 0.02)
            materials: [SimpleMaterial(color: .white, roughness: 0.1, isMetallic: false)]
        )
        
        entity.name = "fixation"
        entity.position = position
        
        // Add subtle pulsing animation
        let pulseAnimation = FromToByAnimation<Transform>(
            name: "pulse",
            from: .init(scale: SIMD3<Float>(1.0, 1.0, 1.0)),
            to: .init(scale: SIMD3<Float>(1.2, 1.2, 1.2)),
            duration: 1.0,
            timing: .easeInOut,
            isAdditive: false
        )
        
        let pulseResource = try? AnimationResource.generate(with: pulseAnimation)
        if let pulseResource = pulseResource {
            entity.playAnimation(pulseResource.repeat())
        }
        
        return entity
    }
    
    private func create3DMaterial(for direction: SaccadeDirection, isActive: Bool) -> SimpleMaterial {
        let baseColor = getTargetColor(direction)
        let opacity: CGFloat = isActive ? 0.9 : 0.4
        
        let material = SimpleMaterial(color: baseColor.withAlphaComponent(opacity), roughness: 0.2, isMetallic: false)
        
        return material
    }
    
    private func createGlowMaterial(for direction: SaccadeDirection) -> SimpleMaterial {
        let glowColor = getTargetColor(direction)
        let material = SimpleMaterial(color: glowColor.withAlphaComponent(0.2), roughness: 0.0, isMetallic: false)
        return material
    }
    
    private func getTargetColor(_ direction: SaccadeDirection) -> UIColor {
        switch direction {
        case .left: return .systemGreen
        case .right: return .systemBlue
        case .up: return .systemOrange
        case .down: return .systemPurple
        }
    }
    
    func startTest() {
        isRunning = true
        currentPhase = .horizontalPhase
        pendingTrials = generateTrialSequence(directions: [.left, .right], count: 8)
        testStartTime = Date()
        gazeIndicatorText = "3D Test Starting - Look at volumetric targets in 3D space!"
        
        updateVisualStates()
        
        Task {
            await runTestSequence()
        }
    }
    
    private func runTestSequence() async {
        // Run horizontal trials
        gazeIndicatorText = "3D Horizontal Saccades - Look left and right at 3D spheres"
        await runTrials()
        
        // Brief pause between phases
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        // Run vertical trials
        currentPhase = .verticalPhase
        pendingTrials = generateTrialSequence(directions: [.up, .down], count: 8)
        currentTrialIndex = trials.count
        gazeIndicatorText = "3D Vertical Saccades - Look up and down at 3D spheres"
        updateVisualStates()
        await runTrials()
        
        // Complete test
        currentPhase = .completed
        isRunning = false
        gazeIndicatorText = "3D Test Complete - Volumetric gaze detection successful!"
        let results = generateResults()
        onTestComplete?(results)
    }
    
    private func runTrials() async {
        for (index, direction) in pendingTrials.enumerated() {
            // Reset for new trial
            currentCue = nil
            showFixation = true
            headMotionExceeded = false
            gazeConfidence = 0.0
            currentlyFocusedTarget = nil
            gazeIndicatorText = "Look at the center 3D sphere"
            
            updateVisualStates()
            
            // Show fixation point
            try? await Task.sleep(nanoseconds: 800_000_000) // 0.8s
            
            // Present cue
            showFixation = false
            currentCue = direction
            cueStartTime = ProcessInfo.processInfo.systemUptime
            gazeIndicatorText = "Look at the \(direction.displayName.lowercased()) 3D target NOW! (Gaze + light tap)"
            
            updateVisualStates()
            
            print("🎯 Presenting 3D cue: \(direction.displayName)")
            
            // Wait for response or timeout
            let timeout: TimeInterval = 3.0
            let deadline = cueStartTime + timeout
            var trialCompleted = false
            
            while ProcessInfo.processInfo.systemUptime < deadline && !trialCompleted {
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms polling
                
                // Check for head motion violation
                if abs(currentHeadYaw) > 6.0 || abs(currentHeadPitch) > 6.0 {
                    headMotionExceeded = true
                    headMotionWarning = "HEAD MOVEMENT DETECTED!"
                    
                    // Invalidate trial
                    let trial = SaccadeTrial(
                        index: currentTrialIndex + index,
                        direction: direction,
                        testDirection: currentPhase == .horizontalPhase ? .horizontal : .vertical,
                        cueTime: cueStartTime,
                        focusTime: nil,
                        latencyMs: nil,
                        outcome: .invalidated,
                        headYawDeg: abs(currentHeadYaw),
                        headPitchDeg: abs(currentHeadPitch)
                    )
                    trials.append(trial)
                    trialCompleted = true
                    gazeIndicatorText = "Trial invalidated - keep head still!"
                    
                    print("❌ Trial invalidated due to head motion: yaw=\(currentHeadYaw)°, pitch=\(currentHeadPitch)°")
                    
                    // Give user time to read message
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }
                
                // Check if trial was completed by target interaction
                if currentCue == nil {
                    trialCompleted = true
                }
            }
            
            // Handle timeout
            if !trialCompleted && currentCue != nil {
                let trial = SaccadeTrial(
                    index: currentTrialIndex + index,
                    direction: direction,
                    testDirection: currentPhase == .horizontalPhase ? .horizontal : .vertical,
                    cueTime: cueStartTime,
                    focusTime: nil,
                    latencyMs: nil,
                    outcome: .timeout,
                    headYawDeg: abs(currentHeadYaw),
                    headPitchDeg: abs(currentHeadPitch)
                )
                trials.append(trial)
                currentCue = nil
                gazeIndicatorText = "Timeout - try to look at 3D targets faster"
                
                print("⏱️ Trial timed out")
                
                // Give user time to read message
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            
            // Clear warnings
            headMotionWarning = ""
            
            // Update progress
            progress = Double(index + 1) / Double(pendingTrials.count)
            
            // Inter-trial interval
            try? await Task.sleep(nanoseconds: 1_200_000_000) // 1.2s
        }
    }
    
    func handleTargetInteraction(entity: Entity) {
        let interactionTime = ProcessInfo.processInfo.systemUptime
        
        // Determine which 3D target was interacted with
        var detectedDirection: SaccadeDirection?
        
        // Check direct entity name first
        if let direction = parseDirectionFromName(entity.name) {
            detectedDirection = direction
        } else {
            // Check parent entities
            var currentEntity = entity
            while let parent = currentEntity.parent {
                if let direction = parseDirectionFromName(parent.name) {
                    detectedDirection = direction
                    break
                }
                currentEntity = parent
            }
        }
        
        guard let direction = detectedDirection else {
            print("⚠️ Could not determine target direction from entity: \(entity.name)")
            return
        }
        
        // Update visual feedback immediately
        lastGazedTarget = direction
        gazeConfidence = 1.0
        currentlyFocusedTarget = direction
        gazeIndicatorText = "✅ 3D Target detected: \(direction.displayName)"
        
        // Animate the target for feedback
        animateTargetSelection(direction)
        
        // Clear feedback after delay
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            await MainActor.run {
                lastGazedTarget = nil
                gazeConfidence = 0.0
                currentlyFocusedTarget = nil
            }
        }
        
        guard let currentCue = currentCue else {
            print("⚠️ 3D Target interaction detected but no active cue")
            return
        }
        
        // Calculate response time from cue to 3D target interaction
        let responseTime = interactionTime - cueStartTime
        let latencyMs = responseTime * 1000
        
        // Check for anticipation (too fast)
        if responseTime < 0.120 {
            let trial = SaccadeTrial(
                index: currentTrialIndex + (pendingTrials.count - pendingTrials.count),
                direction: currentCue,
                testDirection: currentPhase == .horizontalPhase ? .horizontal : .vertical,
                cueTime: cueStartTime,
                focusTime: interactionTime,
                latencyMs: latencyMs,
                outcome: .anticipation,
                headYawDeg: abs(currentHeadYaw),
                headPitchDeg: abs(currentHeadPitch)
            )
            trials.append(trial)
            self.currentCue = nil
            gazeIndicatorText = "Too fast! Wait for the 3D cue"
            
            print("⚡ Anticipation detected: \(Int(latencyMs))ms")
            return
        }
        
        // Determine if correct 3D target was selected
        let isCorrect = direction == currentCue
        let outcome: TrialOutcome = isCorrect ? .correct : .wrongTarget
        
        let trial = SaccadeTrial(
            index: currentTrialIndex + (pendingTrials.count - pendingTrials.count),
            direction: currentCue,
            testDirection: currentPhase == .horizontalPhase ? .horizontal : .vertical,
            cueTime: cueStartTime,
            focusTime: interactionTime,
            latencyMs: latencyMs,
            outcome: outcome,
            headYawDeg: abs(currentHeadYaw),
            headPitchDeg: abs(currentHeadPitch)
        )
        
        trials.append(trial)
        self.currentCue = nil
        
        if isCorrect {
            gazeIndicatorText = "✅ Correct 3D target! \(Int(latencyMs))ms reaction time"
        } else {
            gazeIndicatorText = "❌ Wrong 3D target - look at \(currentCue.displayName)"
        }
        
        print("✅ 3D Saccade completed: \(direction.displayName) -> \(outcome.displayName), latency: \(Int(latencyMs))ms")
    }
    
    private func animateTargetSelection(_ direction: SaccadeDirection) {
        guard let targetEntity = targetEntities[direction] else { return }
        
        // Create a quick scale animation for feedback
        let scaleAnimation = FromToByAnimation<Transform>(
            name: "select",
            from: .init(scale: SIMD3<Float>(1.0, 1.0, 1.0)),
            to: .init(scale: SIMD3<Float>(1.4, 1.4, 1.4)),
            duration: 0.2,
            timing: .easeInOut,
            isAdditive: false
        )
        
        let scaleResource = try? AnimationResource.generate(with: scaleAnimation)
        if let scaleResource = scaleResource {
            targetEntity.playAnimation(scaleResource)
        }
    }
    
    private func parseDirectionFromName(_ name: String) -> SaccadeDirection? {
        switch name {
        case "leftTarget":
            return .left
        case "rightTarget":
            return .right
        case "upTarget":
            return .up
        case "downTarget":
            return .down
        default:
            return nil
        }
    }
    
    func updateVisualStates() {
        updateTargetVisibility()
        updateTargetMaterials()
    }
    
    private func updateTargetVisibility() {
        let isHorizontalPhase = currentPhase == .horizontalPhase
        let isVerticalPhase = currentPhase == .verticalPhase
        
        // Show/hide 3D targets based on phase
        targetEntities[.left]?.isEnabled = isHorizontalPhase
        targetEntities[.right]?.isEnabled = isHorizontalPhase
        targetEntities[.up]?.isEnabled = isVerticalPhase
        targetEntities[.down]?.isEnabled = isVerticalPhase
        
        // Show/hide glow effects
        targetGlowEntities[.left]?.isEnabled = isHorizontalPhase && currentCue == .left
        targetGlowEntities[.right]?.isEnabled = isHorizontalPhase && currentCue == .right
        targetGlowEntities[.up]?.isEnabled = isVerticalPhase && currentCue == .up
        targetGlowEntities[.down]?.isEnabled = isVerticalPhase && currentCue == .down
        
        // Show/hide fixation sphere
        fixationEntity?.isEnabled = showFixation
    }
    
    private func updateTargetMaterials() {
        // Update 3D target materials based on current state
        for (direction, entity) in targetEntities {
            let isActive = currentCue == direction
            let isFocused = currentlyFocusedTarget == direction
            
            let material = create3DMaterial(for: direction, isActive: isActive)
            entity.model?.materials = [material]
            
            // Scale targets based on state
            if isActive {
                entity.transform.scale = SIMD3<Float>(1.3, 1.3, 1.3) // Make bigger when cued
            } else if isFocused {
                entity.transform.scale = SIMD3<Float>(1.1, 1.1, 1.1) // Slightly bigger when focused
            } else {
                entity.transform.scale = SIMD3<Float>(1.0, 1.0, 1.0) // Normal size
            }
        }
    }
    
    func isTargetVisible(_ direction: SaccadeDirection) -> Bool {
        switch currentPhase {
        case .horizontalPhase:
            return direction == .left || direction == .right
        case .verticalPhase:
            return direction == .up || direction == .down
        default:
            return false
        }
    }
    
    private func startHeadTracking() {
        let session = ARKitSession()
        let worldTracking = WorldTrackingProvider()
        
        self.session = session
        self.worldTracking = worldTracking
        
        headTrackingTask = Task {
            do {
                try await session.run([worldTracking])
                isHeadTrackingActive = true
                
                // Capture baseline after a short delay
                try? await Task.sleep(nanoseconds: 500_000_000)
                
                for await update in worldTracking.anchorUpdates {
                    guard let device = update.anchor as? DeviceAnchor else { continue }
                    let currentTransform = device.originFromAnchorTransform
                    
                    // Set baseline on first reading
                    if baselineHeadTransform == nil {
                        baselineHeadTransform = currentTransform
                        await MainActor.run {
                            print("📱 Head tracking baseline established")
                        }
                        continue
                    }
                    
                    guard let baseline = baselineHeadTransform else { continue }
                    
                    // Calculate head motion relative to baseline
                    let deltaTransform = currentTransform * baseline.inverse
                    let (yaw, pitch, _) = extractEulerAngles(from: deltaTransform)
                    
                    await MainActor.run {
                        currentHeadYaw = yaw * 180 / .pi
                        currentHeadPitch = pitch * 180 / .pi
                        
                        // Update warning based on motion
                        if abs(currentHeadYaw) > 4.0 || abs(currentHeadPitch) > 4.0 {
                            headMotionWarning = "Keep head still!"
                        } else {
                            headMotionWarning = ""
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    print("❌ Head tracking failed: \(error)")
                    isHeadTrackingActive = false
                }
            }
        }
    }
    
    private func extractEulerAngles(from transform: simd_float4x4) -> (yaw: Double, pitch: Double, roll: Double) {
        let m = transform
        let yaw = atan2(Double(m[0][2]), Double(m[0][0]))
        let pitch = atan2(-Double(m[1][2]), sqrt(Double(m[0][2] * m[0][2] + m[2][2] * m[2][2])))
        let roll = atan2(Double(m[2][1]), Double(m[2][2]))
        return (yaw, pitch, roll)
    }
    
    private func generateTrialSequence(directions: [SaccadeDirection], count: Int) -> [SaccadeDirection] {
        var sequence: [SaccadeDirection] = []
        
        // Create balanced alternating sequence
        for i in 0..<count {
            sequence.append(directions[i % directions.count])
        }
        
        // Shuffle while avoiding more than 2 consecutive same-side
        return sequence.shuffled()
    }
    
    private func generateResults() -> SaccadesTestResults {
        let horizontalTrials = trials.filter { $0.testDirection == .horizontal }
        let verticalTrials = trials.filter { $0.testDirection == .vertical }
        let validTrials = trials.filter { $0.isValid }
        let latencies = validTrials.compactMap { $0.latencyMs }
        
        let meanLatency = latencies.isEmpty ? nil : latencies.reduce(0, +) / Double(latencies.count)
        let medianLatency: Double? = {
            guard !latencies.isEmpty else { return nil }
            let sorted = latencies.sorted()
            let mid = sorted.count / 2
            return sorted.count % 2 == 0 ?
                (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
        }()
        
        let standardDeviation: Double? = {
            guard let mean = meanLatency, !latencies.isEmpty else { return nil }
            let variance = latencies.reduce(0) { $0 + pow($1 - mean, 2) } / Double(latencies.count)
            return sqrt(variance)
        }()
        
        let totalTrials = trials.count
        let errors = trials.filter { $0.outcome == .wrongTarget }.count
        let timeouts = trials.filter { $0.outcome == .timeout }.count
        let anticipations = trials.filter { $0.outcome == .anticipation }.count
        let invalidated = trials.filter { $0.outcome == .invalidated }.count
        
        let maxHeadMotion = trials.map { max($0.headYawDeg, $0.headPitchDeg) }.max() ?? 0
        let avgHeadMotion = trials.isEmpty ? 0 :
            trials.map { ($0.headYawDeg + $0.headPitchDeg) / 2 }.reduce(0, +) / Double(trials.count)
        
        print("📊 3D Test Results: \(validTrials.count)/\(totalTrials) valid trials, mean: \(meanLatency ?? 0)ms")
        
        return SaccadesTestResults(
            startedAt: testStartTime,
            completedAt: Date(),
            horizontalTrials: horizontalTrials,
            verticalTrials: verticalTrials,
            meanLatencyMs: meanLatency,
            medianLatencyMs: medianLatency,
            standardDeviationMs: standardDeviation,
            bestLatencyMs: latencies.min(),
            worstLatencyMs: latencies.max(),
            errorRate: totalTrials > 0 ? Double(errors) / Double(totalTrials) : 0,
            timeoutRate: totalTrials > 0 ? Double(timeouts) / Double(totalTrials) : 0,
            anticipationRate: totalTrials > 0 ? Double(anticipations) / Double(totalTrials) : 0,
            invalidatedCount: invalidated,
            maxHeadMotionDeg: maxHeadMotion,
            averageHeadMotionDeg: avgHeadMotion,
            headMotionViolations: invalidated
        )
    }
}

// MARK: - UI Components

struct SaccadesInstructionsView: View {
    let onStart: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("3D Volumetric Saccades Test")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "cube.fill")
                        .foregroundStyle(.blue)
                        .frame(width: 24)
                    Text("This test uses 3D spheres floating in space to measure eye movement")
                }
                
                HStack {
                    Image(systemName: "target")
                        .foregroundStyle(.green)
                        .frame(width: 24)
                    Text("When a 3D target glows, quickly look at it and lightly tap")
                }
                
                HStack {
                    Image(systemName: "hand.point.up.left.fill")
                        .foregroundStyle(.orange)
                        .frame(width: 24)
                    Text("Use gaze + light tap on the volumetric 3D spheres")
                }
                
                HStack {
                    Image(systemName: "head.profile.arrow.forward.and.arrow.backward")
                        .foregroundStyle(.red)
                        .frame(width: 24)
                    Text("Keep your head completely still - only move your eyes")
                }
                
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.purple)
                        .frame(width: 24)
                    Text("3D targets will glow and animate when active")
                }
            }
            .font(.body)
            .foregroundStyle(.white)
            
            VStack(spacing: 8) {
                Text("3D Test Sequence:")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Text("1. Horizontal 3D saccades (left ↔ right spheres)")
                    .foregroundStyle(.secondary)
                
                Text("2. Vertical 3D saccades (up ↕ down spheres)")
                    .foregroundStyle(.secondary)
            }
            
            VStack(spacing: 4) {
                Text("Targets are true 3D objects in volumetric space")
                    .font(.callout.bold())
                    .foregroundStyle(.green)
                
                Text("Look around to see the spatial depth")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                
                Text("Head movement will invalidate trials")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            
            Button {
                onStart()
            } label: {
                Text("Begin 3D Test")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(32)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .frame(maxWidth: 600)
    }
}

struct TestHUDView: View {
    @Bindable var controller: SaccadesController
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Phase indicator
            Text(phaseTitle)
                .font(.headline.bold())
                .foregroundStyle(.white)
            
            // Progress
            ProgressView(value: controller.progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                .frame(width: 220)
            
            Text("\(Int(controller.progress * 100))% Complete")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Divider()
            
            // Prominent 3D gaze feedback
            VStack(alignment: .leading, spacing: 8) {
                Text("3D VOLUMETRIC DETECTION:")
                    .font(.caption.bold())
                    .foregroundStyle(.green)
                
                HStack {
                    Circle()
                        .fill(controller.gazeConfidence > 0 ? .green : .gray.opacity(0.5))
                        .frame(width: 12, height: 12)
                        .scaleEffect(controller.gazeConfidence > 0 ? 1.5 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: controller.gazeConfidence)
                    
                    Text(controller.gazeIndicatorText)
                        .font(.callout.bold())
                        .foregroundStyle(controller.gazeConfidence > 0 ? .green : .white)
                }
            }
            
            Divider()
            
            // Head motion indicator
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "gyroscope")
                        .foregroundStyle(controller.isHeadTrackingActive ? 
                                       (controller.headMotionExceeded ? .red : .green) : .gray)
                    
                    Text("HEAD TRACKING")
                        .font(.caption.bold())
                        .foregroundStyle(controller.isHeadTrackingActive ? .white : .gray)
                }
                
                if controller.isHeadTrackingActive {
                    Text("Yaw: \(abs(controller.currentHeadYaw), specifier: "%.1f")° | Pitch: \(abs(controller.currentHeadPitch), specifier: "%.1f")°")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Initializing...")
                        .font(.caption2)
                        .foregroundStyle(.gray)
                }
            }
            
            if !controller.headMotionWarning.isEmpty {
                Text(controller.headMotionWarning)
                    .font(.caption.bold())
                    .foregroundStyle(.red)
                    .padding(6)
                    .background(.red.opacity(0.2), in: RoundedRectangle(cornerRadius: 4))
            }
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .frame(minWidth: 280)
    }
    
    private var phaseTitle: String {
        switch controller.currentPhase {
        case .horizontalPhase:
            return "3D Horizontal Saccades"
        case .verticalPhase:
            return "3D Vertical Saccades"
        default:
            return "3D Saccades Test"
        }
    }
}

struct SaccadesResultsView: View {
    let results: SaccadesTestResults
    let onComplete: () -> Void
    
    private var scoreColor: Color {
        switch results.overallScore {
        case 90...100: return .green
        case 70...89: return .yellow
        default: return .red
        }
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Text("3D Saccades Test Results")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
            
            Text("✅ 3D Volumetric Detection Successful")
                .font(.headline)
                .foregroundStyle(.green)
            
            // Overall Score
            VStack(spacing: 12) {
                Text("\(results.overallScore)")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundStyle(scoreColor)
                
                Text(results.performanceCategory)
                    .font(.title2.bold())
                    .foregroundStyle(scoreColor)
                
                Text("3D Saccadic Performance")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .background(
                LinearGradient(colors: [scoreColor.opacity(0.15), scoreColor.opacity(0.05)], startPoint: .top, endPoint: .bottom),
                in: RoundedRectangle(cornerRadius: 16)
            )
            
            // Key Metrics
            HStack(spacing: 32) {
                metricView("Mean Latency", "\(Int(results.meanLatencyMs ?? 0)) ms", 
                          (results.meanLatencyMs ?? 0) < 250 ? .green : .red)
                
                metricView("3D Accuracy", "\(Int((1 - results.errorRate) * 100))%", 
                          results.errorRate < 0.15 ? .green : .red)
                
                metricView("Valid Trials", "\(results.validTrials)/\(results.totalTrials)", 
                          results.validTrials >= results.totalTrials * 8 / 10 ? .green : .orange)
            }
            
            // Clinical Indicators
            if results.hasConcussionIndicators {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Performance Indicators Detected")
                            .font(.headline.bold())
                            .foregroundStyle(.orange)
                    }
                    
                    Text("3D results suggest potential saccadic dysfunction")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(16)
                .background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
            }
            
            if results.recommendsEvaluation {
                Text("Consider follow-up neurological evaluation")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Detailed metrics summary
            VStack(alignment: .leading, spacing: 4) {
                Text("3D Test Results:")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                if let meanLatency = results.meanLatencyMs {
                    Text("• Mean reaction time: \(Int(meanLatency)) ms (3D volumetric)")
                }
                if let best = results.bestLatencyMs {
                    Text("• Best reaction time: \(Int(best)) ms")
                }
                Text("• 3D target accuracy: \(Int((1 - results.errorRate) * 100))%")
                Text("• Head motion violations: \(results.headMotionViolations)")
                
                if results.anticipationRate > 0 {
                    Text("• Anticipation rate: \(Int(results.anticipationRate * 100))%")
                        .foregroundStyle(.orange)
                }
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Button {
                onComplete()
            } label: {
                Text("Complete 3D Test")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(colors: [scoreColor, scoreColor.opacity(0.8)], startPoint: .leading, endPoint: .trailing),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(32)
        .frame(maxWidth: 700)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(scoreColor, lineWidth: 2)
        }
    }
    
    private func metricView(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(color)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 120)
    }
}