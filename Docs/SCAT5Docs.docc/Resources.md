# Resources for Building a Vision Pro Oculometer

Here are repositories, libraries, and code templates to help a coding agent develop the Ocular Motor Tracking Module (Oculometer) for Vision Pro. The focus is on leveraging native visionOS frameworks like ARKit and RealityKit, with pointers to specific code examples that address the core functionalities of each sub-test.

## General Purpose visionOS & RealityKit Resources

These repositories provide a foundational understanding of visionOS development, including handling 3D objects, user input, and AR interactions. They are excellent starting points for any visionOS project.

* Awesome RealityKit ([link](https://github.com/divalue/Awesome-RealityKit))
* visionOS-examples ([link](https://github.com/IvanCampos/visionOS-examples))
* VisionOS_Resources ([link](https://github.com/silvinaroldan/VisionOS_Resources))

---

## Head and Hand Tracking

* Vision-Pro-Head-Hand-Tracking-Demo ([link](https://github.com/kongmunist/Vision-Pro-Head-Hand-Tracking-Demo))
* HandGesture ([link](https://github.com/johnhaney/HandGesture))
* HandVector ([link](https://github.com/XanderXu/HandVector))

---

## Sub-Test Specific Logic and Implementation

### Smooth Pursuit Test
* RealityKit-Path-Maker ([link](https://github.com/Reality-Dev/RealityKit-Path-Maker))

### Saccades and Gaze Stability Tests
* SwiftUI Focus Handling (Stack Overflow) ([link](https://stackoverflow.com/questions/62142787/handling-focus-event-changes-on-tvos-in-swiftui))

### VOR (Vestibulo-Ocular Reflex) Test
* ARPosture (topic) ([link](https://github.com/topics/posture-recognition?l=swift))

### Convergence Test
* HandGesture and HandVector (links above)

---

## Additional Notes

The original extensive resource list, examples, and guidance are maintained here for internal reference. This DocC bundle ensures documentation is excluded from Compile Sources and won’t break builds.