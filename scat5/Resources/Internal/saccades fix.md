
Overview
In this Vision Pro saccade test app, the goal is to measure eye movement (saccades) by having the user look quickly at targets (left/right/up/down) while keeping their head still. The current implementation uses RealityKit spheres as targets with gaze-and-pinch selection. However, several issues are causing the results to be zero and the experience to feel off. Below we identify the problems and propose solutions, covering both code logic and UI improvements to achieve a more reliable, “medical-grade” saccade test.
Issues Observed
No Gaze Detections (Zero Results): The app isn’t registering the user’s gaze shifts, so trials always time out (latency 0 or nil). This is likely because the code only logs a “focus” when the user pinches (selects) a target. If the user just looks at the target without pinching (as one might expect in a saccade test), the app never records the gaze event, resulting in 0 valid trials.
Lack of Gaze Feedback: Users have no clear indicator of where the system thinks they are looking. The targets do have a subtle hover highlight (via HoverEffectComponent), but it may not be obvious enough. There is a text HUD (“Gaze: None/Left/Right…”) but it only updates on pinch selection, not on pure gaze. This can leave users unsure if their eye movement was detected at all.
Inadequate Head-Motion Indicator: While the HUD shows “KEEP STILL!” in text and uses a red tint when head motion exceeds 3°, this may not be prominent or intuitive enough. The user requested a “rotation leveler or something” – presumably a visual gauge to help keep the head level.
Content Appears Too Low: All the targets and HUD appear below eye level, rather than directly in front of the user’s eyes. This suggests a coordinate system issue – likely the content is anchored to world coordinates (floor or initial origin) instead of the user’s head position. The result is that the user sees the test elements “down near the floor” instead of at eye height.
Understanding Vision Pro Eye Input Constraints
It’s important to recognize how Vision Pro (visionOS) handles eye tracking input. Apple does not allow apps to directly access raw eye-gaze data for privacy reasons. As stated in Apple’s documentation, only the user’s final selection (e.g. a tap or pinch) is delivered to apps, and eye tracking data itself is not shared with third-party apps
reddit.com
. In other words, an app can know what the user ultimately selected (by pinching while gazing at a target), but it cannot continuously track or record the precise gaze point at runtime. This means that a true “hands-free” saccade test (where just looking at a target triggers a response) is not straightforward on Vision Pro. The system will highlight gaze targets for user feedback, but it won’t directly tell your app “the user’s eyes are now looking at Target X” unless some interaction occurs. We have to work within these constraints using the tools Apple provides (focusable UI elements, indirect gaze + pinch gestures, etc.).
Solutions and Improvements
1. Register Gaze Selections (Fixing the 0-Result Issue)
Option A: Require a Pinch (and make that clear). The simplest way to register a saccade is to have the user perform the pinch gesture when they look at the target. This is what your code attempted with the SpatialTapGesture .targetedToAnyEntity(). To fix the “0 result” problem, ensure the user knows they must pinch to confirm their gaze target. For example, update the on-screen instructions:
“When a target flashes, look at it and quickly pinch your fingers to select it.”
By explicitly instructing this, users will perform the pinch, triggering handleTargetSelection and recording a latency. The app then measures the time from cue to pinch (which includes eye movement + reaction time). This isn’t pure eye latency, but given visionOS limitations it’s a viable workaround for now. Option B: Use Focus (Hover) Events to auto-detect gaze. A more advanced approach is to leverage the system’s gaze focus without requiring a pinch. VisionOS automatically highlights interactive elements when looked at
stackoverflow.com
. If we can capture the moment a target gains focus, we could log that as the saccade completion time. RealityKit’s HoverEffectComponent provides the visual, but doesn’t send an event to our code by itself. However, we can achieve this by using SwiftUI focusable views in place of or layered on top of the RealityKit spheres:
Make each target a SwiftUI view (e.g. a Circle) that is .focusable(true) and attach it to the RealityView at the desired 3D position (using an attachment or the new ViewAttachmentComponent in visionOS 26).
Use .onFocusChange on those views to detect when focus is gained (meaning the user’s eyes are on that element). For example, an onFocusChange handler could record the timestamp the moment the view becomes focused.
This gives you a callback almost immediately when the user looks at the target (no pinch needed). You can then compute latency = focusTime – cueTime.
Keep in mind, using gaze focus alone might be less precise than a manual trigger and could potentially fire if the user glances briefly. You might implement a small dwell threshold (e.g. require the focus to remain for 100 ms) to confirm it as a valid look. Also note that testing this requires a device; the simulator’s “Send Pointer” won’t perfectly emulate actual eye focus behavior
developer.apple.com
developer.apple.com
. If done right, this method could approach a more “hands-free” saccade test experience. Recommendation: In the near term, update the app to guide the user to pinch so you stop getting 0 results. In parallel, you can experiment with the focusable SwiftUI approach to see if it reliably captures gaze events. Combining both might be ideal: e.g., use focus events to measure raw eye latency, but still ask for a pinch as a confirmation and backup signal.
2. Improve Gaze Feedback to the User
To make sure the user knows what they’re looking at is registered:
Make Targets Focusable & Highlight on Gaze: (As mentioned, ensure each target has HoverEffectComponent, InputTargetComponent, and a collision shape
stackoverflow.com
 – your code already does this with generateCollisionShapes). When these are set, visionOS will automatically highlight the object when the user looks at it. If the default hover glow is too subtle, consider customizing it:
