
Smooth Pursuit Test – Detailed Design
Purpose: Assess the user’s ability to smoothly track a moving object with their eyes. After concussion, smooth pursuit eye movements may become “jerky” or unable to keep up with the target, indicating an ocular-motor impairment. This test will reveal if the user’s eyes can steadily follow a slow-moving stimulus without corrective saccades. It is a standard component of VOMS (vestibular/ocular motor screening)
upmc.com
. Scenario & Stimulus: A small, bright 3D orb (e.g. a glowing sphere) will move slowly across the user’s field of view in a controlled pattern. We will first do a horizontal sweep and then a vertical sweep:
Horizontal movement: the orb travels left-right-left in front of the user, covering roughly a ~30° range to each side of center at a distance of ~1.5 meters. It should take about 2–3 seconds to go from one end to the other (around 10–15° per second, a gentle speed that normal eyes can smoothly pursue
imotions.com
).
Vertical movement: the orb moves up-down-up through a similar angular range (e.g. ~20–30° up and down). Same speed profile.
Throughout, the user is instructed “Keep your head still and follow the moving dot with your eyes.” The test lasts ~10–15 seconds per direction.
Visual Design & UI: The orb should be easy to see (brightly colored, e.g. yellow or light-blue, with a slight glow). It moves on a dark or semi-transparent background to maintain contrast. To leverage VisionOS’s volumetric UI, the orb will be a RealityKit Entity in an ARView (within an ImmersiveSpace). There will be a brief on-screen text (and optional voiceover) instruction before the test begins. During the test, we may display a subtle indicator if the user moves their head (for example, a message “Please try to keep head still” if head motion is detected, see below). The orb’s path can be visualized or left invisible; likely invisible to avoid giving the user any fixed reference except the orb itself. We will not display any score or feedback to the user during the test (to avoid distraction), but the clinician’s dashboard might show a live indicator of tracking quality (e.g. orb turns red if user’s eyes fall behind). Technical Implementation: This test is implemented in a RealityKit scene. We will create a ModelEntity for the orb and animate its movement:
Animating the Target: We can use RealityKit’s animation APIs to move the orb smoothly. One simple method is to use the move(to:relativeTo:duration:) function on the entity’s Transform component for a single pass
codingxr.markhorgan.com
. For example, to move horizontally 0.5m right relative to starting point over 2 seconds, then reverse. Alternatively, for continuous back-and-forth motion, we might use a custom timer or an AnimationResource that loops the translation between two points. Pseudocode outline:
swift
Copy
Edit
let startPos: SIMD3<Float> = [ -0.3, 0, -1.5]  // 30cm left at 1.5m distance
let endPos:   SIMD3<Float> = [  0.3, 0, -1.5]  // 30cm right
orb.position = startPos
orb.move(to: Transform(scale: .one, rotation: simd_quatf(), translation: endPos), 
         relativeTo: nil, duration: 2.5, timingFunction: .easeInOut)
