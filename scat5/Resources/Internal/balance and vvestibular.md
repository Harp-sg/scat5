Goal
Quantify balance/vestibular deficits after concussion using volumetric UI and objective sway metrics captured from Vision Pro (pose/IMU), plus symptom provocation ratings.

Sub-tests (independent modules in a menu):

Moving Room (optic-flow sway)

Static Stance (enhanced BESS)

VOR Balance (fixation + head turns)

Step-in-Place (optional)

VisionOS modality
Default passthrough AR with a semi-transparent virtual room (safety). Optional full immersive for clinics. Use volumetric window for instructions, progress, and symptom panel. 
Apple Developer

Core metrics

Sway AP/ML (cm): peak-to-peak, RMS, path length (sum of frame-to-frame horizontal/forward displacement).

95% ellipse area (optional): covariance of (x,z) head positions.

Instability events: jerk spikes or threshold crossings.

VOR compliance: head yaw rate (°/s) & % time gaze on fixation.

Symptoms: 0–10 dizziness, nausea, headache (pre/post).

Pipelines

Head pose stream (60–90 Hz): ARSession.currentFrame.camera.transform → extract position (x,y,z) + yaw/pitch/roll. Low-pass with α≈0.1; compute deltas per frame. 
Apple Developer

Gaze-on-target: add HoverEffectComponent to fixation dot; log focused/unfocused timestamps. 
Apple Developer

Volumetric UI: RealityView scene graph for 3D content; SwiftUI panel (RealityUI components optional) for controls/symptoms. 
Apple Developer
GitHub

Tech stack

Swift 5.9+, visionOS (RealityView + ImmersiveSpace), RealityKit, ARKit world tracking, SwiftUI, Reality Composer Pro for assets, optional RealityUI + RealityGeometries. 
Apple Developer
GitHub
The Swift Package Index

Safety

Pre-test checklist panel: clear floor, spotter recommended.

Bail-out: pinch-and-hold ≥1.5s or say “Stop” (if you add Speech) → immediately freeze scene to static neutral.

Auto-pause if sway exceeds threshold or head-yaw rate > target by >50%.

Acceptance criteria

Each sub-test completes within target duration, stores metrics to SwiftData, renders a clinician-readable summary card, and supports bail-out.

