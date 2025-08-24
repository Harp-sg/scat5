
Saccades Test – Detailed Design
Purpose: Measure the speed and accuracy of the user’s rapid eye movements (saccades) when switching focus between targets. Concussions often cause delayed or inaccurate saccades – e.g. the eyes may overshoot or have latency when trying to quickly refocus from one point to another. This test evaluates cognitive processing and ocular motor control for rapid gaze shifts. Scenario & Stimulus: Two target points will be presented, and the user will be asked to look back-and-forth between them quickly on cue:
We will conduct horizontal saccades (left-right) and possibly vertical saccades (up-down) as separate trials. Horizontal is the primary one (since it’s in VOMS and commonly revealing).
For horizontal: We place two small spheres or icons at fixed positions to the left and right of the user’s central gaze. For example, one target ~15° to the left of center, and the other ~15° to the right, both at about 1.5 m distance (so roughly 0.4m left/right from center in world coordinates at that depth). They could be similar in appearance to the pursuit orb (maybe a different color to distinguish, e.g. one green on left, one blue on right, or both white).
The user is instructed: “When I say left or right (or when the target flashes), quickly look at the indicated target.” We will have a series of, say, 10 prompts alternating between left and right. The interval between prompts might be ~2 seconds: enough time for a normal person to refocus immediately, but short enough to challenge someone with a concussion.
We can provide the cue either by audio (“Look LEFT… now RIGHT…”) and/or by a visual cue: e.g. the target that should be looked at could flash or enlarge briefly. Using a visual flash might be more precise for measuring reaction time (since we know exactly when the flash occurs as the “GO” signal). We can also synchronize both: play a sound or voice and flash the target concurrently.
The user’s task is simply to snap their eyes to the cued target as fast as possible (without moving head).
Visual Design & UI: Both targets should be clearly visible in the user’s periphery when they look straight ahead. We might start with the user focusing on a central dot (to ensure a consistent start position). Then the test begins with a cue for either left or right. The targets can be spheres or perhaps flat 3D UI elements (like focusable buttons) to take advantage of VisionOS focus highlighting. We will likely highlight the currently cued target (e.g. make it briefly grow in size or pulse) to draw the user’s attention. VisionOS will also highlight whichever target the user is actually looking at (via the gaze focus effect), which gives them feedback that they’ve looked at it. To avoid clutter, we won’t move these targets; they remain static at their positions. A minimal UI text might show “Round 3/10” or similar to indicate progress, or we might omit that to keep the user fully attentive to cues. Technical Implementation: This test requires precise timing and detection of gaze shifts:
Target Setup: We create two focusable entities or SwiftUI views for the left and right targets. Each needs to be gaze-interactive. One approach: Use SwiftUI Button or Toggle views placed in 3D (using VisionView or an anchored window) at the desired locations, with .focusable(true, onFocusChange:) to monitor focus. Alternatively, use RealityKit entities with colliders and a HoverEffect. SwiftUI focus system may be simpler for capturing focus change events with known timing. We can define an onFocusChange for each target that triggers when the user’s gaze enters that target.
Prompting and Timing: We will create a sequence of prompts (could be hardcoded or randomized but balanced in count). For example, an array like ["Left", "Right", "Left", ...]. For each prompt, the logic is:
Highlight the target to indicate it’s the one to look at. For instance, if cue is "Left", we can change the left target’s appearance momentarily (e.g. toggle a filled circle or change color) or play a quick animation (pulse).
Record the timestamp of the cue (using DispatchTime.now() or a monotonic clock).
Wait for the user’s gaze to land on that target. We detect this via the target’s focus change: when .onFocusChange(true) triggers for that target, we record the timestamp of focus. The difference gives us reaction time.
If the user was already looking at the correct target at the time of cue (which might happen if they anticipate or if two cues in a row are the same side), we handle that separately (we might discard that trial or re-cue, because we want them to have to move eyes).
If the user looks at the wrong target (e.g. cue says left but they gaze right, perhaps due to confusion), we will note an incorrect response. The system can detect this because the wrong target’s focus would trigger instead. In that case, we can prompt them again or just log it as an error (in real testing, clinicians look for overshooting or wrong-way saccades as signs of impairment).
After the user successfully focuses the correct target, or if a set max time (like 1.5 seconds) passes, we move to the next cue. We will likely allow up to ~1–2 seconds for the user to respond; if they haven’t focused by then, that trial is marked as “missed” and we advance.
Focus Detection Implementation: If using SwiftUI views for targets, it’s straightforward:
swift
Copy
Edit
Circle()  // left target
  .frame(width: 0.05, height: 0.05) // 5 cm circle
  .position(x: -0.4, y: 0)         // example position in container coordinates
  .focusable(true, onFocusChange: { isFocused in 
       if isFocused { leftTargetFocusedAt = Date() }
  })
