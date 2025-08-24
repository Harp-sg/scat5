
VOR_Balance.md
Module: Balance & Vestibular
Subtest: VOR (Vestibulo-Ocular Reflex) while standing
Platform: visionOS (Apple Vision Pro) — SwiftUI + RealityKit + ARKit
UI style: Volumetric UI (window/volume + RealityView)
Default modality: Passthrough AR (safer for posture tasks); optional “dimmed immersive” variant for clinics. 
Apple Developer
+1

1) Clinical rationale & targets
Purpose. Screen whether a patient can maintain fixation on a static target while making standardized head turns, and whether this destabilizes posture or provokes symptoms (dizziness, nausea, headache, fogginess).

Protocol anchor (VOMS). VOMS specifies horizontal and vertical VOR with ~20° amplitude at a metronome ~180 bpm (≈3 Hz) for 10 reps; symptom ratings recorded after each component. We’ll start with horizontal at 1–2 Hz for 10 s (clinically gentler; configurable). 
impacttest.com
Physiopedia
PMC

Why it matters. VOMS shows good internal consistency and clinical utility for concussion; dizziness provocation and fixation difficulty during VOR are common findings. Recent military outpatient data: excellent internal consistency, moderate–good test–retest reliability (note ~22% false-positive rate → this is adjunctive, not diagnostic). 
PMC
Academic Oxford

Primary outcomes

Gaze-on-target % during head turns (proxy for gaze slips).

Head yaw rate (°/s) and turn frequency (Hz), to confirm the patient actually did the task to spec.

Postural sway vs standing baseline (RMS/AP-ML, path length).

Symptom delta (0–10 for dizziness, headache, nausea, fogginess).

2) Modality: Passthrough AR vs Immersive
Default: Passthrough AR with a neutral static “frame” (no optic flow). Safer posture; clear situational awareness.

Optional: Dimmed immersive background for clinics to suppress visual clutter (no moving elements).

Rationale: Apple HIG: prioritize comfort; in Full Space avoid motion that causes discomfort. We use static scene, minimal visuals, and keep UI centered in natural viewing zones. 
Apple Developer
+2
Apple Developer
+2

3) User flow (patient + clinician)
Safety screen (volumetric panel)

“Stand with feet shoulder-width apart on a clear floor. A spotter is recommended.”

Checks: Battery pack secured; cable not taut; shoes on; glasses if worn.

Buttons: Begin, Cancel.

Calibration (3 s)

Collect quiet-stance head pose to define origin and baseline sway noise.

Instructions (panel + TTS)

“Keep your eyes on the dot. Turn your head left–right about 20° at about once per second for 10 seconds. Bail-out: pinch-and-hold.”

Metronome (optional): audio tick at target rate (1.5 Hz default).

Practice (3 s)

Live speed bar shows yaw rate; “a bit faster/slower” text if out of band.

Test run (10 s)

Start tone; timer HUD; fixation dot visible.

Live gaze indicator (dot glow when focused); speed bar and frequency text.

Bail-out stops immediately.

Symptoms panel (volumetric)

0–10 sliders for Dizziness, Headache, Nausea, Fogginess (default 0, 0.5 steps).

Summary card (for clinician)

“VOR: gaze-on 78%, yaw 160°/s @ 1.7 Hz, AP-RMS +25% vs baseline. Dizziness +3.”

Save & Close → persists to SwiftData and returns to module menu.

4) Visual & interaction design
4.1 Fixation target
Dot at 2.0 m straight ahead, physical size ≈ 25 mm (visibility without being too salient).

Material: white core, faint outer ring; HoverEffectComponent attached for system gaze glow. 
Apple Developer

Hit region: sphere collider radius 3 cm for robust focus.

4.2 Volumetric UI (window/volume)
Top center: Timer (mm:ss), metronome icon if enabled.

Center right: Speed bar (0–300°/s), green band 120–240°/s.

Bottom: “Pinch-and-hold to STOP” reminder + small STOP button.

Colors: neutral/dim to reduce distraction; high contrast for numbers.

Placement: keep UI within ±15° of primary gaze to minimize head/neck strain. 
Uxcel

4.3 Audio
Metronome (optional): short tick (≤50 ms), ~60–65 dB SPL equivalent.

Start/End tones distinct and soft.

Accessibility: supports TTS for instructions (Speech framework). 
Apple Developer

5) Implementation (visionOS native)
5.1 Architecture
SwiftUI volumetric window hosts a RealityView (scene) + HUD overlays. 
Apple Developer
+1

RealityKit scene contains: fixation entity, optional floor marker, minimal neutral “frame”.

ARKit provides device pose (world transform) each frame to compute yaw & sway. 
Apple Developer

5.2 Entities & components
FixationDotEntity: ModelEntity (sphere or flat disc billboard).

HoverEffectComponent(style: .highlight) → system gaze glow. 
Apple Developer