Feature 2: Balance and Vestibular Assessment
Description & Rationale: Balance deficits are a hallmark of concussion, yet traditional balance tests (e.g. the Balance Error Scoring System, BESS) can be subjective and have limited sensitivity. This feature will use Vision Pro’s spatial capabilities to conduct objective balance and vestibular function tests. By creating dynamic visual environments and using the headset’s motion sensors, we can challenge the user’s balance in ways that reveal subtle impairments. We will also assess the vestibular system (inner ear balance) in conjunction with vision – important because concussed patients often experience dizziness or poor balance when visual and vestibular inputs conflict. Test Scenarios: Planned sub-components of this module include:
“Moving Room” Balance Test: This concept, adapted from research, involves a visual scene that moves around the user to induce the sensation of movement. In our implementation, the user will stand up (if they are able) wearing the Vision Pro. The device will display a virtual environment aligned with the real world (for safety, a semi-transparent grid or walls in the periphery). We will then subtly move the virtual horizon or walls forward/backward and side-to-side. If a user’s balance is impaired (as in recent concussion), this optic flow can cause them to sway or stumble even if they’re on solid ground. We will measure the user’s postural sway during this test.
Static Stance with Metrics: We simulate the BESS stance tests but enhance them with sensor measurement. For example, instruct “Stand with feet together, eyes open, for 20 seconds” (then one foot, etc., possibly eyes closed variant). The Vision Pro’s accelerometer and gyroscope data can quantify how much the user wobbles. We can compute a sway index (e.g. total angular movement or translational variance of the headset). Instead of a human counting foot lift errors, we have an objective measure of balance stability. This is done with the IMU data at (say) 60 Hz and calculating deviation.
Head Movement & Gaze Stability (VOR) – dynamic balance: This overlaps with Feature 1’s VOR test but here we do it in context of balance. For instance, the user stands and quickly rotates their head left-right while focusing on a static object (testing the vestibulo-ocular reflex while upright). We monitor if they can do this without losing balance or breaking gaze.
Tandem Gait or Step in Place: If time and complexity permit, we can have the user do a simple gait test – e.g., walk forward a few steps or march in place while wearing Vision Pro. The device’s inside-out tracking can potentially detect movement trajectory. However, since walking with a headset can be risky and Vision Pro is tethered to a battery, we may skip actual walking. Instead, we might simulate a step-in-place test: ask the user to march in place (knees up) with eyes open vs closed (a traditional vestibular test). Vision Pro’s downward cameras could possibly track leg movement, but more reliably, the head bobbing pattern can indicate if the user is marching consistently or drifting.
Technical Implementation:
Immersive Environment: We will create a virtual environment using RealityKit that can surround the user. For simplicity and performance, this could be a large cube or sphere with a textured grid or scenery. Alternatively, a basic room mesh can be procedurally generated. We can then animate this entire environment entity to translate subtly along an axis (e.g. using Transform interpolation or directly updating position each frame to create a slow oscillation). The user’s real floor will still be there; we are not physically moving them, just providing a visual stimulus.
Spatial Tracking for Sway: To quantify sway, we use ARKit’s tracking of the device in the room. When the user starts, we set a reference origin (perhaps an anchor at their initial head position). As the test runs, each frame we get the headset’s position relative to that anchor. The difference gives us how much the user sways (particularly in the anterior-posterior (Z) and lateral (X) directions). A concussed user might sway more in response to the moving room. We’ll compute metrics like peak sway (cm) and sway path length. If the sway exceeds a safety threshold (e.g. moving room is causing too much instability), the system can automatically pause and return to a stable visual to avoid a fall.
Balance Error Scoring Automation: For static stance tests, we can set a counter for “balance errors.” Instead of a human counting foot faults, we define an error as any sudden jerk in the headset’s motion indicating a loss of balance (for example, if the head dips or moves more than, say, 5cm abruptly – which might indicate a step or stumble). Another approach: use Vision Pro’s cameras to possibly detect if a hand comes up or foot moves, though that’s complex. A simpler built-in measure is sufficient as a proxy. We’ll log the number of such balance “instability events” in 20 seconds. Research has noted that traditional BESS scoring has only moderate reliability, so having a continuous measurement from sensors could be more reliable.
Vestibular head turn test: We will instruct the user via voice or on-screen text to perform rapid head rotations (e.g. 30° side-to-side at a metronome pace). The headset’s gyroscope can measure if they achieve the target speed (we might have to provide feedback like “turn faster” or “too fast, slow down” to standardize it). At the same time, we ensure they maintain focus on a dot (from Feature 1 code). We might log if the user could keep their eyes on target (again using the gaze focus trick).
User Interface & Safety: During balance tests, especially the moving room, it’s crucial the user can bail out if uncomfortable. We will implement a gesture or voice command like saying “Stop” (if we integrate Speech, or simply a pinch-and-hold for 2 seconds) to immediately stop movement and return to a normal view. VisionOS supports Spatial Audio, which we might use to provide a gentle auditory cue during the moving room (like a rhythmic tone) to help the user maintain orientation. After each sub-test, similar to the ocular tests, a symptom check prompt appears (e.g. “Are you dizzy? Rate 0-10”). If a high dizziness is reported, we might skip subsequent vestibular tests to avoid aggravation.
Data Output: This module yields quantifiable balance metrics:
Sway distances (with moving visual) – we can compare to baseline if available.
Number of balance “errors” in stance tests.
Whether the user had difficulty with VOR (e.g. couldn’t maintain gaze or felt symptoms).
A subjective dizziness score change, if any.
These will be stored in the result object. The report might say, for example, “Balance: Sway increased by 50% compared to baseline during dynamic visual test, indicating persisting balance deficit. 3 balance errors recorded in 20s stance (norm is 0-1).” Such interpretation could be added.
References & Justification: Our balance tests are informed by existing research and tools. The “moving room” paradigm is a well-established method to test sensory integration for balance; studies have shown concussed individuals exhibit greater sway when the visual field moves. This indicates lingering perceptual-motion disintegration that routine tests might miss. By implementing a moving room in AR, we replicate this lab test in a portable form. VR-based balance assessments in literature achieved good sensitivity and could detect deficits even after clinical recovery. We also improve on BESS: one study noted BESS had only 60% sensitivity for concussion with a certain cutoff; by using sensors, we aim to improve detection of balance issues. The virtual reality balance module by some researchers showed that using a VR platform could identify lingering balance problems that clinical tests missed. Our use of Vision Pro is directly analogous, providing a controlled yet realistic balance challenge. Moreover, including vestibular challenges (head movement, etc.) aligns with VOMS (Vestibular Ocular Motor Screening), which is proven to detect concussion symptoms that static tests do not. In summary, Feature 2 uses Vision Pro to objectively quantify balance, one of the most important and previously hard-to-measure concussion signs.