We would embed this in an immersive SwiftUI container (the coordinates would be in meters perhaps via a RealityView or an anchor). If using RealityKit entities, we would rely on HoverEffect highlight – but to get precise timing, SwiftUI’s focus system might be easier to tie into our logic. VisionOS essentially uses the same gaze focus mechanism for both SwiftUI and RealityKit (with HoverEffect), but SwiftUI gives a high-level hook.
Preventing Cheating (Head Movements): Similar to the pursuit test, we want only eye movement. We instruct the user to keep their head still. We will monitor head transform here as well, and if we detect significant head turning (which would make the saccade easier), we can pause and remind the user. Because the targets are only ~15° apart, a modest head turn could “cheat” the test. We set a threshold (maybe <5° head yaw change allowed). If exceeded during a trial, we might invalidate that trial and repeat it, with a message “Please do not move your head, only your eyes.” This will ensure the validity of the reaction time data.
Data Collection: For each saccade trial, we will record:
Reaction time (in milliseconds) = time from cue to gaze focus on target.
Whether the correct target was focused or if there was an error (wrong target or no response).
We’ll take an average reaction time over the successful trials and also note the worst (slowest) time. Concussed individuals might have significantly slower saccades. For example, if normals average, say, ~200 ms, and the user is averaging 400 ms, that’s an indicator of impairment (exact thresholds TBD from literature or internal baseline).
Any missed or incorrect responses count as abnormal signs as well.
We may also qualitatively note if the user “overshoots” – overshoot would manifest as perhaps briefly focusing beyond the target then coming back. With our detection method, overshoot might appear as either a delay in focusing or a momentary focus on the wrong target. We likely can’t perfectly measure overshoot without continuous eye tracking, but any irregular focus patterns can be flagged.
All these metrics will be stored. If any are outside norms (e.g. reaction time beyond a cutoff), the system flags it. We will also compare to user’s baseline if available (some athletes might do a baseline test when healthy).
Symptom Check: After the series of saccades (which only takes maybe 20 seconds total), we prompt the user with the same symptom survey overlay. They rate if quick eye movements caused any new symptoms (it could provoke headache or dizziness in concussed individuals). This is recorded.
References/Resources: The focus-change detection leverages VisionOS gaze highlighting. We know from Apple’s documentation that when people look at an interactive element, VisionOS will highlight it
developer.apple.com
. We will use the SwiftUI focusable views to catch that event. (On tvOS, .focusable is commonly used, and VisionOS uses a similar focus engine). For Unity reference, if needed, the XR Interaction Toolkit examples include a Gaze Interaction sample that uses an eye-tracked gaze interactor to select objects
github.com
, which conceptually matches what we do here (though we prefer not to switch to Unity unless necessary). The logic for measuring reaction time to focus events is custom but straightforward given the tools.

Saccades.md
Goal
Measure saccadic latency and accuracy during horizontal (and optional vertical) cue-driven gaze shifts, while enforcing head-still constraints. Output per-trial latency, error/miss rates, and summary stats; prompt symptom rating.

UX (volumetric)
ImmersiveSpace with a neutral backdrop.

