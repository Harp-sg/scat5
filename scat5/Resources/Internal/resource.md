## Resources for Building a Vision Pro Oculometer

Here are repositories, libraries, and code templates to help a coding agent develop the Ocular Motor Tracking Module (Oculometer) for Vision Pro. The focus is on leveraging native visionOS frameworks like ARKit and RealityKit, with pointers to specific code examples that address the core functionalities of each sub-test.

### General Purpose visionOS & RealityKit Resources

These repositories provide a foundational understanding of visionOS development, including handling 3D objects, user input, and AR interactions. They are excellent starting points for any visionOS project.

* **Awesome RealityKit ([link](https://github.com/divalue/Awesome-RealityKit))**: A curated list of RealityKit projects, packages, and articles. This is a great place to discover a wide range of functionalities and see how other developers are using RealityKit.
* **visionOS-examples ([link](https://github.com/IvanCampos/visionOS-examples))**: A collection of sample projects demonstrating various features of visionOS, including immersive spaces, 3D content, and user interactions.
* **VisionOS\_Resources ([link](https://github.com/silvinaroldan/VisionOS_Resources))**: Another valuable collection of examples, tutorials, and design resources for visionOS development.

---

### Head and Hand Tracking

These repositories are directly applicable to monitoring the user's head movements, a crucial part of the Oculometer's tests, and for detecting hand gestures for user input.

* **Vision-Pro-Head-Hand-Tracking-Demo ([link](https://github.com/kongmunist/Vision-Pro-Head-Hand-Tracking-Demo))**: A starter project that demonstrates how to track head and hand joint positions in Vision Pro. This is essential for the "Head Movement Monitoring" in the Smooth Pursuit, Saccades, and VOR tests. It also forms the basis for the hand gesture detection needed in the Convergence Test.
* **HandGesture ([link](https://github.com/johnhaney/HandGesture))**: A Swift package for visionOS that provides a higher-level API for capturing semantic hand gestures, such as a pinch. This is directly applicable to the "Convergence Test" for detecting when a user signals double vision.
* **HandVector ([link](https://github.com/XanderXu/HandVector))**: This repository offers a way to match hand gestures and even allows for testing hand tracking in the visionOS simulator. It provides an alternative and potentially more advanced method for pinch detection in the "Convergence Test."

---

### Sub-Test Specific Logic and Implementation

While no single repository implements the exact medical tests, the following provides the pre-baked logic and code examples for the core mechanics of each Oculometer sub-test.

#### **Smooth Pursuit Test**

The key here is creating a smoothly moving target.

* **RealityKit-Path-Maker ([link](https://github.com/Reality-Dev/RealityKit-Path-Maker))**: This package allows you to create a path from an array of points for a RealityKit entity to follow. This is the perfect tool for generating the horizontal and vertical sweeps of the target orb as described in the "Smooth Pursuit Test" requirements.

#### **Saccades and Gaze Stability Tests**

These tests rely on knowing what the user is looking at. The following resources explain how to handle gaze-based focus.

* **SwiftUI Focus Handling (Stack Overflow)**: While not a repository, this [Stack Overflow discussion](https://stackoverflow.com/questions/62142787/handling-focus-event-changes-on-tvos-in-swiftui) on tvOS focus handling is highly relevant. visionOS uses a similar focus engine. The key takeaway is the use of the `.focusable(true)` and `@FocusState` property wrapper to detect when a view is being looked at. This is the core mechanism for determining if the user's gaze is on the correct target in the "Saccades Test" and for monitoring gaze in the "Gaze Stability & VOR Test."

#### **VOR (Vestibulo-Ocular Reflex) Test**

This test combines gaze stability with head movement.

* **ARKit Head Rotation Tracking**: The `Vision-Pro-Head-Hand-Tracking-Demo` mentioned earlier provides the necessary code to access head rotation data from ARKit. By combining this with the SwiftUI focus handling techniques, you can build the VOR test. You'll need to continuously check the head's rotation while verifying that the user's gaze remains fixed on the target. The repository **ARPosture** ([link](https://github.com/topics/posture-recognition?l=swift)) also provides examples of using ARKit for head position tracking.

#### **Convergence Test**

This test requires detecting a specific hand gesture.

* **HandGesture and HandVector Repositories**: As mentioned in the "Head and Hand Tracking" section, these repositories provide the direct functionality needed to recognize a pinch gesture, which is the user's input to signal the onset of double vision.

By combining the general-purpose visionOS knowledge from the "Awesome" lists with the specific functionalities demonstrated in the targeted repositories for path animation, focus handling, head tracking, and hand gestures, a coding agent will have a comprehensive toolkit to build the Oculometer module.
High-value scaffolding repos & docs (VisionOS-native)
Gaze / Focus / Volumetric UI

Eyes (HIG) – explains system gaze highlighting and how users “look + pinch” to activate. Use this to justify using .focusable and Hover effects instead of raw eye rays. 
Apple Developer

SwiftUI Focus Cookbook + WWDC “SwiftUI focus” – patterns for .focusable, onFocusChange, focus sections; perfect for your saccade/pursuit timing. 
Apple Developer
+1

RealityUI (Swift Package) – prebuilt UI widgets/animations inside RealityKit scenes; great for volumetric score panels, countdown rings, progress chips. 
GitHub

Hand tracking / pinch (for Convergence “double now”)

Apple sample: “Tracking and visualizing hand movement” – official VisionOS sample with hand anchors and joint transforms. Base for custom pinch detection using thumb–index distance. 
Apple Developer

VisionGesture (repo) – working hand-tracking on device, plus a fake hand tracker for the simulator; good for building/testing custom gestures offline. 
GitHub

“Simplest sample code for hand tracking” (Dev.to) – 70-line SwiftUI/RealityKit hand-tracking demo; quick reference for joint enumeration. 
DEV Community

Custom gesture tutorial (blog) – step-by-step ARKit joint math to roll your own gestures. Useful if you want a dedicated “ConvergencePinch” recognizer. 
danieltperry.me

Movement/animation of targets

RealityKit move/animate examples – code snippets for entity.move(to:duration:), keyframes, and async helpers to chain motions (handy for smooth pursuit and convergence path). 
Step Into Vision
Stack Overflow
Gist

Curated lists to mine

awesome-visionOS – living index of VisionOS samples (RealityKit, ARKit, GroupActivities, shader examples). 
GitHub

Awesome RealityKit – physics, collisions, animation examples you can drop into “catch/move” behaviors. 
GitHub

visionOS resources roundup – broad collection of code & learning links. 
GitHub
Awesome Ecosystem


Core building blocks (official & battle-tested)
Apple visionOS “Hand tracking” sample – shows joint anchors, per-frame transforms, perfect to implement custom pinch (thumb–index distance) for the Convergence “double-now” trigger. Downloadable sample. 
Apple Developer
+1

SwiftUI .focusable(_:onFocusChange:) – system-level gaze focus; use it to time saccade reaction (cue → focus-landed timestamp) and to compute “focus time %” in pursuit/fixation. 
Apple Developer

RealityKit Entity.move(to:…duration:…timingFunction:) – one-liner to animate targets (pursuit path, convergence in-toward user). Also see async wrapper gist for awaitable chaining. 
Apple Developer
+1
Gist

Reality Composer Pro – optional authoring tool bundled with new visionOS projects; use it to lay out volumetric HUD panels / targets or import USDZ assets cleanly. 
Apple Developer
+1

WWDC visionOS sessions – how to blend SwiftUI + RealityKit (volumes, RealityView, attachments) and how gaze hover is automatic for focusable elements. Great for scaffolding your volumetric UI shell. 
Apple Developer
+2
Apple Developer
+2

Drop-in libraries & sample repos (VisionOS-native)
Volumetric UI / HUDs
RealityUI (Swift Package) – prebuilt 3D UI controls & animations inside RealityKit; ideal for floating scorecards, timers, symptom pickers in scene (no flat windows). 
GitHub
The Swift Package Index

HUD Component gist (visionOS) – minimal HUD overlay pattern in an ImmersiveSpace with RealityView + attachments; use as a template for your VOMS symptom prompt. 
Gist

Hand tracking & custom gestures (for pinch without changing gaze)
VisionGesture – real-device hand tracking + simulator fake-hand; great to build/test pinch detector and custom gestures offline. 
GitHub

HandVector – gesture similarity utils + simulator bridge; handy for robust, debounced pinch recognition. 
GitHub

HandsRuler – production app showing index-to-index distance across hands; copy the distance math & joint sampling cadence. 
GitHub

Custom hand-gesture tutorial (ARKit joints) – step-by-step math for joint vectors/thresholds; adapt directly for Convergence “double” pinch. 
danieltperry.me

41-line hand-tracking snippet – ultra-compact sample to read all joints via AsyncSequence; great for the agent as a starting point. 
DEV Community

Target motion, timing & animation
RealityKit move examples – clear, modern examples (2025) animating entities with duration and easing; ideal for smooth pursuit sweeps and linear convergence. 
Step Into Vision

CreateWithSwift: play / chain animations – demonstrates availableAnimations & playAnimation, if you import animated USDZ targets (optional). 
Create with Swift

Entity.move async gist – moveAsync helper returning when motion completes → makes cue → await focus → next cue logic tidy for saccades. 
Gist

Project scaffolds & curated lists (to mine patterns quickly)
awesome-visionOS (multiple lists) – pointers to dozens of open sample apps, RealityView, anchors, spatial audio, etc. Use to grab scene setup, volumes, attachments patterns. 
GitHub
+2
GitHub
+2

VisionProTeleop – streams head + wrist + hand tracking; browse for clean head-pose capture & timestamping patterns useful for VOR head-motion checks. 
GitHub

Intro visionOS samples – Apple’s official landing that links all starter projects (including hand tracking) your agent can clone. 
Apple Developer

Asset sources (targets, icons, simple 3D)
Apple Quick Look USDZ gallery – free USDZ models to prototype dots/balls/panels (you can also author minimal spheres in Composer Pro). 
Apple Developer

Loading USD/Reality files – official docs for loading assets programmatically (for any custom target meshes or UI tokens). 
Apple Developer

Composer Pro docs – importing PBR materials, organizing scenes for volumetric UI. 
Apple Developer

How these map to your four tests
Smooth Pursuit

Animate a glowing orb left↔︎right/up↕︎ with move(to:duration:timingFunction:); compute focus-time % via .focusable(onFocusChange:). Use RealityUI for a tiny countdown ring before motion. 
Apple Developer
+2
Apple Developer
+2
Step Into Vision
GitHub

Saccades

Two static focusable targets (L/R). On cue, pulse target (RealityUI) and timestamp. When onFocusChange(true) fires on the cued target, compute latency. Chain with the moveAsync gist if you add animated cues. 
GitHub
Apple Developer
Gist

Fixation & VOR

Center crosshair as focusable view. For VOR, read head yaw from ARSession.currentFrame.camera.transform each frame; warn if below target amplitude or if focus drops. VisionProTeleop shows clean pose capture + timestamps you can mirror. 
GitHub

Convergence

Move the dot toward the user over ~10 s; capture pinch via hand-joint distance (Apple sample / VisionGesture). On pinch, stop motion and record NPC distance. (HandsRuler demonstrates stable distance sampling patterns.) 
Apple Developer
GitHub
+1


