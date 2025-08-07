
1. Medical Spec

Implement the SCAT5 **Neurological & Coordination Exam** exactly per the 5th Edition consensus. This module contains five subtests; each is recorded as **Normal** or **Abnormal**. The overall **neuroExamNormal** field is `true` only if all subtests are Normal.

### 1.1 Neck Examination (Cervical Spine)
- **Instruction:** “Check if you have full, pain-free passive cervical range of motion.”
- **Clinician Prompt:** Gently guide the athlete’s head through flexion, extension, rotation, lateral bend.
- **Scoring:** `neckPain = true` if athlete reports pain or limited ROM; otherwise `false`.

### 1.2 Reading & Following Instructions
- **Instruction:** “Please read this sentence aloud.” (e.g. “The quick brown fox jumps over the lazy dog.”)
- **Comprehension Check:** Then ask: “Touch your left ear when you finish.”
- **Scoring:** `readingNormal = false` if slurred speech, hesitations, misreading, or inability to follow; else `true`.

### 1.3 Gaze Stability & Double Vision
- **Instruction:** “Follow the dot with your eyes only, without moving your head.”
- **Stimulus:** A dot moves slowly left to right, then up to down.
- **Clinician Query:** “Did you experience any double or blurred vision?”
- **Scoring:** `doubleVision = true` if athlete reports diplopia or displays gaze tracking error; else `false`.

### 1.4 Finger-to-Nose Coordination
- **Instruction:** “Touch your fingertip to your nose as quickly and accurately as you can, five times.”
- **Method:** Athlete sits, extends arm, and touches nose with index finger 5 times.
- **Scoring:** `fingerNoseNormal = false` if dysmetria (missing nose), ataxia, or >2 s per touch; else `true`.

### 1.5 Tandem Gait (Heel-to-Toe Walk)
- **Instruction:** “Walk heel-to-toe in a straight line for 3 meters, turn, and walk back the same way.”
- **Timing:** Measure total time; note any deviations off line or loss of balance.
- **Scoring:** `tandemGaitNormal = false` if athlete steps off line, cannot maintain heel-to-toe, or time exceeds expected threshold; else `true`.

---

## 2. Volumetric UI Spec (Vision Pro)

### 2.1 Spatial Layout
- Render a **carousel of cards** for each subtest. Each card: 0.5 m × 0.25 m at ~1.3 m distance.
- **Navigation:** Gaze-left/right + pinch to move between cards. A 5-segment circular progress ring appears peripherally.

### 2.2 Subtest Card Details

#### Neck Exam Card
- Prompt (24 pt): “Neck range of motion – pain-free?”
- Two buttons: **Yes** (green) / **No** (red), each 0.15 m × 0.08 m.

#### Reading & Instruction Card
- Display sample sentence in 20 pt.
- After reading, show **Yes/No** toggles: “Follow instruction?”

#### Gaze Stability Card
- Render a **0.05 m sphere** moving horizontally then vertically in a 0.8 m × 0.8 m plane.
- Track gaze intersection; count missed frames >200 ms.
- Prompt toggles: “Double vision?”

#### Finger-to-Nose Card
- Position a **nose marker** via ARKit face anchor.
- Track index-fingertip joint; detect touches when distance <0.05 m.
- Show “Touches: X/5” counter top-right.

#### Tandem Gait Card
- Overlay a **3 m floor line** via AR mesh.
- **Start** button (0.15 m × 0.08 m) to begin timer; **Stop** to end.
- Record time and show toggles: “Stepped off line?”

### 2.3 Interaction Patterns
- **Gaze + Pinch** for all button selections.
- **Hand Tracking** fallback for finger-to-nose and dot-following.
- **AR Mesh Anchors** for floor line placement.

### 2.4 Feedback
- Toggles light up accent color (#399EE6).
- Gaze misses flash red halo.
- Finger-to-nose pulses green on valid touch.
- Timer ticks with subtle audio.

---

## 3. API Contract

```swift
struct NeuroResult: Codable {
  let neckPain: Bool
  let readingNormal: Bool
  let doubleVision: Bool
  let fingerNoseNormal: Bool
  let tandemGaitNormal: Bool
  let tandemGaitTime: TimeInterval?  // seconds
}

enum ModuleResult {
  case neuro(NeuroResult)
}

class NeurologicalModule: SCATModule {
  var result = NeuroResult(
    neckPain: false,
    readingNormal: true,
    doubleVision: false,
    fingerNoseNormal: true,
    tandemGaitNormal: true,
    tandemGaitTime: nil
  )

  func start(context: ModuleContext) {
    context.ui.showNeuroCarousel(subtests: 5)
  }

  func recordNeckPain(_ pain: Bool) {
    result.neckPain = pain
  }
  func recordReading(_ ok: Bool) {
    result.readingNormal = ok
  }
  func recordDoubleVision(_ dv: Bool) {
    result.doubleVision = dv
  }
  func recordFingerNose(_ ok: Bool) {
    result.fingerNoseNormal = ok
  }
  func recordTandemGait(ok: Bool, time: TimeInterval) {
    result.tandemGaitNormal = ok
    result.tandemGaitTime = time
  }

  func complete() -> ModuleResult {
    return .neuro(result)
  }
}
4. Data Mapping
TestSession.neckPain ← result.neckPain

TestSession.readingNormal ← result.readingNormal

TestSession.doubleVision ← result.doubleVision

TestSession.fingerNoseNormal ← result.fingerNoseNormal

TestSession.tandemGaitNormal ← result.tandemGaitNormal

TestSession.tandemGaitTime ← result.tandemGaitTime

TestSession.neuroExamNormal ← all subfields are true

5. Edge Cases & Validation
Gaze failure: fallback to pinch-only on moving dot.

Hand-tracking loss: require manual toggles on finger-to-nose card.

No floor mesh: clinician manually enters time/toggle for gait.

Skip subtest: confirm “Skip this subtest?” before moving on.

6. Example Payload
json
Copy
Edit
{
  "type": "neuro",
  "neckPain": false,
  "readingNormal": true,
  "doubleVision": false,
  "fingerNoseNormal": true,
  "tandemGaitNormal": false,
  "tandemGaitTime": 8.47
}