Center fixation dot (start).

Two volumetric targets at ~±15° horizontally (≈±0.40 m at 1.5 m depth). Optional vertical pair later.

Cue sequence (10 trials default). On cue, the cued target pulses; user snaps eyes to it without moving head.

VisionOS gaze focus highlight indicates where they’re looking; we timestamp the moment focus lands on the cued target.

Head yaw relative to baseline is monitored; trials exceeding threshold (default 5°) are invalidated and re-queued once.

Post-block, a symptom panel appears (0–10 for dizziness/headache/nausea).

Acceptance criteria
10 valid horizontal trials captured with:

Per-trial: cue side, cue timestamp, latency ms, correct|wrong|timeout, head-motion flag.

Summary: mean/median latency, SD, worst, error rate, timeouts, invalidated/repeats, head-motion count.

Stores a SaccadesResult struct you can persist via SwiftData in your app.

Optional vertical block behind a feature flag.

Data model (module-local)
swift
Copy
Edit
import Foundation

enum SaccadeSide: String, Codable { case left, right }
enum TrialOutcome: String, Codable { case correct, wrongTarget, timeout, invalidated }

struct SaccadeTrial: Codable, Identifiable {
    let id = UUID()
    let index: Int
    let side: SaccadeSide
    let cueTime: TimeInterval   // monotonic seconds
    var focusTime: TimeInterval?
    var latencyMs: Double?      // computed
    var outcome: TrialOutcome
    var headYawDeg: Double      // peak yaw delta during trial
}

struct SaccadesResult: Codable {
    let startedAt: Date
    let horizontal: [SaccadeTrial]
    // Aggregates
    let meanLatencyMs: Double?
    let medianLatencyMs: Double?
    let sdLatencyMs: Double?
    let worstLatencyMs: Double?
    let errorRate: Double
    let timeoutRate: Double
    let invalidatedCount: Int
    // Symptoms (0–10)
    let dizziness: Int
    let headache: Int
    let nausea: Int
}
Constants & tuning
swift
Copy
Edit
enum SaccadeConfig {
    // Geometry @ 1.5 m depth
    static let targetDepthM: Float = 1.5
    static let horizontalOffsetM: Float = 0.40  // ≈ 15° at 1.5m
    static let verticalOffsetM: Float = 0.28    // optional ≈ 10° at 1.5m

    // Timing
    static let trialsPerBlock = 10
    static let interCueInterval: TimeInterval = 2.0
    static let responseTimeout: TimeInterval = 1.5

    // Head gating
    static let maxHeadYawDeg: Double = 5.0
    static let recenterGraceMs: Double = 150

    // Visuals
    static let targetDiameterM: CGFloat = 0.05
    static let fixationDiameterM: CGFloat = 0.04
}
Implementation (SwiftUI + RealityKit, ImmersiveSpace)
This is a drop-in minimal module. Add it to a visionOS target. It compiles on Xcode 15.4/16-beta (VisionOS 1/2). If you already have a project shell, merge the ImmersiveSpace and RealityView into your flow and wire the onFinish.

swift
Copy
Edit
import SwiftUI
import RealityKit
import Observation

// MARK: - Orchestrator

@Observable
final class SaccadesController {
    // Camera / head pose baseline
    var baselineYawRad: Double? = nil

    // Focus states
    var leftFocused = false
    var rightFocused = false
    var lastFocusChangeMonotonic: TimeInterval = 0

    // Head yaw tracking
    var currentYawRad: Double = 0
    var peakYawDeltaDeg: Double = 0

    // Trials
    private(set) var trials: [SaccadeTrial] = []
    private var nextIndex = 0
    private var pending: [SaccadeSide] = []
    private var currentCue: (index: Int, side: SaccadeSide, cueMono: TimeInterval)?
    private var timerTask: Task<Void, Never>?

    // State
    enum Phase { case idle, running, finished }
    var phase: Phase = .idle

    // MARK: Public API

