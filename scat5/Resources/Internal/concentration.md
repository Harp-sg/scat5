
1. Medical Spec
Implement the SCAT5 Concentration subtests exactly as published:

1.1 Digit Span Backwards (4 points)
Sequences A–F, with lengths 3, 4, 5, and 6 digits respectively (six lists in total)

Presentation: One digit per second, at 1 s intervals.

Recall: Athlete repeats the sequence in reverse order immediately after presentation.

Stop Rule: Continue through lists until the athlete fails two consecutive trials, then stop.

Scoring: 1 point for each correctly reversed sequence; maximum = 4.

1.2 Months in Reverse (1 point)
Athlete must recite all 12 months of the year backwards (December → January) in one go.

Scoring: 1 point if the entire sequence is correct; 0 otherwise.

Total Concentration Score: 0–5 points (4 from digits + 1 from months).

2. Volumetric UI Spec (Vision Pro)
2.1 Spatial Layout
Use an ImmersiveSpace with a floating panel (0.6 m × 0.3 m) at ~1.2 m ahead, eye level.

Digit Span Phase:

Display current digit in large 48 pt text, centered.

“Sequence X of Y” label (16 pt) top-left.

Visual timer ring around digit (0.15 m diameter) indicating 1 s pacing.

Response Phase (Digits):

After sequence finishes, show 4 blank slots (0.06 m each) in a row.

Mic icon (0.12 m) below slots to start speech capture.

“Tap to type” toggle to open a numeric keypad (keys 0–9, each 0.06 m).

Months Phase:

Single prompt card: “Recite months backward” text (24 pt).

Mic icon below; optional scrollable month list (12 items) that can be gaze-selected.

2.2 Interaction & Sensors
Timed Digit Display:

Use CACurrentMediaTime() with accuracy ±0.01 s.

Animate each digit fade-in (0.1 s), hold (0.8 s), fade-out (0.1 s).

Speech Recognition:

On mic tap, start SFSpeechRecognizer up to 20 s capture.

Normalize and split tokens (digits or month names).

Gaze+Pinch:

Select keypad digits or month items via gaze dwell ≥200 ms + pinch.

Auto-Advance:

After correct response or timeout (10 s for digits, 15 s for months), auto-move on with a 500 ms confirmation pulse.

2.3 Visual & Audio Feedback
Correct Sequence: blank slots fill with recognized digits in green, + soft chime.

Incorrect: slot flashes red + gentle error tone; incorrect slot remains blank.

Consecutive Failures: after two digit failures, skip remaining lists with a “Stopping digit span due to consecutive errors” message.

Months Correct: play chime; if wrong, highlight first mistake then end.

3. API Contract
swift
Copy
Edit
struct ConcentrationResult: Codable {
  let digitSequences: [[Int]]      // Presented sequences
  let digitResponses: [[Int]]      // Athlete’s reversed responses
  let digitScore: Int              // 0–4
  let monthsResponse: [String]?    // If manual capture
  let monthsScore: Int             // 0 or 1
}

enum ModuleResult {
  case concentration(ConcentrationResult)
}

class ConcentrationModule: SCATModule {
  let id: ModuleID = .concentration
  var digitLists: [[Int]] = DigitListRepository.allLists()
  var presented: [[Int]] = []
  var responses: [[Int]] = []
  var digitScore = 0
  var monthScore = 0

  func start(context: ModuleContext) {
    runDigitSpan(context: context, index: 0, consecutiveFails: 0)
  }

  private func runDigitSpan(context: ModuleContext, index: Int, consecutiveFails: Int) {
    guard index < digitLists.count, consecutiveFails < 2 else {
      runMonths(context: context)
      return
    }
    let seq = digitLists[index]
    presented.append(seq)
    context.ui.showDigitSequence(seq) { response in
      if response == seq.reversed() {
        digitScore += 1
        responses.append(response)
        runDigitSpan(context: context, index: index+1, consecutiveFails: 0)
      } else {
        responses.append(response)
        runDigitSpan(context: context, index: index+1, consecutiveFails: consecutiveFails+1)
      }
    }
  }

  private func runMonths(context: ModuleContext) {
    context.ui.showMonthsRecall() { responseTokens in
      let correctList = MonthRepository.reversedMonths()
      monthScore = (responseTokens == correctList) ? 1 : 0
      finish(context: context)
    }
  }

  private func finish(context: ModuleContext) {
    let result = ConcentrationResult(
      digitSequences: presented,
      digitResponses: responses,
      digitScore: digitScore,
      monthsResponse: nil,   // speech-only
      monthsScore: monthScore
    )
    context.completeModule(with: .concentration(result))
  }

  func complete() -> ModuleResult {
    fatalError("Use context.completeModule instead")
  }
}
4. Data Mapping
TestSession.concentrationScore = digitScore + monthScore

(Optional) store presented & responses in metadata

5. Edge Cases & Validation
2 Consecutive Fails: Abort digit phase early.

No Speech Input: After 10 s silence, prompt “Please type” and open keypad.

Partial Month List: If any month wrong or missing, monthsScore = 0.

Invalid Numeric Entry: Gaze keypad enforces single-digit taps only.

6. Example Payload
json
Copy
Edit
{
  "type": "concentration",
  "digitSequences": [
    [7,2,4],
    [3,8,1,6],
    [5,2,9,4,1],
    [2,9,6,8,3,7]
  ],
  "digitResponses": [
    [4,2,7],
    [6,1,8,3],
    [1,4,9,2,5],
    [7,3,8]      // failed this one
  ],
  "digitScore": 3,
  "monthsScore": 1
}