// Add completion handler to reverse direction after reaching end, or use repeat.
We will chain or loop these moves for a couple of cycles (left-right-left). The same will be done vertically (with positions above and below). Using RealityKit’s animation system ensures smooth interpolation of movement at the specified speed. We might also explore RealityKit timelines or keyframe animations for more complex paths if needed, but a simple linear oscillation suffices here.
Eye-Tracking & Focus Detection: Direct gaze coordinates are not exposed in VisionOS, so we rely on the focus/hover system to know if the user is looking at the orb. Our approach: make the orb a focusable entity. VisionOS will automatically highlight it when the user’s gaze is on it (since it’s an interactive 3D element in the scene). We will enable a HoverEffectComponent on the orb – possibly using the .highlight style for a gentle glow when focused
GitHub
. This way, as the user’s eyes track the orb, it will appear slightly highlighted if they maintain gaze. We can observe focus changes via the onFocusChange modifier in SwiftUI or by detecting the HoverEffect state on the entity. For implementation, since the orb is a RealityKit entity, we may wrap the ARView in a SwiftUI view and overlay an invisible SwiftUI focusable if needed. However, a better approach is using RealityKit’s collision and focus: by giving the orb a CollisionComponent and enabling gaze tracking (if VisionOS 2.0+ allows it via HoverEffectComponent), we should get focus highlights. We might need to utilize PixelCast (a RealityKit feature for hit-testing what the user looks at) if automatic focus is insufficient
GitHub
GitHub
. Another simpler fallback: place an invisible SwiftUI Button or FocusableView at the orb’s position that moves with it, just to get focus callbacks. This is a bit hacky but ensures we can use .focusable(true, onFocusChange:) to log when focus is on the moving target.
Head Movement Monitoring: The user is instructed to keep their head still. We will use ARKit to monitor this. For example, on each frame (ARView.scene.subscribe(to: SceneEvents.Update) callback), we can check the Vision Pro’s head pose. Using ARView.session.currentFrame.camera.transform, we get the device’s transform. We will compare the current rotation (orientation) to the orientation at test start. If the head has rotated beyond a small threshold (e.g. >5°), or if it’s continuously moving, we interpret that as the user moving their head instead of just their eyes. In such case, we can provide a gentle on-screen reminder: e.g., show a text “Please keep your head still – use only your eyes”. We might momentarily pause the orb’s motion when this happens, or simply note it in the results (“head movement detected”). The inertial sensors in VisionPro are very accurate, so even subtle head turns can be detected. (Since we are not using face tracking here, we rely on device motion.)
Data Collection: We will log metrics like tracking percentage and smoothness. Specifically, we measure how consistently the user’s gaze stayed on the orb:
Focus Time Ratio: Using focus detection, compute the fraction of the test duration that the orb was focused. For instance, if out of 10 seconds of motion the system registered gaze on the orb for 9 seconds, that’s 90% – likely normal. If focus was frequently lost (e.g. user’s gaze dropped away or required catch-up saccades), this ratio will be lower. We may count each lapse (focus lost) as an event and measure its duration.
Qualitative Observation: If possible, we will also note if the tracking was “smooth” or if we suspect catch-up saccades. Without raw eye velocity, this is hard to quantify, but frequent brief losses of focus or very jerky head movements to compensate could be proxies. The clinician could also observe the session live through the device or an external screen to subjectively rate smooth pursuit quality.
All these values will be saved. We will define thresholds (based on normative data or the user’s baseline). For example, a focus time < 80% or more than 2 focus losses might be flagged as abnormal pursuit.
Symptom Check: Immediately after the pursuit test, a SwiftUI overlay will appear asking the user to rate any symptom changes. This can list common symptoms like “Did you feel any increase in: headache, dizziness, nausea, fogginess?” with rating scales 0 (none) to 10 (severe). The user will gaze at a number or a “None” option and pinch to select. (VisionOS gaze control highlights the selectable options when looked at, making it easy to pinch-select.) This mirrors the VOMS protocol where symptom provocation is noted. The selected ratings are stored in the results.
Relevant References/Resources: The implementation will draw on Apple’s RealityKit for animations and focus. For example, Mark Horgan’s RealityKit tutorial shows how to use entity.move(to:duration:) to animate an object’s position
codingxr.markhorgan.com
. Apple’s WWDC material on VisionOS highlights that gaze will automatically highlight focusable entities (“Eyes” input)
developer.apple.com
, which we leverage via the HoverEffect. Unity’s XR Interaction Toolkit (if used as alternative) provides a Gaze Interactor that could simplify gaze detection and selection on Vision Pro
github.com
, but our plan is to achieve this natively in Swift/RealityKit if possible.


Smooth_Pursuit.md
Goal
Quantify smooth pursuit quality using a moving dot in volumetric UI, with gaze focus (for % time on target) and head-motion guardrails (to discourage compensatory head turns). Save metrics to SwiftData alongside SCAT-5.

Clinical parameters (defaults, configurable)
Distance to target (z): 1.50 m

Angular sweep: ±15° (compute lateral amplitude A = z * tan(θ) ≈ 1.5 * tan(15°) ≈ 0.40 m)

If you want ±30° later: A ≈ 0.866 m (requires bigger space).

Speed: 10°/s (end-to-end sweep 30° → ~3.0 s per pass)

Duration: 2 passes horizontal (≈6–7 s) + 2 passes vertical (≈6–7 s)

Head-motion threshold: warn if |yaw| or |pitch| drift > 5° from start; mark event if > 8°.

Focus sampling: use gaze focus on the moving target; compute:

focus_time_ratio = focused_time / test_time

focus_breaks_count and break durations.

Abnormal flags (suggested, tune after pilot):

Horizontal or vertical focus_time_ratio < 0.80 or focus_breaks_count ≥ 3 → flag.

head_motion_events ≥ 2 → “invalid / redo recommended”.

Modes
AR passthrough (default): orb in your real room, high comfort.