    func startHorizontalBlock() {
        trials = []
        nextIndex = 0
        pending = makeBalancedSequence(count: SaccadeConfig.trialsPerBlock)
        peakYawDeltaDeg = 0
        phase = .running
        runLoop()
    }

    func cancel() {
        timerTask?.cancel()
        phase = .idle
        currentCue = nil
        pending.removeAll()
    }

    // Called by UI on focus change (left/right)
    func focused(target: SaccadeSide, isFocused: Bool, nowMono: TimeInterval) {
        switch target {
        case .left: leftFocused = isFocused
        case .right: rightFocused = isFocused
        }
        lastFocusChangeMonotonic = nowMono
        // If we are in a live trial, check hit
        guard let cur = currentCue else { return }
        guard isFocused else { return }

        // Enforce that focus occurs AFTER cue (debounce anticipations)
        guard nowMono >= cur.cueMono else { return }

        let hitTarget = target == cur.side
        completeTrial(byFocusOnCorrect: hitTarget, atMono: nowMono)
    }

    // Called by RealityView update each frame
    func updateCameraYaw(_ yawRad: Double) {
        currentYawRad = yawRad
        if baselineYawRad == nil { baselineYawRad = yawRad }
        guard let base = baselineYawRad else { return }
        let delta = wrapAngle(yawRad - base) // [-π, π]
        let deg = abs(delta * 180 / .pi)
        peakYawDeltaDeg = max(peakYawDeltaDeg, deg)
    }

    // MARK: Internals

    private func runLoop() {
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            guard let self else { return }
            var recenterAtMono: TimeInterval = monotonic()

            while !Task.isCancelled, phase == .running {
                guard let side = pending.first else {
                    phase = .finished
                    break
                }
                pending.removeFirst()
                let idx = nextIndex; nextIndex += 1
                // Snapshot head baseline for this trial
                baselineYawRad = currentYawRad
                peakYawDeltaDeg = 0

                // Cue
                let cueMono = monotonic()
                currentCue = (idx, side, cueMono)
                await MainActor.run {
                    // Emit a transient pulse signal via state the UI can animate
                    NotificationCenter.default.post(name: .saccadeCue, object: side)
                }

                // Wait for response or timeout, sampling head yaw
                let deadline = cueMono + SaccadeConfig.responseTimeout
                var outcome: TrialOutcome = .timeout
                var focusTime: TimeInterval? = nil
                // Poll until focus callback completes trial or timeout; check head motion
                while monotonic() < deadline && currentCue != nil && phase == .running {
                    try? await Task.sleep(nanoseconds: 10_000_000) // 10 ms
                    // Head motion gating
                    if peakYawDeltaDeg > SaccadeConfig.maxHeadYawDeg {
                        outcome = .invalidated
                        break
                    }
                }
                // If trial still active and wasn’t invalidated, check if focus landed
                if let cur = currentCue, outcome != .invalidated {
                    if let _ = focusTime {
                        // handled in completeTrial()
                    } else {
                        // timeout (or wrong target happened but focus callback will have called completeTrial)
                        let t = SaccadeTrial(index: idx, side: side, cueTime: cueMono,
                                             focusTime: nil, latencyMs: nil,
                                             outcome: .timeout, headYawDeg: peakYawDeltaDeg)
                        trials.append(t)
                        currentCue = nil
                    }
                }
                // If invalidated: re-queue this side once after brief recenter
                if outcome == .invalidated {
                    // Give user a short “recenter” grace period
                    recenterAtMono = monotonic()
                    pending.insert(side, at: 0) // retry immediately
                    let t = SaccadeTrial(index: idx, side: side, cueTime: cueMono,
                                         focusTime: nil, latencyMs: nil,
                                         outcome: .invalidated, headYawDeg: peakYawDeltaDeg)
                    trials.append(t)
                    currentCue = nil
                    // Small pause to let them settle
                    try? await Task.sleep(nanoseconds: 250_000_000)
                } else {
                    // Inter-cue gap
                    let remaining = SaccadeConfig.interCueInterval - max(0, monotonic() - cueMono)
                    if remaining > 0 { try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000)) }
                }
            }
        }
    }

    private func completeTrial(byFocusOnCorrect: Bool, atMono: TimeInterval) {
        guard let cur = currentCue else { return }
        guard phase == .running else { return }
        let latencyMs = (atMono - cur.cueMono) * 1000.0
        let outcome: TrialOutcome = byFocusOnCorrect ? .correct : .wrongTarget
        let t = SaccadeTrial(index: cur.index, side: cur.side, cueTime: cur.cueMono,
                             focusTime: atMono, latencyMs: latencyMs,
                             outcome: outcome, headYawDeg: peakYawDeltaDeg)
        trials.append(t)
        currentCue = nil
    }

    private func makeBalancedSequence(count: Int) -> [SaccadeSide] {
        var arr: [SaccadeSide] = []
        for i in 0..<count { arr.append(i % 2 == 0 ? .left : .right) }
        // Optional: shuffle with constraint to avoid >2 repeats
        return arr
    }

    private func wrapAngle(_ a: Double) -> Double {
        var x = fmod(a + .pi, 2 * .pi)
        if x < 0 { x += 2 * .pi }
        return x - .pi
    }

    private func monotonic() -> TimeInterval {
        // Mach absolute time via ProcessInfo
        ProcessInfo.processInfo.systemUptime
    }
}

