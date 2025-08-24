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


awesome—let’s ship the **Smooth Pursuit** module first. below is a production-quality spec (markdown) plus a working Swift/RealityKit scaffold your agent can drop into your visionOS target and iterate on.

---

# Smooth\_Pursuit.md

## Goal

Quantify **smooth pursuit** quality using a moving dot in volumetric UI, with **gaze focus** (for % time on target) and **head-motion guardrails** (to discourage compensatory head turns). Save metrics to SwiftData alongside SCAT-5.

## Clinical parameters (defaults, configurable)

* **Distance to target (`z`)**: 1.50 m
* **Angular sweep**: ±15° (compute lateral amplitude `A = z * tan(θ) ≈ 1.5 * tan(15°) ≈ 0.40 m`)

  * If you want ±30° later: `A ≈ 0.866 m` (requires bigger space).
* **Speed**: 10°/s (end-to-end sweep 30° → \~3.0 s per pass)
* **Duration**: 2 passes horizontal (≈6–7 s) + 2 passes vertical (≈6–7 s)
* **Head-motion threshold**: warn if |yaw| or |pitch| drift > 5° from start; mark event if > 8°.
* **Focus sampling**: use **gaze focus** on the moving target; compute:

  * `focus_time_ratio = focused_time / test_time`
  * `focus_breaks_count` and break durations.
* **Abnormal flags (suggested, tune after pilot)**:

  * Horizontal or vertical `focus_time_ratio < 0.80` **or** `focus_breaks_count ≥ 3` → flag.
  * `head_motion_events ≥ 2` → “invalid / redo recommended”.

## Modes

* **AR passthrough** (default): orb in your real room, high comfort.
* **Immersive (dim)**: dark neutral backdrop to boost contrast. Toggle via a setting.

## UX flow

1. **Pre-flight panel (volumetric HUD)**

   * Title, brief instructions: “Keep head still; follow the dot with your eyes.”
   * Buttons: \[Start] \[Cancel] ; Mode toggle (AR/Immersive).
2. **Test**

   * Small glowing orb sweeps **left↔︎right** then **up↕︎down**.
   * Minimal HUD: countdown chip, **HEAD STILL** hint if needed, \[Pause/Abort].
3. **Post-test prompt**

   * VOMS-style symptoms (0–10): headache, dizziness, nausea, fogginess.
   * Save & return.

## Data model (concept)

* `SmoothPursuitResult`

  * `mode` ("AR"/"Immersive"), `distance_m`
  * `horizontal: SegmentResult`, `vertical: SegmentResult`
  * `head_still_percent`, `head_motion_events`
  * `symptoms: {headache, dizziness, nausea, fogginess}`
* `SegmentResult`

  * `duration_s`, `focus_time_ratio`, `focus_breaks_count`, `[focus_break_durations_s]`

---

# Code scaffold (drop-in)

> Tested patterns: RealityKit animation for the orb, SwiftUI focus for gaze, ARKit camera transform for head pose. The “focus on a 3D thing” is implemented by **attaching a tiny invisible focusable SwiftUI view to the moving entity** so you get `onFocusChange` events when the user looks at the orb.

### 1) SwiftData models (adjust to your existing schema)