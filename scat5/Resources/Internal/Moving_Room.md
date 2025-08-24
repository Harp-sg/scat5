
al increased sway post-concussion vs baseline.
PMC

Scene

Environment: a cube room (3×3×3 m) centered on user with semi-transparent grid on inner faces. Build in Reality Composer Pro (one cube or 4–6 planes) and load as entity.
Apple Developer

Optic-flow motion (choose one, configurable):

Translate the room ±8–12 cm @ 0.2–0.4 Hz in AP and ML (sinusoid).

Or slowly rotate the room ~±1–2° @ 0.2 Hz (yaw/pitch).

Keep floor static (real floor visible) and move walls/horizon to maximize vection, minimize fall risk.

Volumetric UI

Floating panel (volumetric window) shows countdown, test time (e.g., 20 s), STOP button (backup to pinch). Use RealityUI for button/slider polish if desired.
Apple Developer
GitHub

Sway capture

At test start, set origin = current head pose. Each frame:

get (x,z) from camera.transform, append to buffer (timestamped).

compute smoothed derivatives; store peak sway, RMS, path length, 95% ellipse area (optional).

Instability event if |Δv| or step displacement > threshold (tune ≈ 5–7 cm or equivalent angular spike).

Auto-safety

If path length per second or instantaneous displacement > safety limit (e.g., 20 cm), freeze room → switch to neutral. Log “auto-pause”.

End of test

Store metrics; open symptom panel (dizziness, nausea, headache).

Provide clinician summary: “AP RMS sway +38% vs baseline; 2 instability events.”

Refs

Moving-room & optic-flow literature (postural sway changes under visual motion; concussion sensitivity).
PMC
+1

Moving_Room.md — Balance & Vestibular Assessment (Vision Pro)
0) Purpose & clinical basis
Create a controlled optic-flow perturbation (“moving room”) while the person stands on a solid floor. Quantify postural sway (AP/ML) using head pose from Vision Pro’s visual-inertial tracking. Concussed individuals typically exhibit greater sway under visual motion vs baseline, so this is sensitive to lingering deficits.
PMC
+1

“Moving room” = visual surrounds move while the support surface stays stationary; postural sway increases due to sensory conflict between vision and vestibular/proprioceptive input. VR makes this practical outside a lab.
PMC

Why head-pose is valid: Head- or HMD-mounted IMUs/pose streams produce sway metrics that correlate with force-plate measures in quiet stance and under visual conditions; recent validation studies support IMU/HMD use for postural assessment.
PMC
+1
Europe PMC

1) Mode: immersive vs passthrough (what to ship)
Default: Passthrough AR with semi-transparent walls. Rationale: people retain a stable, real floor/room view (safer), while we move virtual walls/horizon to induce vection (this matches the classical definition: visual surround moves, support fixed).
PMC

Clinic option: Full immersive (toggle in settings) for maximal optic flow when a spotter is present. In either mode, keep the floor/static ground plane visually stable to reduce fall risk.

Implementation: visionOS volumetric window hosting a RealityView scene for walls + metrics HUD.
Apple Developer
+1

2) Patient & assessor flow (independent module)
Environment check (volumetric panel): “Clear 2×2 m floor. Stand hip-width apart, arms at sides. A spotter is recommended.”

Controls: Start, Amplitude slider (8–12 cm), Frequency slider (0.2–0.4 Hz), Mode (Translate / Rotate), Duration (20 s default).

Calibration (1 s): capture head pose origin; compute baseline noise.

Countdown (3→1) with soft tone.

Stimulus ON (20 s)

Passthrough visible. Semi-transparent grid walls oscillate (AP ±X cm; optional ML).

A large STOP button and pinch-and-hold (≥1.5 s) bail-out are active at all times.

Stimulus OFF → Symptom panel: rate dizziness, nausea, headache (0–10).

Summary card: headline metrics and flags, auto-saved to SwiftData.

(All timings/parameters are configurable in the panel to support research protocols.)

3) Volumetric UI (exact layout)
One volumetric window (≈ 60–80 cm wide panel positioned 1.2–1.5 m in front).

Top bar: module title, gear icon → settings popover.

Main column:

Status row: Ready / Calibrating / Running / Paused / Completed + time remaining.

Controls row (pre-test): dropdowns/sliders:

Stimulation: Translate | Rotate

Axis: AP | ML | Both

Amplitude (cm): 8–12 (default 10)

Frequency (Hz): 0.2–0.4 (default 0.3)

Duration (s): 10–60 (default 20)

Start (primary), STOP (secondary, always visible).

Post-test panel (modal sheet in same window):

Symptom pickers (0–10): Dizziness, Nausea, Headache.

Save → Summary card (metrics, flags, time, params).

Use SwiftUI in a volumetric window and render the moving room in a RealityView behind/around it. For polished 3D controls (e.g., 3D buttons/sliders floating beside the user), you can optionally integrate RealityUI, but standard SwiftUI in a volume suffices.
Apple Developer
+1
GitHub

4) Scene graph & assets
Root Anchor at head pose at t0 (calibration).