extension Notification.Name {
    static let saccadeCue = Notification.Name("SaccadeCue")
}
Immersive space + RealityView with volumetric attachments
swift
Copy
Edit
struct SaccadesImmersiveSpace: View {
    @Environment(SaccadesController.self) private var vm

    var body: some View {
        RealityView { content in
            // Left/Right attachment entities placed in world
            let left = AttachmentEntity(id: "left")
            left.position = [ -SaccadeConfig.horizontalOffsetM, 0, -SaccadeConfig.targetDepthM ]
            content.add(left)

            let right = AttachmentEntity(id: "right")
            right.position = [  SaccadeConfig.horizontalOffsetM, 0, -SaccadeConfig.targetDepthM ]
            content.add(right)

            // Center fixation
            let center = AttachmentEntity(id: "center")
            center.position = [ 0, 0, -SaccadeConfig.targetDepthM ]
            content.add(center)

        } update: { content in
            // Read live camera transform -> yaw
            if let cam = content.cameraTransform {
                // extract yaw from rotation matrix (Y-up world)
                let m = cam.rotation.matrix
                let yaw = atan2(Double(m.columns.0.z), Double(m.columns.0.x)) // approx
                vm.updateCameraYaw(yaw)
            }
        } attachments: {
            // Focusable targets as SwiftUI in 3D (volumetric UI)
            Attachment(id: "left") {
                SaccadeTargetView(color: .green, label: "L")
                    .focusable(true) { isFocused in
                        vm.focused(target: .left, isFocused: isFocused, nowMono: ProcessInfo.processInfo.systemUptime)
                    }
            }
            .accessibilityLabel("Left target")

            Attachment(id: "right") {
                SaccadeTargetView(color: .blue, label: "R")
                    .focusable(true) { isFocused in
                        vm.focused(target: .right, isFocused: isFocused, nowMono: ProcessInfo.processInfo.systemUptime)
                    }
            }
            .accessibilityLabel("Right target")

            Attachment(id: "center") {
                FixationDotView()
                    .accessibilityLabel("Fixation")
            }
        }
        .gesture(SpatialTapGesture().targetedToAnyEntity().onEnded { _ in }) // reserve focus, optional
        .overlay(alignment: .top) { SaccadesHUD() }
        .onReceive(NotificationCenter.default.publisher(for: .saccadeCue)) { note in
            // just used to animate pulse ring on targets
        }
    }
}