Immersive (dim): dark neutral backdrop to boost contrast. Toggle via a setting.

UX flow
Pre-flight panel (volumetric HUD)

Title, brief instructions: “Keep head still; follow the dot with your eyes.”

Buttons: [Start] [Cancel] ; Mode toggle (AR/Immersive).

Test

Small glowing orb sweeps left↔︎right then up↕︎down.

Minimal HUD: countdown chip, HEAD STILL hint if needed, [Pause/Abort].

Post-test prompt

VOMS-style symptoms (0–10): headache, dizziness, nausea, fogginess.

Save & return.

Data model (concept)
SmoothPursuitResult

mode ("AR"/"Immersive"), distance_m

horizontal: SegmentResult, vertical: SegmentResult

head_still_percent, head_motion_events

symptoms: {headache, dizziness, nausea, fogginess}

SegmentResult

duration_s, focus_time_ratio, focus_breaks_count, [focus_break_durations_s]

Code scaffold (drop-in)
Tested patterns: RealityKit animation for the orb, SwiftUI focus for gaze, ARKit camera transform for head pose. The “focus on a 3D thing” is implemented by attaching a tiny invisible focusable SwiftUI view to the moving entity so you get onFocusChange events when the user looks at the orb.

1) SwiftData models (adjust to your existing schema)
swift
Copy
Edit
// SmoothPursuitModels.swift
import Foundation
import SwiftData

@Model
final class SmoothPursuitResult {
    @Attribute(.unique) var id: UUID = .init()
    var createdAt: Date = .now
    var mode: String            // "AR" or "Immersive"
    var distance_m: Double
    // Aggregates
    var headStillPercent: Double
    var headMotionEvents: Int
    // Horizontal
    var h_duration_s: Double
    var h_focusTimeRatio: Double
    var h_focusBreaks: Int
    var h_focusBreakDurations_s: [Double]
    // Vertical
    var v_duration_s: Double
    var v_focusTimeRatio: Double
    var v_focusBreaks: Int
    var v_focusBreakDurations_s: [Double]
    // Symptoms (0-10)
    var sym_headache: Int
    var sym_dizziness: Int
    var sym_nausea: Int
    var sym_fogginess: Int

    init(mode: String, distance_m: Double) {
        self.mode = mode
        self.distance_m = distance_m
        self.headStillPercent = 1.0
        self.headMotionEvents = 0
        self.h_duration_s = 0
        self.h_focusTimeRatio = 0
        self.h_focusBreaks = 0
        self.h_focusBreakDurations_s = []
        self.v_duration_s = 0
        self.v_focusTimeRatio = 0
        self.v_focusBreaks = 0
        self.v_focusBreakDurations_s = []
        self.sym_headache = 0
        self.sym_dizziness = 0
        self.sym_nausea = 0
        self.sym_fogginess = 0
    }
}
2) The test view (SwiftUI shell + ImmersiveSpace)
swift
Copy
Edit
// SmoothPursuitTestView.swift
import SwiftUI
import RealityKit
import SwiftData

struct SmoothPursuitTestView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    @State private var running = false
    @State private var useImmersive = false
    @State private var lastResultID: UUID?

    var body: some View {
        VStack(spacing: 24) {
            Text("Smooth Pursuit").font(.largeTitle).bold()
            Toggle("Immersive (dim background)", isOn: $useImmersive)
            Button(running ? "Running…" : "Start Test") {
                Task { await start() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(running)
        }
        .padding()
    }

    private func start() async {
        guard !running else { return }
        running = true
        if useImmersive {
            _ = await openImmersiveSpace(id: "SmoothPursuitSpace")
        } else {
            _ = await openImmersiveSpace(id: "SmoothPursuitSpace") // same space; we set AR/Immersive inside
        }
        // The ImmersiveSpace drives the session and will call dismiss when finished.
    }
}
Register the space in your app:

swift
Copy
Edit
// App entry or where you declare spaces
@main struct AppEntry: App {
    var body: some Scene {
        WindowGroup { SmoothPursuitTestView() }
        ImmersiveSpace(id: "SmoothPursuitSpace") {
            SmoothPursuitScene()
        }.immersionStyle(selection: .constant(.automatic), in: .full)
    }
}
3) The RealityKit scene with orchestration
swift
Copy
Edit
// SmoothPursuitScene.swift
import SwiftUI
import RealityKit
import ARKit
import SwiftData

struct SmoothPursuitScene: View {
    @Environment(\.dismissImmersiveSpace) private var dismiss
    @Environment(\.modelContext) private var ctx

