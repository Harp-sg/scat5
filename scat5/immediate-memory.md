
1. Medical Spec
Word Lists

Default: 5-word lists (A–F)

Optional: 10-word lists (G–I) for research

Trials

Present the same chosen list 3 times, 1 second per word, regardless of performance

Scoring

1 point per correctly recalled word, across all trials

Max = 15 (5-word) or 30 (10-word)

Timing

Use a precise timer (±0.01 s) to display each word at 1.0 s intervals

Record the timestamp of the final word of Trial 3 to trigger the Delayed Recall module after ≥ 5 min

No repeats of the list between trials; no hints.

2. Volumetric UI Spec (Vision Pro)
Spatial Layout

Use an ImmersiveSpace with a central floating panel (0.6 m × 0.3 m) at ~1.2 m distance.

Presentation View:

Current word in 24 pt text, centered.

“Trial X / 3” in 16 pt beneath.

Recall View:

5 (or 10) blank slots as circles (0.05 m diameter) in a row.

Microphone icon (0.12 m) at bottom-center to start speech capture.

“Tap to type” toggle to open a floating SwiftUI keyboard for manual entry.

Interaction & Sensors

Timed Display: CACurrentMediaTime()-driven, with 0.1 s fade-in/-out, 0.8 s hold.

Audio Playback: AVSpeechSynthesizer at 140 wpm in sync with timer.

Speech Recognition:

Start on mic tap; capture up to 30 s or until user says “Complete.”

Normalize and match tokens against the active word list.

Manual Fallback: If recognition fails (< 60% confidence), show on-panel keyboard.

Feedback:

Correct word → slot fills green + chime.

Incorrect/duplicate → slot flashes red + error tone.

Trial Transition: 2 s countdown (“Next Trial in 2…1…Go”) between trials.

3. API Contract
swift
Copy
Edit
struct MemoryResult: Codable {
  let listID: String            // e.g. "A"
  let trials: [[String]]        // words recalled each trial
  let totalCorrect: Int         // 0–15 or 0–30
  let endTimestamp: TimeInterval// for scheduling delayed recall
}

enum ModuleResult {
  case memory(MemoryResult)
  // … other modules …
}

class MemoryModule: SCATModule {
  let id: ModuleID = .memory
  var selectedList: [String] = []
  var trials: [[String]] = []
  var currentTrial = 0
  var endTimestamp: TimeInterval = 0

  func start(context: ModuleContext) {
    // Choose list, reset state, begin Trial 1
  }

  private func runNextTrial(context: ModuleContext) {
    // Present words paced at 1 s; then show recall UI
  }

  private func endSession(context: ModuleContext) {
    endTimestamp = CACurrentMediaTime()
    let correct = trials.flatMap{$0}.filter(selectedList.contains).count
    context.completeModule(with: .memory(
      MemoryResult(
        listID: ListRepository.id(for: selectedList),
        trials: trials,
        totalCorrect: correct,
        endTimestamp: endTimestamp
      )
    ))
  }

  func complete() -> ModuleResult {
    fatalError("Use context.completeModule to finish")
  }
}
4. Data Mapping
TestSession.memoryScore = totalCorrect

Store selectedList and full trials array in session metadata

Set TestSession.delayedRecallReadyTime = endTimestamp + 300 (5 min)

5. Edge Cases & Validation
Default List: If config invalid, default to List A.

Speech Timeout: No speech in 30 s → prompt “Please speak or type.”

Duplicate Words: Only first correct occurrence counts; ignore repeats.

Interruption: App focus loss pauses presentation and resumes accurately.

6. Example Payload
json
Copy
Edit
{
  "type": "memory",
  "listID": "A",
  "trials": [
    ["apple","ball","cat"],
    ["apple","dog"],
    ["ball","cat","dog"]
  ],
  "totalCorrect": 8,
  "endTimestamp": 6875423.423
}
