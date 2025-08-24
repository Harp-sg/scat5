
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

Immediate Memory (0–15 or 0–30) Module: Detailed Workflow

The Immediate Memory task assesses an athlete’s ability to encode and recall short lists of words, a core component of the SCAT5 cognitive screen. On Vision Pro, we’ll automate presentation, timing, and scoring while preserving the exact SCAT5 protocol.

1. Word‐List Selection
List Repository
– The app ships with six 5-word lists (A–F) and three 10-word lists (G–I), exactly as published in the SCAT5 manual.

Configuration
– By default, use 5-word lists (max score = 15).
– For research or ceiling‐effect avoidance, the clinician can toggle a setting to use 10-word lists (max = 30).

Randomization
– To prevent learning effects across repeated tests, the module randomly picks one list per session.

2. Presentation Phase
Immersive Display
– Enter an ImmersiveSpace where a floating panel (0.6 m × 0.3 m) sits ~1.2 m in front at eye level.
– The panel background uses a subtle ultraThinMaterial to maintain environmental awareness.

Word‐by‐Word Pacing
– Internally, we capture a high‐precision start time via CACurrentMediaTime().
– Every 1.0 s (±0.01 s), we:

Fade‐in the next word over 0.1 s (to minimize abrupt visual changes).

Hold it for 0.8 s.

Fade‐out over 0.1 s.
– Simultaneously, AVSpeechSynthesizer speaks the word at ~140 wpm, synchronized to the timer.

On‐Panel Feedback
– A small “Trial X/3” indicator (16 pt) updates at the panel’s top as each list presentation begins.
– A pulsing ring around the word text provides a visual rhythm cue, helping athletes with vestibular difficulties stay engaged.

3. Recall Phase
Immediate Transition
– At the end of the third word‐presentation fade‐out, the panel transitions in 0.2 s to a recall UI.

Recall UI Elements
– Slot Row: 5 (or 10) blank circles (Ø 0.05 m) aligned horizontally; each represents one target word.
– Microphone Icon: Centered beneath slots (Ø 0.12 m). Gaze + pinch to start speech capture.
– “Tap to Type” Button: Gaze + pinch opens an on‐panel SwiftUI keyboard for manual entry if needed.

Speech Capture
– Upon mic‐tap, we launch an SFSpeechRecognizer session, capturing up to 30 s or until the athlete says “Done.”
– As speech arrives, the engine:

Tokenizes words (lowercasing, trimming punctuation).

Deduplicates so each target only counts once.

Matches tokens against the original list.

Slot Filling & Feedback
– Correct match → corresponding circle fills with the word text in green + soft chime.
– Incorrect or duplicate → circle flashes red + gentle buzz, then clears to allow another attempt.
– Progressively fill slots in the order the athlete recalls—order doesn’t affect score.

Manual Fallback
– If speech authorization is denied or recognition confidence <60%, we automatically display the SwiftUI keyboard and let the clinician or athlete gaze‐select letters to type each word.

4. Scoring & Data Capture
Score Calculation
– totalCorrect = number of unique matched words (max 15 or max 30).

Timestamping
– Capture endTimestamp = CACurrentMediaTime() immediately upon completion of recall (last slot filled or time expired).
– Store this timestamp to schedule the Delayed Recall module at endTimestamp + 300 s.

Result Object

swift
Copy
Edit
struct MemoryResult: Codable {
  let listID: String           // e.g. "A"
  let trialsRecalled: [[String]] // arrays of recalled words per trial if we store per‐trial data
  let totalCorrect: Int
  let endTimestamp: TimeInterval
}
Persistence
– Write the MemoryResult into the current TestSession (SwiftData).
– Optionally log full per‐trial transcripts for research.

5. Handling Interruptions & Errors
App Focus Loss: Presentation timer pauses if the headset is removed or app backgrounds, then resumes exactly where left off.

Late Entry: If the athlete is still speaking when the 30 s expires, we cut off capture and process what we have.

Premature Exit: If the clinician switches modules mid‐recall, we warn: “Immediate Memory incomplete—progress will be lost.”

6. Vision Pro Advantages for Immediate Memory
Precise Timing & Synchronization via high‐resolution timers and spatial audio.

Hands‐Free & Accessible controls—gaze and voice reduce manual steps and keep athletes settled.

Immersive Focus minimizes distractions, essential for accurate memory encoding.

Rich Feedback (visual, auditory, haptic) reinforces correct responses and guides athletes seamlessly.

By combining SCAT5’s rigorous 1 s pacing and 3-trial structure with Vision Pro’s audio‐visual immersion, speech recognition, and precise timers, we ensure clinical fidelity, administrative simplicity, and maximal reproducibility of the Immediate Memory assessment.








Sources
You said:
how is memory being tested though aas per scaat 5


ChatGPT said:

Thought for 9 seconds
SCAT5 Immediate Memory Protocol (Medical-Grade Detail)

The Immediate Memory subtest of the SCAT5 is designed to assess an athlete’s ability to encode and recall non-semantic information under time pressure. It follows these strict, evidence-based steps:

Word‐List Selection

Choose one of the six 5-word lists (Lists A–F) provided in the SCAT5 manual.

Optional (to reduce ceiling effects): use a 10-word list (Lists G–I) instead
ecysa.org
.

Clinician Script

“I am going to test your memory. I will read you a list of words and when I am done, repeat back as many words as you can remember, in any order.”
(Do not mention the delayed recall test.) 
ecysa.org

Presentation Phase

Timing: Present each word exactly one per second (one-second interval) without pausing.

Pacing Cue: A metronome or timer may be used to ensure consistency.

Delivery: Words can be spoken by the clinician at a steady pace or played via an audio prompt.

Recall Phase (Trials 1–3)

Immediately after the final word of the list, prompt:

“Please tell me all the words you remember, in any order.”

Allow the athlete up to 30 seconds to recall.

Trials: Repeat the same list three times, regardless of how many words were recalled on earlier trials.

“I am going to repeat the same list again. Repeat back as many words as you can remember, in any order, even if you said the word before.” 
ecysa.org

Scoring

1 point for each correctly recalled word on each trial.

Total Score: Sum across all three trials.

5-word list: Maximum = 15.

10-word list: Maximum = 30.

Duplicates do not earn extra points; only first correct instance counts.

Documentation

Record the exact time the third recall trial ends; this timestamp dictates when the Delayed Recall test may begin (≥5 minutes later).

Log which words were recalled on each trial for qualitative analysis if needed.

How Vision Pro Leverages This Protocol

Precise Timing: Internally, CACurrentMediaTime() drives a 1 s timer to display (and/or speak) each word with <0.01 s drift, ensuring fidelity to SCAT5 pacing.

Synchronized Audio & Visual Cues: An AVSpeechSynthesizer speaks each word while the Vision Pro panel simultaneously fades it in/out, aiding both auditory and visual encoding.

Immersive Recall Interface: After presentation, a 3D panel presents blank slots for each word and a mic icon. The athlete triggers speech capture via a gaze+pinch gesture, and the on-device recognizer matches spoken words against the list in real time.

Immediate Feedback & Logging: Correct recalls fill slots in green with a soft chime; errors flash red. The system automatically tallies the total score and stamps the timestamp for the delayed recall timer.

By combining SCAT5’s rigorous “3 × 1 s word” structure with Vision Pro’s high-precision timers, spatial audio/visual synchronization, and hands-free speech input, we ensure clinical fidelity, repeatability, and ease of administration—all while preserving the exact SCAT5 memory-testing protocol.
