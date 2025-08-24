
## 1. Medical Spec

Implement the SCAT5 **Balance Examination (mBESS)** exactly as defined in the SCAT5 protocol:

- **Stances (3 × 20 s each)** on a firm surface:
  1. **Double‐leg stance**: feet together, hands on hips, eyes closed.
  2. **Single‐leg stance**: non‐dominant foot on ground, dominant foot raised, hands on hips, eyes closed.
  3. **Tandem stance**: heel‐to‐toe, non‐dominant foot behind, hands on hips, eyes closed.

- **Error definitions** (each counts as 1):
  - Hands lift off iliac crests
  - Opening eyes
  - Step, stumble, or fall
  - Hip abduction or flexion > 30°
  - Lifting forefoot or heel
  - Remaining out of position > 5 s

- **Scoring**:
  - Count up to **10 errors per stance** (max 30).
  - **Total Error Score** = sum(errors in all 3 stances), range 0 (best) – 30 (worst).

---

## 2. Volumetric UI Spec (Vision Pro)

### 2.1 Spatial Layout
- Use an `ImmersiveSpace` with a **wide panel** (0.8 m × 0.4 m) set ~1.2 m in front at chest level.
- Split into **three tabs** or carousel cards—one per stance—labeled “1/3”, “2/3”, “3/3”.

### 2.2 Per‐Stance Card

- **Instructions** at top (20 pt): e.g. “Double‐leg stance: 20 s”.
- **Timer**: large 0.2 m diameter countdown ring around a numeric countdown (24 pt).
- **Error Counter**: “Errors: X” in top‐right (16 pt).
- **Error Button**: a big red 0.1 m × 0.1 m button labeled “Error +1”.  
- **Sway Graph (Optional)**: mini‐plot of head sway magnitude over time, 0.4 m wide × 0.1 m tall.

### 2.3 Interaction & Sensors

- **Start/Next**: Gaze + pinch on “Start” / “Next Stance” buttons (0.15 m × 0.07 m).
- **Error Recording**:  
  - Tap **Error +1** (gaze + pinch) each time an error occurs.  
  - **Automatic detection** (optional):  
    - **Head‐sway** via `CMMotionManager.deviceMotion` (roll/pitch > threshold)  
    - Increment error automatically if sway exceeds preset (e.g. >0.15 rad).  
- **Apple Watch Integration (Optional)**:  
  - Stream high‐freq accelerometer data to detect foot lifts or body sway.  
  - Use `WCSession` to receive live motion and supplement head‐sway counts.

### 2.4 Feedback

- **Error button** flashes +1 and haptic pulse on Watch (if paired).
- **Timer ring** pulses green when time starts, red when <5 s remaining.
- **Sway spikes** highlight in the mini‐graph.

---

## 3. API Contract

```swift
struct BalanceResult: Codable {
  let errorsByStance: [Int]       // [double, single, tandem]
  let totalErrors: Int            // sum(errorsByStance)
  let swayData: [Double]?         // optional head‐sway magnitudes
}

enum ModuleResult {
  case balance(BalanceResult)
}

class BalanceModule: SCATModule {
  let id: ModuleID = .balance
  var errors = [0, 0, 0]
  var swayData: [Double] = []
  var motionMgr = CMMotionManager()
  var watchSession: WCSession?

  func start(context: ModuleContext) {
    context.ui.showBalanceCarousel(totalStances: 3)
    startStance(index: 0, context: context)
  }

  private func startStance(index: Int, context: ModuleContext) {
    errors[index] = 0
    startHeadSwayUpdates()
    context.ui.showStance(index: index, duration: 20) { 
      self.stopHeadSwayUpdates()
      context.ui.hideSwayGraph()
      if index < 2 {
        context.ui.showNextButton { _ in self.startStance(index: index+1, context: context) }
      } else {
        self.finish(context: context)
      }
    }
    context.ui.onErrorButtonTapped = {
      self.errors[index] += 1
      context.ui.updateErrorCounter(self.errors[index])
    }
  }

  private func startHeadSwayUpdates() {
    motionMgr.deviceMotionUpdateInterval = 1/50
    motionMgr.startDeviceMotionUpdates(to: .main) { data, _ in
      let d = data!.attitude.roll.magnitude + data!.attitude.pitch.magnitude
      self.swayData.append(d)
      if d > 0.15 {
        // optionally auto‐increment current error
      }
      // update UI mini‐graph
    }
    context.ui.showSwayGraph(data: swayData)
  }

  private func stopHeadSwayUpdates() {
    motionMgr.stopDeviceMotionUpdates()
  }

  private func finish(context: ModuleContext) {
    let total = errors.reduce(0,+)
    let result = BalanceResult(errorsByStance: errors, totalErrors: total, swayData: swayData)
    context.completeModule(with: .balance(result))
  }

  func complete() -> ModuleResult {
    fatalError("Use context.completeModule instead")
  }
}
4. Data Mapping
TestSession.balanceErrorsByStance ← errors

TestSession.balanceErrorsTotal ← totalErrors

(Optional) store swayData in metadata

5. Edge Cases & Validation
Max Errors: Cap each stance at 10; disable Error button thereafter.

MotionMgr Unavailable: fallback to manual error button only.

Watch Unreachable: degrade gracefully; show “Watch not connected” note.

Interruption: pausing/resuming timer and motion updates on app focus loss.

6. Example Payload
json
Copy
Edit
{
  "type": "balance",
  "errorsByStance": [1, 3, 2],
  "totalErrors": 6,
  "swayData": [0.02,0.05,0.12,0.18, /* … */]
}