CollisionComponent for gaze hit tests.

HUD: SwiftUI overlays in the volume (timer, speed bar, messages).

Bail-out:

Primary: STOP SwiftUI button (gaze + pinch).

Secondary: pinch-and-hold via HandTrackingProvider (distance thumb–index < threshold for ≥1.5 s). 
Apple Developer

5.3 Pose & signals (per-frame loop)
Get device transform: frame.camera.transform (4×4). If you prefer anchors, use ARKit DeviceAnchor for world pose access (RealityKit .head anchor doesn’t expose transform directly). 
Apple Developer
Stack Overflow

Convert transform to yaw-pitch-roll. For yaw (Z-up world assumed):

cpp
Copy
Edit
// From rotation matrix R:
yaw   = atan2(R[1,0], R[0,0])    // radians → convert to degrees
pitch = asin(-R[2,0])
roll  = atan2(R[2,1], R[2,2])
Yaw rate (°/s): central difference:
ω_yaw[t] = (yaw[t] - yaw[t-1]) / Δt → unwrap angles to avoid 360° jumps.

Frequency (Hz): zero-crossings of yaw (±epsilon) / (2·duration) or peak-to-peak intervals; smooth with moving median.

5.4 Gaze-on-target %
RealityKit gives visual hover (via HoverEffect) but no direct callback. Two robust patterns:

SwiftUI focusable overlay: place an invisible focusable view aligned with the dot; use .focusable(true, onFocusChange:) to timestamp focused/unfocused.

Raycast proxy: cast from head forward to dot collider each frame and consider “focused” if within small angular cone (e.g., ≤2–3°).

Note: Dev forums confirm HoverEffect is visual only; use a focusable SwiftUI view or custom hit/raycast for programmatic events. 
Apple Developer
Stack Overflow

5.5 Sway metrics (postural)
Track head position (x,z) w.r.t. origin captured at calibration.

Filtering: low-pass α≈0.1 (exponential smoothing) to reduce sensor noise.

Metrics:

RMS sway (AP=z, ML=x) over 10 s.

Path length = Σ‖p[t]-p[t-1]‖.

Optional 95% ellipse area from covariance of (x,z).

Justification: IMU/head-pose measures are widely used surrogates for postural stability (not a force plate, but directionally sensitive and practical). 
PMC
SAGE Journals

5.6 Real-time coaching
Speed bar: live |ω_yaw|.

Green band: 120–240 °/s (~1–2 Hz with 20° amplitude).

If outside band for >500 ms: show “Turn a bit faster/slower”.

Gaze slips: if not focused for >150 ms, flash a “Keep eyes on the dot” tip.

5.7 Timing
Calibration: 3 s (collect baseline sway noise).

Practice: 3 s.

Test: 10 s (configurable 8–15 s).

Cooldown: 1 s before symptom panel.

5.8 Bail-out & auto-safety
Pinch-and-hold ≥1.5 s or hit STOP → freeze scene to neutral; record “aborted by user”.

Auto-pause if:

|x| or |z| displacement > 25 cm from origin (fall risk), or

instantaneous |ω_yaw| > 400 °/s (excessive rotation).

On auto-pause, fade audio, show “Paused for safety”.

6) Data model (SwiftData)
swift
Copy
Edit
@Model final class VORBalanceResult {
  var id = UUID()
  var userId: UUID
  var startedAt: Date
  var durationSec: Double

  // Head motion
  var meanYawRate_dps: Double
  var medianYawRate_dps: Double
  var freq_Hz: Double
  var yawAmplitude_deg: Double   // peak-to-peak/2

  // Fixation
  var gazeOnPct: Double          // 0–100
  var gazeSlipCount: Int
  var meanSlipDuration_ms: Double

  // Sway (vs standing baseline captured same session)
  var apRMS_cm: Double
  var mlRMS_cm: Double
  var pathLen_cm: Double
  var apRMS_deltaPct: Double     // relative to baseline
  var mlRMS_deltaPct: Double

  // Symptoms (delta from pre-test if you capture it)
  var dizzinessDelta: Int   // 0..10
  var headacheDelta: Int
  var nauseaDelta: Int
  var fogginessDelta: Int

  // Compliance & safety
  var completed: Bool
  var abortedReason: String?  // user_stop, auto_pause_threshold, etc.
}
Persist under the parent Assessment entity with timestamps to enable longitudinal trending.

7) Scoring & interpretation (defaults; clinician-tunable)
Adequate effort: median yaw rate in 120–240 °/s AND freq 0.9–2.2 Hz.

Gaze stability: gaze-on ≥85% considered normal; 70–85% borderline; <70% abnormal (proxy; tune with your pilot data).

Sway coupling: AP-RMS +≥20% vs standing baseline suggests vestibular coupling; flag if +≥35%.

Symptoms: any +≥2 on dizziness OR +≥4 total suggests provocation (VOMS-consistent).