    @State private var hud = HUDState()
    @State private var config = PursuitConfig()   // tweakable params
    @State private var result = SmoothPursuitResult(mode: "AR", distance_m: 1.5)

    var body: some View {
        RealityView { content, attachments in
            await SceneBuilder.setupScene(content: content,
                                          attachments: attachments,
                                          hud: $hud,
                                          config: config)
        } update: { content, attachments in
            // HUD updates handled via binding
        }
        .overlay(alignment: .topLeading) { HUDView(hud: hud) }
        .task { await runTest() }
    }

    private func runTest() async {
        // 1) Countdown
        hud.phase = .countdown(3)
        try? await Task.sleep(nanoseconds: 3 * 1_000_000_000)

        // 2) Orchestrate horizontal then vertical
        hud.phase = .running
        let orchestrator = SceneOrchestrator.shared
        orchestrator.reset(with: config)

        // Attach metrics sink
        orchestrator.metrics = MetricsSink()

        // Horizontal (two passes)
        await orchestrator.runPass(axis: .horizontal, passes: 2)

        // Vertical (two passes)
        await orchestrator.runPass(axis: .vertical, passes: 2)

        // 3) Gather metrics
        let m = orchestrator.metrics.finalize()
        result.h_duration_s = m.h.duration
        result.h_focusTimeRatio = m.h.focusRatio
        result.h_focusBreaks = m.h.breaksCount
        result.h_focusBreakDurations_s = m.h.breaksDurations

        result.v_duration_s = m.v.duration
        result.v_focusTimeRatio = m.v.focusRatio
        result.v_focusBreaks = m.v.breaksCount
        result.v_focusBreakDurations_s = m.v.breaksDurations

        result.headStillPercent = m.head.stillRatio
        result.headMotionEvents = m.head.motionEvents

        // 4) Symptom dialog (simple inline for now)
        await MainActor.run {
            hud.phase = .symptoms
        }
    }
}

// MARK: - Config / HUD

struct PursuitConfig {
    var zDistance: Float = 1.5
    var sweepDegrees: Float = 15         // ±deg
    var degPerSec: Float = 10            // speed
    var headWarnDeg: Float = 5
    var headEventDeg: Float = 8
}

@Observable final class HUDState {
    enum Phase { case idle, countdown(Int), running, symptoms, done }
    var phase: Phase = .idle
    var headHintVisible = false
    var timerText = ""
}

struct HUDView: View {
    @State var hud: HUDState
    var body: some View {
        HStack(spacing: 16) {
            if case .countdown(let n) = hud.phase {
                Text("Starting in \(n)…").padding(8).background(.thinMaterial).clipShape(.capsule)
            }
            if hud.headHintVisible {
                Text("Keep your head still").padding(8).background(.red.opacity(0.2)).clipShape(.capsule)
            }
        }.padding()
    }
}
4) Scene setup, focus attachment, animation, metrics
swift
Copy
Edit
// SmoothPursuitScene+Runtime.swift
import RealityKit
import SwiftUI
import simd
import ARKit

enum Axis { case horizontal, vertical }

@MainActor
enum SceneBuilder {
    static func setupScene(content: RealityViewContent,
                           attachments: RealityViewAttachments,
                           hud: Binding<HUDState>,
                           config: PursuitConfig) async {
        // Lighting & backdrop
        content.camera = .init()
        content.environment.lighting.intensityExponent = 1.0

        // Optional dim immersive backdrop: a dark sphere far away (toggle later)
        // ...

        // The orb entity
        let orb = ModelEntity(mesh: .generateSphere(radius: 0.012),
                              materials: [SimpleMaterial(color: .yellow, isMetallic: false)])
        orb.name = "orb"
        orb.generateCollisionShapes(recursive: false)
        content.add(orb)

        // Attach a tiny focusable SwiftUI view so we can observe gaze focus
        attachments.attach(to: orb) {
            FocusProbe(onFocusChanged: { isFocused in
                SceneOrchestrator.shared.gazeDidChange(isFocused: isFocused)
            })
            .frame(width: 0.02, height: 0.02) // ~2cm “hit” behind the orb
            .allowsHitTesting(false) // prevent taking pinches; just focus state
            .focusable(true) { focused in
                SceneOrchestrator.shared.gazeDidChange(isFocused: focused)
            }
        }

        // Start orchestrator with references
        SceneOrchestrator.shared.install(orb: orb,
                                         content: content,
                                         hud: hud,
                                         config: config)
    }
}