You can change the target’s appearance on focus. For example, if you implement the SwiftUI focusable overlay, you could also bind a state to it – when focused, change the sphere’s material or scale. Even without that, you might observe that the HoverEffect adds a slight bloom; you could amplify user feedback by increasing the sphere size or adding an outline when it’s the current cue.
Another approach is to use the fact that the system only allows one item to be focused at a time – you could periodically check which target is currently under gaze if you manage focus state. But since direct querying isn’t available, leaning on the visual highlight is the primary option.
Optional Gaze Cursor: For a truly explicit “where my eyes are” indicator, some apps use a subtle reticle or dot at the gaze point. Apple’s HIG doesn’t provide a public gaze cursor (the philosophy is to highlight targets instead
reddit.com
), and there’s no API to get the gaze coordinate in the scene. So we cannot draw a free-moving eye cursor. Instead, focus indicators on the targets themselves are the way to go. Ensuring the targets’ hover highlight is visible and perhaps augmenting it (as above) will give the user confidence that “yes, I’m looking at the correct spot.”
Feedback on Wrong Target: Currently, if the user looks at or pinches the wrong target, the code marks a wrong outcome but the user might not realize it immediately. You might provide a quick visual feedback for incorrect selections – e.g., flash the target red or play a sound – to distinguish it from a correct hit. This can be done in handleTargetSelection when isCorrect is false.
3. Enhanced Head-Motion Indicator (Leveler)
Keeping the head still is critical for a valid saccade test, so it’s worth giving strong feedback about head movement:
Visual Level Gauge: You can add a small “bubble level” style indicator to the HUD. For example, draw crosshair axes and a dot that moves off-center if the user tilts their head. The dot’s X position could map to head yaw, and Y position to head pitch. When the head is perfectly still (within tolerance), the dot stays centered in the crosshair. If they move, the dot drifts off-center, and you can also color it green (steady) vs. red (too much motion). This gives a real-time intuitive cue. Implementing this in SwiftUI is straightforward (using shapes and .offset based on controller.currentHeadYaw/Pitch).
Numerical/Text Feedback: In addition to or instead of the above, you could display the current head rotation in degrees. For example: “Head Yaw: 2.5°, Pitch: 1.8°”. This might be more detail than a typical user needs, but it can help during testing to adjust thresholds. Your HUD already shows a red warning if >3°, which is good. You might increase the font size or make the warning text (“KEEP STILL!”) flash when triggered to ensure the user notices.
Stricter Handling: Your code invalidates trials if head motion exceeds limits, which is correct for test integrity. Make sure to communicate this to the user. For instance, if a trial is invalidated due to head movement, you might briefly display a message like “Head moved – trial skipped” so they understand what happened.
By providing a clear level indicator and warnings, users will better maintain the required stillness, improving test quality.
4. Positioning Content at Eye Level
The issue of everything showing up “down, not in front” is a coordinate anchoring problem. In an immersive space, the origin can be arbitrary or at floor level depending on ARKit’s world tracking. We should instead anchor the content relative to the user’s head position at the start of the test. The solution is to use a head-anchored entity:
Create an AnchorEntity anchored .head with trackingMode: .once. This will place the anchor at the user’s head pose at creation time, and then stop updating (so it stays in the world fixed relative to where the head was). For example:
let originAnchor = AnchorEntity(.head)
originAnchor.anchoring.trackingMode = .once
content.add(originAnchor)
// Now add targets as children of this anchor:
originAnchor.addChild(leftTarget)
originAnchor.addChild(rightTarget)
// ... etc ...
leftTarget.position = [-horizontalOffset, 0, -depth]  // e.g. (-0.3, 0, -1)
upTarget.position   = [0, verticalOffset, -depth]
// etc.
This ensures that at the moment the immersive space opens (or the test begins), the anchor is at the user’s eye level and facing direction
stackoverflow.com
. All targets placed relative to this anchor (at Z = –depth in front, and some X/Y offsets) will appear directly in front of the user’s gaze, at roughly eye height. Now the user shouldn’t have to look down to see the targets.
Why .once tracking? By freezing the anchor after initial placement, the targets stay world-fixed. The user is instructed not to move their head; thus the targets remain in the same spot in space even if the user later fidgets. If we used a continuously tracking head anchor, the content would move with the user’s head (like a HUD stuck to the face), which we don’t want – it would defeat the purpose by removing the need for eye movement. Using .once gives us a stable reference frame for the test
stackoverflow.com
.
Verify orientation: The anchor’s orientation will match the head’s initial orientation. So if the user was looking straight ahead, the –Z axis of the anchor is straight in front of them. That means position = (0,0,-1) on the anchor is one meter forward along their line of sight (which is what we want). The Y axis of the head anchor should be vertical, so an offset of (0, 0.2, -1) would be 20 cm above eye level at 1 m out. If you still find content slightly off, you can adjust the offsets (e.g. use a small negative Y if needed to align with eyes, since the device’s coordinate might be centered between the eyes).
HUD attachments: You can also attach your HUD SwiftUI views to this same originAnchor for consistency. In your positionHUDElements, instead of adding attachments directly to content, add them as children of originAnchor (and still use billboard so they face the user). That way, the HUD (instructions, countdown, exit button, etc.) is also placed relative to the user’s initial position and not at ground level.
After this change, your “fixation dot” and targets will appear floating at eye-level in front of the user, greatly improving ergonomics.
5. Polish and Other Considerations
SwiftUI vs RealityKit in visionOS 26: With visionOS 26, Apple introduced tighter integration between SwiftUI and RealityKit. You can attach SwiftUI views into a RealityKit scene more easily (via ViewAttachmentComponent) and even attach SwiftUI gesture handlers directly to entities
developer.apple.com
. This might simplify some of the approaches above (for example, handling gaze focus or tap on an entity using SwiftUI’s mechanisms). Keep an eye on those APIs as they evolve, as they could let you, say, mark a RealityKit ModelEntity as focusable and respond to focus state changes in SwiftUI.
Calibration and Medical Accuracy: Since you mentioned “medical grade,” be aware of the limitations: the Vision Pro’s eye tracking is very good for interface interactions, but Apple’s restrictions mean you can’t directly measure true saccadic reaction time in the 100–300 ms range with precision. The pinch method will include a motor reaction component, and even the focusable-view hack might have a small system lag. Make sure to document these limitations if using this for any clinical or research purpose. Still, the device’s consistent tracking and lack of extra hardware make it promising for relative comparisons and detecting larger impairments.
Data Logging: To achieve medical-grade credibility, you might want to log raw trial data (latencies, errors, head motion) for analysis. Ensure your SaccadesTestResults and SaccadesResult (SwiftData model) capture all needed info. You might also timestamp events with system time or monotonic time for accuracy. The code seems to be doing this already (storing latency, etc.); just be cautious with using ProcessInfo.systemUptime (monotonic) vs. Date – the former is good for high-res intervals as you used.
User Experience: Finally, polish the flow – e.g., provide a summary to the user at the end with clear interpretation. Your results view already computes an overall score and flags “potential impairment” if certain metrics are off. Ensure those thresholds (error rate, latency) are tuned to known clinical norms if possible. It’s great that you provide a recommendation for follow-up evaluation if needed. Little things like that make it feel more “medical grade.”
Conclusion
By implementing the changes above – anchoring the scene to the user’s head, using focusable targets or pinch input to register gaze shifts, providing clear visual feedback for gaze and head movement, and refining instructions – you will significantly improve the reliability and usability of the saccade test on Vision Pro. The combination of RealityKit and SwiftUI in visionOS 26 offers powerful tools to achieve this, as evidenced by community findings and Apple’s examples (e.g., using AnchorEntity(.head) to position content at head height
stackoverflow.com
, and leveraging the Vision Pro’s focus highlighting for gaze input
stackoverflow.com
). With these improvements, your app should be able to approach a “medical-grade” test: delivering consistent stimuli and capturing the user’s responses more accurately. Just remember that absolute eye-tracking precision is gated by the platform’s design
reddit.com
, but within those bounds, you can still obtain valuable metrics on the user’s ocular performance. Good luck, and happy testing! Sources:
Apple Vision Pro eye input privacy – only final selections (e.g. pinch taps) are sent to apps
reddit.com
.
VisionOS gaze highlighting requires HoverEffectComponent, InputTargetComponent, and collisions on entities
stackoverflow.com
.
Using a head-anchored RealityKit entity to place content at eye level in an immersive space
stackoverflow.com
.