Room: 3×3×3 m cube surrounding user (inner-facing quads) with semi-transparent grid material (~40–60% opacity). Build in Reality Composer Pro, export as .reality or .usd.
Apple Developer

Alternative: generate planes at runtime using RealityGeometries (denser meshes for smooth motion/lighting).
The Swift Package Index
GitHub

Motion driver (see §5): sinusoidal translation ±8–12 cm at 0.2–0.4 Hz OR slow rotation ±1–2° at 0.2 Hz around yaw/pitch. (Keep floor visually stable.) Evidence: such optic-flow perturbations provoke sway and are used in balance rehab/assessment.
PMC
Frontiers

HUD: minimal markers only; the real floor remains visible.

Optional: add a distant horizon line to amplify vection (increases visual motion cue salience).
PMC

5) Motion profiles (exact math)
A) Translational optic-flow (recommended default)
For AP motion (z-axis), position of walls entity relative to origin:

cpp
Copy
Edit
z(t) = A * sin(2π f t)      // A in meters (0.08–0.12), f in Hz (0.2–0.4)
x(t) = 0 (or B * sin(2π f t + φ) for ML)
y(t) = 0
Use SceneEvents.Update to update transform per frame, or a looping AnimationResource with a linear curve.

Ramp-in: multiply first 1.5 s by r(t)=min(1, t/1.5) to avoid a startle.

B) Rotational optic-flow (alternative)
For small-angle yaw oscillation:

lua
Copy
Edit
θyaw(t) = θmax * sin(2π f t) // θmax = 1–2° (0.017–0.035 rad), f = 0.2 Hz
Apply rotation to the room parent (keep floor plane static/hidden).

6) Pose stream & sway metrics
Sampling & transforms
At 60–90 Hz, read head pose from ARKit: ARSession.currentFrame?.camera.transform → 4×4 matrix; extract position (x, y, z) and orientation (quaternion).
Apple Developer
+1

Define origin at calibration t0: p0 = (x0, z0). Compute relative horizontal displacements:
dx = x - x0, dz = z - z0. (AP=+z anterior; ML=+x right.)

Filtering
Apply exponential moving average (EMA) to positions to reduce VIO jitter:

csharp
Copy
Edit
p_filt[t] = α * p_raw[t] + (1-α) * p_filt[t-1]
α ≈ 0.2 for 60 Hz (tune based on jitter vs responsiveness)
Metrics (compute over test duration T)
Peak AP sway (cm): 100 * max(|dz|).

Peak ML sway (cm): 100 * max(|dx|).

RMS sway (cm): 100 * sqrt( mean( dz^2 ) ) (AP) and likewise ML.

Path length (cm): sum over frames Σ 100 * sqrt(Δdx^2 + Δdz^2).

95% ellipse area (cm²) (optional): from covariance Σ of [dx dz], area = 5.991 * π * sqrt(λ1) * sqrt(λ2) * 100^2 (λi eigenvalues).

Instability events: if step_disp = sqrt(Δdx^2 + Δdz^2) > 0.05–0.07 m OR if instantaneous jerk |Δv/Δt| exceeds tuned threshold → count++, store timestamps.

These are standard posturography surrogates; wearable/HMD studies show good correspondence to force-plate sway under visual conditions.
PMC
+1

7) Safety logic
Bail-out (always-on):

Pinch-and-hold ≥1.5 s (hand-tracking joint distance threshold) → stop stimulus, switch room static, show “Paused”.

STOP button in volumetric panel (gaze + pinch).

Auto-pause if either:

Instantaneous displacement > 0.20 m (20 cm), or

Path-length-rate > 0.6 m/s, or

Head-yaw rate > 120°/s (suggests unintended head scanning).

On auto-pause: freeze motion, darken grid to 80% opacity, log auto-pause event and reason, show Resume option.

Visual motion can strongly perturb posture; conservative thresholds + clear floor and spotter minimize fall risk while preserving sensitivity.
PMC

8) Results, storage, and flags
Summary card (shown to clinician & saved)
Parameters: mode, axis, amplitude, frequency, duration.

Metrics: AP/ML peak (cm), RMS (cm), path length (cm), instability events (#), auto-pause (Y/N).

Delta vs baseline (if baseline exists): e.g., “AP RMS +38% vs baseline.”

Symptom change (0–10 scales).

Interpretation rule-of-thumb (non-diagnostic): increase >30–50% vs baseline under optic flow + symptom provocation suggests persisting sensory reweighting deficit; consider vestibular/oculomotor follow-up. (Tune with your cohort.)

SwiftData sketch
swift
Copy
Edit
@Model final class MovingRoomResult {
  @Attribute(.unique) var id = UUID()
  var userId: UUID
  var date: Date

  // Stim params
  var mode: String      // "translate" | "rotate"
  var axis: String      // "AP" | "ML" | "both"
  var amplitudeCm: Double
  var frequencyHz: Double
  var durationSec: Int

  // Metrics
  var apPeakCm: Double
  var mlPeakCm: Double
  var apRmsCm: Double
  var mlRmsCm: Double
  var pathLenCm: Double
  var ellipseAreaCm2: Double?
  var instabilityEvents: Int
  var autoPaused: Bool

  // Symptoms
  var dizziness: Int
  var nausea: Int
  var headache: Int

  // Baseline deltas (optional)
  var apRmsDeltaPct: Double?
  var mlRmsDeltaPct: Double?
}
9) Implementation details (VisionOS/RealityKit)
9.1 Volumetric window + RealityView
Create a volumetric scene with SwiftUI window style .volumetric(). Place a RealityView behind your SwiftUI controls.
Apple Developer
+1