Report always states this is an adjunctive screen (VOMS-style), not a standalone diagnosis. 
PMC

8) QA, validation, and medical notes
Bench validation:

Compare computed yaw rate/frequency against a motion rig (known sinusoid).

Validate gaze-on % logic using scripted gaze proxy (focus overlay) to ensure thresholds behave.

Clinical pilot (n≈20–40): collect healthy baseline variability; refine thresholds.

Limitations: visionOS does not expose raw eye vectors; we use focus/hover & ray proxy → gaze-on % is a surrogate. Document this clearly. 
Apple Developer

Comfort & safety: keep visuals static; avoid optic flow in this subtest; follow visionOS motion comfort guidance. 
Apple Developer
+1

Regulatory stance: research/adjunctive; not a diagnostic device. Include clinician guardrails and symptom bail-outs.

9) Pseudocode (key loops)
swift
Copy
Edit
// Setup
let session = ARKitSession()
let worldTracking = WorldTrackingProvider()
try await session.run([worldTracking])
let originPose = Pose.from(session.currentFrame!) // at calibration end

// Per-frame update
@MainActor
func update(frame: ARFrame) {
    // 1) Pose → yaw
    let R = frame.camera.transform.rotationMatrix
    let yawDeg = radiansToDegrees(atan2(R[1,0], R[0,0]))
    let dt = frame.timestamp - lastTimestamp
    let yawRate = unwrap(yawDeg - lastYawDeg) / dt  // °/s
    yawLP = lowPass(yawRate, alpha: 0.1)
    updateSpeedBar(yawLP)

    // 2) Frequency (zero-crossing or peak detector)
    freq = freqEstimator.update(yawDeg, timestamp: frame.timestamp)

    // 3) Sway (x,z relative to origin)
    let p = positionXZ(frame.camera.transform, relativeTo: originPose)
    sway.update(p)

    // 4) Gaze-on (either focus overlay events or ray proxy)
    let onTarget = rayProxyIsOnFixationDot(frame)
    gaze.update(onTarget, timestamp: frame.timestamp)

    // 5) Safety
    if sway.displacementFromOrigin() > 0.25 { autoPause("sway_limit") }
    if abs(yawLP) > 400 { autoPause("excess_yaw_rate") }
}
10) Repos & docs to model against
HoverEffectComponent (RealityKit) – gaze highlight on entities (dot). 
Apple Developer

Volumetric windows & RealityView – idiomatic volumetric UI. 
Apple Developer

Head/device transform sample – get head pose reliably. 
Apple Developer

ARKit in visionOS – device pose & anchors API. 
Apple Developer

Hand tracking provider – for pinch-and-hold bail-out detection. 
Apple Developer

Gaze callback limitation threads – plan for focus overlay or ray proxy. 
Apple Developer
Stack Overflow

11) Immersive vs AR: final call
Ship default in Passthrough AR. It’s medically sufficient and safer for balance tasks.

Offer a “Dimmed Immersive” toggle (no motion; dark matte background) for clinics that want maximal visual control. Both comply with HIG comfort guidance (no optic flow; minimal motion). 
Apple Developer

12) Copy blocks (ready for UI)
Safety
“Make sure the floor around you is clear. Stand with feet shoulder-width apart. A spotter is recommended. Press Begin when ready.”

Instruction
“Keep your eyes on the dot. Turn your head left and right about 20° at about once per second for 10 seconds. Pinch-and-hold to stop anytime.”

Coaching
“A bit faster.” / “A bit slower.” / “Keep eyes on the dot.”

Symptoms
“Rate any increase since before this test: Dizziness, Headache, Nausea, Fogginess (0–10).”

13) Deliverables checklist (for the agent)
VORBalanceView.swift (volumetric window + HUD).

VORBalanceScene.swift (RealityView content; fixation dot entity).

PoseStream.swift (ARKit session, pose, yaw math, filters).

GazeFocusProxy.swift (focusable overlay or ray proxy).

SwayMetrics.swift (RMS, path length, ellipse).

HandBailout.swift (pinch-and-hold via HandTrackingProvider).

VORBalanceResult.swift (SwiftData @Model).

Unit tests for yaw math, zero-crossing frequency, and path length.

Citations (key)
HoverEffectComponent (gaze highlight on entities). 
Apple Developer

Volumetric windows / RealityView patterns. 
Apple Developer

Head/device transform sample; ARKit in visionOS. 
Apple Developer
+1

Hand tracking provider (pinch). 
Apple Developer

Gaze programmatic limitation & workarounds. 
Apple Developer
Stack Overflow

VOMS protocol & symptom recording (VOR specifics). 
impacttest.com
Physiopedia

VOMS validity & reliability (adjunctive nature). 
PMC
Academic Oxford

Motion/comfort guidance for immersive spaces. 
Apple Developer

IMU/head-pose as sway surrogate (context & cautions). 
PMC
SAGE Journals