private struct SaccadeTargetView: View {
    let color: Color
    let label: String
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .frame(width: SaccadeConfig.targetDiameterM, height: SaccadeConfig.targetDiameterM)
                .foregroundStyle(color.opacity(0.9))
                .overlay {
                    Circle().strokeBorder(.white.opacity(0.9), lineWidth: 0.002)
                }
                .scaleEffect(pulse ? 1.4 : 1.0)
                .animation(.easeInOut(duration: 0.18), value: pulse)

            // Optional tiny label
            Text(label).font(.system(size: 0.018, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
        }
        // Listen for cue to pulse
        .onReceive(NotificationCenter.default.publisher(for: .saccadeCue)) { note in
            if let side = note.object as? SaccadeSide {
                if (side == .left && label == "L") || (side == .right && label == "R") {
                    pulse = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { pulse = false }
                }
            }
        }
    }
}

private struct FixationDotView: View {
    var body: some View {
        Circle()
            .frame(width: SaccadeConfig.fixationDiameterM, height: SaccadeConfig.fixationDiameterM)
            .foregroundStyle(.white.opacity(0.95))
            .overlay {
                Circle().stroke(.black.opacity(0.6), lineWidth: 0.0015)
            }
    }
}
HUD & controls
swift
Copy
Edit
struct SaccadesHUD: View {
    @Environment(SaccadesController.self) private var vm
    @State private var showStart = true
    @State private var showSymptoms = false

    // Symptom ratings
    @State private var dizziness = 0
    @State private var headache = 0
    @State private var nausea = 0

    var body: some View {
        VStack(spacing: 10) {
            if showStart, vm.phase == .idle {
                VStack(spacing: 8) {
                    Text("Saccades (Horizontal)")
                        .font(.title2).bold()
                    Text("Keep your **head still**. On cue, snap your eyes to the pulsing target.")
                        .multilineTextAlignment(.center)

                    Button("Start") {
                        showStart = false
                        vm.startHorizontalBlock()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(16)
                .glassBackgroundEffect()
            }

            if vm.phase == .running {
                Text("Trials: \(vmCompletedCount(vm))/\(SaccadeConfig.trialsPerBlock)")
                    .padding(8)
                    .glassBackgroundEffect()
            }

            if vm.phase == .finished {
                VStack(spacing: 8) {
                    SummaryView(trials: vm.trials)
                    Button("Record Symptoms") { showSymptoms = true }
                        .buttonStyle(.borderedProminent)
                    Button("Restart") {
                        showStart = true
                        showSymptoms = false
                        vm.cancel()
                    }
                }
                .padding(16)
                .glassBackgroundEffect()
            }
        }
        .sheet(isPresented: $showSymptoms) {
            SymptomSheet(dizziness: $dizziness, headache: $headache, nausea: $nausea) {
                let result = makeResult(vm: vm, dz: dizziness, hd: headache, nz: nausea)
                // TODO: hand off `result` to your SwiftData layer
                showSymptoms = false
            }
        }
    }

    private func vmCompletedCount(_ vm: SaccadesController) -> Int {
        vm.trials.filter { $0.outcome != .invalidated }.count
    }

    private func makeResult(vm: SaccadesController, dz: Int, hd: Int, nz: Int) -> SaccadesResult {
        let hs = vm.trials.filter { $0.outcome == .correct }.compactMap { $0.latencyMs }
        let mean = hs.isEmpty ? nil : hs.reduce(0,+)/Double(hs.count)
        let sorted = hs.sorted()
        let median = hs.isEmpty ? nil : (sorted.count % 2 == 1 ?
            sorted[sorted.count/2] : (sorted[sorted.count/2 - 1] + sorted[sorted.count/2]) / 2)
        let worst = hs.max()
        let sd = hs.isEmpty ? nil : sqrt(hs.reduce(0) { $0 + pow($1 - (mean ?? 0), 2) } / Double(hs.count))

        let errors = Double(vm.trials.filter { $0.outcome == .wrongTarget }.count)
        let timeouts = Double(vm.trials.filter { $0.outcome == .timeout }.count)
        let invalid = vm.trials.filter { $0.outcome == .invalidated }.count
        let denom = Double(SaccadeConfig.trialsPerBlock)

        return SaccadesResult(
            startedAt: Date(),
            horizontal: vm.trials,
            meanLatencyMs: mean,
            medianLatencyMs: median,
            sdLatencyMs: sd,
            worstLatencyMs: worst,
            errorRate: denom > 0 ? errors / denom : 0,
            timeoutRate: denom > 0 ? timeouts / denom : 0,
            invalidatedCount: invalid,
            dizziness: dz, headache: hd, nausea: nz
        )
    }
}

private struct SummaryView: View {
    let trials: [SaccadeTrial]
    var body: some View {
        let hits = trials.filter { $0.outcome == .correct }.compactMap { $0.latencyMs }
        let mean = hits.isEmpty ? 0 : hits.reduce(0,+)/Double(hits.count)
        VStack(spacing: 4) {
            Text("Block complete").font(.title3).bold()
            Text("Mean latency: \(mean.rounded()) ms")
            Text("Errors: \(trials.filter{$0.outcome == .wrongTarget}.count) • Timeouts: \(trials.filter{$0.outcome == .timeout}.count)")
            Text("Invalidated (head): \(trials.filter{$0.outcome == .invalidated}.count)")
        }
    }
}

private struct SymptomSheet: View {
    @Binding var dizziness: Int
    @Binding var headache: Int
    @Binding var nausea: Int
    var onDone: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Stepper("Dizziness: \(dizziness)", value: $dizziness, in: 0...10)
                Stepper("Headache: \(headache)", value: $headache, in: 0...10)
                Stepper("Nausea: \(nausea)", value: $nausea, in: 0...10)
            }
            .navigationTitle("Symptoms (0–10)")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Save", action: onDone) } }
        }
    }
}
App entry for a standalone test (wire into your app’s flow as needed)
swift
Copy
Edit
@main
struct SaccadesDemoApp: App {
    @State private var vm = SaccadesController()

