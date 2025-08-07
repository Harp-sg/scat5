
## 1. Medical Spec

Implement the SCAT5 **Delayed Recall** module exactly as defined in the 5th-Edition consensus:

- **Timing:** Administer **≥5 minutes** after the end of the Immediate Memory trials.  
- **Stimulus:** Use the *exact same* word list (5-word or 10-word) previously presented.  
- **Single Recall Trial:** Athlete recalls all words in any order, one attempt only—no hints or repetitions.  
- **Scoring:** 1 point per correctly recalled word;  
  - **Max = 5** (for 5-word lists)  
  - **Max = 10** (for 10-word lists)  

> Record the timestamp of recall completion for audit and to trigger any follow-up tasks.

---

## 2. Volumetric UI Spec (Vision Pro)

### 2.1 Spatial Layout

- **Countdown View** (if <5 min remains):  
  - Circular timer ring (Ø 0.2 m) with large numeric countdown (24 pt) in center.  
- **Prompt View** (when ready):  
  - Floating panel (0.6 m × 0.3 m) at ~1.2 m in front, eye level.  
  - Prompt text (24 pt): “Delayed Recall: Say all the words I read earlier.”  
- **Response UI:**  
  - Blank slots as circles (0.05 m diameter) in a row—one per original word.  
  - **Microphone icon** (Ø 0.12 m) beneath slots to start speech capture.  
  - **“Tap to type”** button beside mic to open a floating keyboard for manual entry.

### 2.2 Interaction & Sensors

- **Countdown Enforcement:**  
  - Use a precise timer (e.g. `DispatchSourceTimer`) to block input until 5 min elapses.  
- **Speech Recognition:**  
  - On mic tap, start `SFSpeechRecognizer` session (max 30 s or until athlete says “Done”).  
  - Normalize transcripts (lowercasing, trimming) and split into tokens.  
- **Manual Fallback:**  
  - If recognition fails (<50% confidence) or times out, automatically show the on-panel keyboard.  
- **Gaze + Pinch:**  
  - Use `SpatialPointerInteraction` for mic, typing, and slot selection (to confirm entries).

### 2.3 Feedback

- **Correct Fill:**  
  - Slot fills with the word in green + soft chime.  
- **Incorrect/Repeat:**  
  - Slot flashes red + gentle buzz, then clears the erroneous token.  
- **Completion:**  
  - When all slots are filled or time expires, play a completion tone and auto-advance after 1 s.

---

## 3. API Contract

```swift
struct DelayedRecallResult: Codable {
  let listID: String           // e.g. "A" or "G"
  let recalledWords: [String]  // unique matched words
  let score: Int               // 0–5 or 0–10
  let timestamp: TimeInterval  // CACurrentMediaTime() at completion
}

enum ModuleResult {
  case delayedRecall(DelayedRecallResult)
}

class DelayedRecallModule: SCATModule {
  let id: ModuleID = .delayedRecall
  var listID: String = ""
  var originalList: [String] = []
  var recalled: [String] = []
  var timestamp: TimeInterval = 0

  func start(context: ModuleContext) {
    // Load memory module info
    listID = context.session.memoryListID
    originalList = context.session.memoryList
    let ready = context.session.memoryEndTimestamp + 300
    if CACurrentMediaTime() < ready {
      context.ui.showCountdown(until: ready) {
        self.promptRecall(context)
      }
    } else {
      promptRecall(context)
    }
  }

  private func promptRecall(_ context: ModuleContext) {
    context.ui.showDelayedRecallPrompt()
    context.ui.onMicTap = { self.startSpeech(context) }
    context.ui.onTypeTap = { self.showKeyboard(context) }
  }

  private func startSpeech(_ context: ModuleContext) {
    context.speech.startRecognition(timeout: 30) { words in
      self.handleResponses(words, context: context)
    }
  }

  private func showKeyboard(_ context: ModuleContext) {
    context.ui.showKeyboard { entries in
      self.handleResponses(entries, context: context)
    }
  }

  private func handleResponses(_ words: [String], context: ModuleContext) {
    let unique = Array(Set(words.map { $0.lowercased() }))
    recalled = originalList.filter { unique.contains($0.lowercased()) }
    timestamp = CACurrentMediaTime()
    let result = DelayedRecallResult(
      listID: listID,
      recalledWords: recalled,
      score: recalled.count,
      timestamp: timestamp
    )
    context.completeModule(with: .delayedRecall(result))
  }

  func complete() -> ModuleResult {
    fatalError("Use context.completeModule instead")
  }
}
4. Data Mapping
TestSession.delayedRecallScore ← score

Persist recalledWords and timestamp in session metadata

5. Edge Cases & Validation
Missing Memory Data: If memoryEndTimestamp or memoryList is absent, abort with an error.

Early Tap: If mic is tapped before countdown ends, show “Please wait X s.”

Speech Denied/Timeout: Auto-trigger keyboard fallback with a prompt.

Duplicate Tokens: Count each original word only once.

6. Example Payload
json
Copy
Edit
{
  "type": "delayedRecall",
  "listID": "A",
  "recalledWords": ["apple","ball","cat"],
  "score": 3,
  "timestamp": 6875723.523
}
ruby
Copy
Edit