9.2 Room construction & motion
Load RoomEntity (cube with inner quads) from Reality Composer Pro OR generate with RealityGeometries planes (denser vertex grid → smoother shading).
Apple Developer
The Swift Package Index

On SceneEvents.Update, compute t += dt, set room transform with sinusoid (see §5). For rotate mode, apply small yaw/pitch oscillation.

9.3 Head pose stream
On SceneEvents.Update, read ARSession.currentFrame?.camera.transform each frame. Use Apple docs for ARCamera.transform and ARSession.currentFrame.
Apple Developer
+1

Extract (x,z), update EMA, append to ring buffer with timestamp.

9.4 Bail-out gesture & STOP
Gesture (preferred): enable hand tracking; compute thumb–index distance, detect pinch-held ≥1.5 s → pauseStimulus(). (Pattern lifted from Apple’s hand tracking samples.)

STOP button: SwiftUI Button in the volumetric window for gaze+pinch.

9.5 Gaze hints (optional)
For any focusable 3D buttons in-scene, add HoverEffectComponent to show system gaze highlight.
Apple Developer
+1

9.6 Safety & ramp
Ramp-in and ramp-out to avoid sudden motion: multiply A or θ by a 1.5 s envelope at start/end.

Enforce auto-pause thresholds (see §7) during update loop.

9.7 Compute metrics
After durationSec, compute metrics from the buffer (see §6). Keep raw series for research (opt-in).

9.8 Baselines
Provide a “Baseline (no motion)” mode (static walls, 20 s). Save metrics as baseline per user. Summary compares test vs baseline.

10) QA checklist (coding agent)
 Scene loads; grid walls visible; floor is real passthrough.

 Start → 1 s calibration → countdown → motion starts smoothly.

 Bail-out works (pinch-hold, STOP).

 Auto-pause triggers when thresholds exceeded.

 Metrics stable on repeated trials with no motion (noise < ~0.3 cm RMS).

 Symptom panel selection via gaze+pinch.

 SwiftData save; summary renders; deltas vs baseline correct.

11) Repos & docs for scaffolding
Apple (visionOS)

Volumetric windows & RealityView — official sample & docs. Use this to structure your volumetric panel + RealityView scene.
Apple Developer
+1

HoverEffectComponent — add gaze highlight to 3D controls if you place any inside the scene.
Apple Developer

ARCamera.transform & ARSession.currentFrame — head pose source.
Apple Developer
+1

Open-source (RealityKit utilities)

RealityUI (UI widgets & animations in 3D) — speed up building Start/Stop and settings controls as volumetric 3D controls if you prefer in-scene UI.
GitHub
The Swift Package Index

RealityGeometries (extra meshes; denser planes) — build the room procedurally if you don’t want to ship assets.
The Swift Package Index
GitHub

Awesome-RealityKit collection — more RealityKit helper packages if you need focus entities, actions, etc.
GitHub

Clinical/VR background (for your README / methods)

VR concussion review; moving-room paradigm & optic flow.
PMC

Moving-room postural sway experiments overview.
PMC

Optic-flow perturbations in VR rehab.
Frontiers

IMU/HMD sway validity vs force plate.
PMC
+1

12) Medical notes & wording (app copy)
Pre-test warning: “This visual test can make you feel unsteady. Keep a clear area. If you feel unsafe, pinch and hold to stop.”

During test: “Stand still and look ahead normally.”

Post-test: “Please rate any symptom change (0–10).”

Interpretation (for clinicians in summary):
“Optic-flow sway was ↑X% vs baseline (AP RMS, ML RMS). Optical perturbations are known to increase sway when sensory reweighting is impaired after concussion; consider vestibular/oculomotor follow-up if increases are marked or symptoms provoked.”
PMC

13) Interfaces for integration
swift
Copy
Edit
protocol MovingRoomDelegate: AnyObject {
  func movingRoomDidComplete(_ result: MovingRoomResult)
  func movingRoomDidAutoPause(reason: String, at time: TimeInterval)
}
Present as an independent module from your SCAT-5 menu; it persists results to SwiftData and calls the delegate.

Why this leverages Vision Pro “justifiably”
Volumetric UI makes it safe: static real floor + controllable moving walls (hard to replicate on flat screens).
Apple Developer

Visual-inertial head pose enables force-plate–like sway metrics without external hardware.
PMC
+1

The moving-room sensory conflict is a classic, lab-validated way to unmask deficits that routine exams miss; Vision Pro delivers it portably with reproducible parameters (amplitude/frequency/duration).
PMC