/// A transparent focus probe
struct FocusProbe: View {
    let onFocusChanged: (Bool) -> Void
    var body: some View {
        Color.clear
            .accessibilityHidden(true)
            .focusable(true) { focused in onFocusChanged(focused) }
    }
}

/// Metrics aggregation
final class MetricsSink {
    struct Segment {
        var duration: Double = 0
        var focusSeconds: Double = 0
        var breaksCount: Int = 0
        var breaksDurations: [Double] = []
        fileprivate var _focused = false
        fileprivate var _lastChange: CFTimeInterval = CACurrentMediaTime()
    }
    struct Head {
        var stillSeconds: Double = 0
        var totalSeconds: Double = 0
        var motionEvents: Int = 0
    }
    var h = Segment()
    var v = Segment()
    var head = Head()

    fileprivate var mode: Axis = .horizontal

    func setMode(_ m: Axis) {
        mode = m
        _setStart()
    }
    func tickFocus(isFocused: Bool) {
        let now = CACurrentMediaTime()
        var seg = (mode == .horizontal ? h : v)
        // transition
        if seg._focused != isFocused {
            let dt = now - seg._lastChange
            if seg._focused { seg.focusSeconds += dt }
            else if isFocused == false { /* was out of focus already */ }
            else { /* regained focus */ }
            // track breaks
            if !seg._focused && isFocused { /* end of break */ }
            if seg._focused && !isFocused { seg.breaksCount += 1 }
            seg._focused = isFocused
            seg._lastChange = now
        }
        if mode == .horizontal { h = seg } else { v = seg }
    }
    func tickHead(still: Bool, event: Bool, dt: Double) {
        head.totalSeconds += dt
        if still { head.stillSeconds += dt }
        if event { head.motionEvents += 1 }
    }
    func finalize() -> (h: Segment, v: Segment, head: Head) {
        let now = CACurrentMediaTime()
        // close segments
        for axis in [Axis.horizontal, Axis.vertical] {
            var seg = (axis == .horizontal ? h : v)
            let dt = now - seg._lastChange
            if seg._focused { seg.focusSeconds += dt }
            seg.duration += dt
            if axis == .horizontal { h = seg } else { v = seg }
        }
        // ratios computed by consumer
        return (h, v, head)
    }
    private func _setStart() {
        let now = CACurrentMediaTime()
        h._lastChange = now; v._lastChange = now
    }
}

/// Orchestrates motion & sampling
@MainActor
final class SceneOrchestrator {
    static let shared = SceneOrchestrator()
    private init() {}

    private weak var orb: Entity?
    private weak var content: RealityViewContent?
    private var hud: Binding<HUDState>!
    private var config: PursuitConfig!
    private var startCameraOrientation = simd_quatf()

    var metrics = MetricsSink()

    func install(orb: Entity, content: RealityViewContent, hud: Binding<HUDState>, config: PursuitConfig) {
        self.orb = orb
        self.content = content
        self.hud = hud
        self.config = config

        // Set initial transform (center)
        orb.transform.translation = SIMD3(0, 0, -config.zDistance)

        // Capture start head orientation
        if let cam = content.camera {
            startCameraOrientation = cam.transform.rotation
        }

        // Subscribe to per-frame updates
        content.scene.subscribe(to: SceneEvents.Update.self) { [weak self] ev in
            self?.update(frameTime: ev.deltaTime)
        }.store(in: &cancellables)
    }

    func reset(with config: PursuitConfig) {
        self.config = config
        metrics = MetricsSink()
    }

    func gazeDidChange(isFocused: Bool) {
        metrics.tickFocus(isFocused: isFocused)
    }

    func runPass(axis: Axis, passes: Int) async {
        metrics.setMode(axis)
        guard let orb, let content else { return }

        let z = -config.zDistance
        let A = config.zDistance * tan(config.sweepDegrees * .pi / 180)
        // positions
        let start: SIMD3<Float>
        let end: SIMD3<Float>
        switch axis {
        case .horizontal: start = [-A, 0, z]; end = [A, 0, z]
        case .vertical:   start = [0,  A, z]; end = [0, -A, z]
        }

        let sweepDeg: Float = config.sweepDegrees * 2 // -θ to +θ
        let durationPerSweep = Double(sweepDeg / config.degPerSec) // seconds

        orb.transform.translation = start
        for i in 0..<passes {
            await move(orb, to: end, duration: durationPerSweep)
            await move(orb, to: start, duration: durationPerSweep)
            // small settle gap
            try? await Task.sleep(nanoseconds: 150_000_000)
        }
    }

