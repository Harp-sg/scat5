
Ocular Motor Tracking Module (Oculometer) – Requirements
The Oculometer module provides a set of vestibular-ocular motor tests in an immersive AR environment (Apple Vision Pro) to objectively assess concussion-related vision issues. This module leverages eye tracking and head tracking to evaluate how well the user’s eyes can move and focus, as these functions are often impaired after concussion. Research shows that vestibular/ocular motor exams (like VOMS) can detect concussions with ~90% accuracy and often uncover issues that standard cognitive or balance tests miss
upmc.com
upmc.com
. By integrating these tests into our VisionOS-based SCAT5 app, we aim for a faster, more objective assessment (similar in spirit to the Cal Poly ODIN headset that diagnoses concussions via eye-tracking
ceng.calpoly.edu
). Each sub-test will run as an independent module within the app, meaning they can be initiated and executed separately, and each will report its results into the overall assessment. We prioritize using Apple’s native VisionOS frameworks (ARKit, RealityKit, SwiftUI) for seamless performance and integration. However, if certain interactions (like gaze selection) prove difficult to implement natively, we may consider Unity’s XR Interaction Toolkit as a fallback (which offers built-in gaze and pinch interaction support
github.com
). Sub-Tests in the Oculometer Module: (each is described in detail below)
Smooth Pursuit Test: Eye follows a moving target smoothly.
Saccades Test: Rapid gaze shifts between two targets on cue.
Gaze Fixation & VOR Test: Steady gaze on a target, first with head still, then during head movements (Vestibulo-Ocular Reflex).
Convergence Test: Eyes track a target moving close to the nose, to find the near-point of double vision.
For each test, the app will provide clear on-screen instructions (and optional voice prompts) to the user, utilize the Vision Pro’s volumetric UI capabilities (3D content within the AR space), and gather both performance metrics and symptom feedback. After each sub-test, the user will rate symptom changes (e.g. dizziness or headache increase) on a simple scale via gaze & pinch input, mirroring the clinical VOMS procedure of symptom reporting. All results from these tests (quantitative metrics and subjective symptom reports) will be stored in the AssessmentResult data model for review. Any values outside normal ranges (based on baseline or population norms) will be flagged in the final report. Below are detailed requirements and implementation plans for each sub-test, including technical design and UI details, as well as references to relevant code examples or repositories for guidance.