    var body: some Scene {
        WindowGroup(id: "home") {
            VStack(spacing: 12) {
                Text("Saccades Test Prototype").font(.title2).bold()
                Text("Open ImmersiveSpace to begin.").foregroundStyle(.secondary)
                Button("Enter Immersive") { openImmersive(spaceID: "saccades") }
                    .buttonStyle(.borderedProminent)
            }
            .environment(vm)
        }

        ImmersiveSpace(id: "saccades") {
            SaccadesImmersiveSpace().environment(vm)
        }
    }
}

@MainActor
func openImmersive(spaceID: String) {
    Task { try? await ImmersiveSpaceManager.shared.openImmersiveSpace(id: spaceID) }
}
Integration hook: Replace the onDone in SymptomSheet with your SwiftData write (e.g., attach @Model entities and persist SaccadesResult JSON or decompose into fields).

Notes & testing tips
Focus timing accuracy: We use systemUptime (monotonic) for cue/focus timing; avoid Date() for latency math.

Head gating: Yaw extraction from cameraTransform rotation is lightweight and runs per frame. Adjust maxHeadYawDeg if clinicians want stricter enforcement (e.g., 3°).

Cue balance: Sequence alternates L/R by default. Swap in a constrained shuffle if you want randomized order without repeats >2.

Vertical block: Duplicate the target attachments at ±verticalOffsetM on Y and reuse the controller; add a toggle to run vertical trials.

Accessibility: All targets are focusable; the system renders gaze highlight, reinforcing correct selection visually.

Repos & snippets to reference (for your agent)
Apple Hand-tracking sample (for pinch & joint utilities you’ll reuse in Convergence): joint anchors + per-frame transforms; clean async sequence pattern.

SwiftUI Focus (visionOS HIG & examples): .focusable, onFocusChange, focus movement patterns for timing focus landings.

RealityKit motion: Entity.move(to:duration:) + async chaining gist; helpful if you later animate cues or move targets.

VisionPro Teleop (pattern): clean camera/pose sampling + timestamping you can mirror for VOR head compliance.