    private func move(_ e: Entity, to: SIMD3<Float>, duration: Double) async {
        await withCheckedContinuation { cont in
            e.move(
                to: Transform(translation: to),
                relativeTo: nil,
                duration: duration,
                timingFunction: .linear
            )
            // crude completion after duration
            Task { try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000)); cont.resume() }
        }
    }

    // — sampling / head checks
    private var cancellables: [Cancellable] = []
    private var headWarnDisplayed = false

    private func update(frameTime dt: Double) {
        guard let cam = content?.camera else { return }
        let q = cam.transform.rotation
        let delta = angleBetween(q, startCameraOrientation) // radians
        let deg = abs(delta * 180 / .pi)

        let still = (deg <= Double(config.headWarnDeg))
        let event = (deg >= Double(config.headEventDeg))
        metrics.tickHead(still: still, event: event, dt: dt)

        // HUD hint
        let shouldWarn = !still
        if shouldWarn != headWarnDisplayed {
            headWarnDisplayed = shouldWarn
            hud.wrappedValue.headHintVisible = shouldWarn
        }
    }

    private func angleBetween(_ a: simd_quatf, _ b: simd_quatf) -> Double {
        let dq = simd_mul(a, simd_conjugate(b))
        return Double(2 * acos(min(1, max(-1, dq.vector.w))))
    }
}
5) Simple symptom capture (post-test)
swift
Copy
Edit
// SymptomPromptView.swift
import SwiftUI

struct SymptomPrompt: View {
    let onDone: (_ headache: Int, _ dizziness: Int, _ nausea: Int, _ fogginess: Int) -> Void
    @State private var headache = 0
    @State private var dizziness = 0
    @State private var nausea = 0
    @State private var fogginess = 0

    var body: some View {
        VStack(spacing: 12) {
            Text("Symptoms (0–10 change from baseline)").bold()
            SymptomRow("Headache", value: $headache)
            SymptomRow("Dizziness", value: $dizziness)
            SymptomRow("Nausea", value: $nausea)
            SymptomRow("Fogginess", value: $fogginess)
            Button("Save") { onDone(headache, dizziness, nausea, fogginess) }
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }
}

private struct SymptomRow: View {
    let label: String
    @Binding var value: Int
    var body: some View {
        HStack {
            Text(label).frame(width: 120, alignment: .leading)
            Slider(value: Binding(get: { Double(value) },
                                  set: { value = Int($0.rounded()) }),
                   in: 0...10, step: 1)
            Text("\(value)")
                .monospacedDigit()
                .frame(width: 28)
        }
    }
}
Wire this view over your RealityView when hud.phase == .symptoms; on save, write to SmoothPursuitResult in SwiftData and dismissImmersiveSpace().

Implementation notes & options
Gaze focus on a 3D entity
Using a SwiftUI attachment that is .focusable and parented to the orb is a reliable way to get onFocusChange callbacks while the object moves. VisionOS automatically highlights focused items; you don’t need raw gaze rays.

Head motion
For clinical fidelity you can separately track yaw vs pitch by decomposing the quaternion (and only warn on yaw for horizontal, pitch for vertical), but the magnitude check above is a solid first cut.

Immersive vs AR
To “dim” in Immersive mode, surround the user with a large sphere at ~10–20 m radius with a very dark, low-contrast material and isUnlit = true so it doesn’t react to lighting.

Thresholds
Keep the numbers configurable (environment might limit available angles). Start with ±15° and 10°/s; collect pilot data, then tighten flags.

Persistence
Your main app already has SwiftData: save SmoothPursuitResult and link it to your assessment session entity. If arrays aren’t convenient in your schema, store break durations as a JSON string.

Unit tests / simulator
You can simulate focus by programmatically flipping gazeDidChange in unit tests. For head motion and pinch in CI, consider a “fake” camera/hand feed toggle.

Repos / building blocks to reference while implementing
Apple Hand Tracking sample (thumb–index distance pattern; useful for your convergence test later, but also a nice reference for joint update cadence).

RealityKit move/animate snippets (entity movement with move(to:duration:) and simple async chaining).

SwiftUI focus cookbook / WWDC focus sessions (for robust .focusable patterns and onFocusChange).

RealityUI (optional) to render the countdown chip / symptom panel as volumetric widgets.
