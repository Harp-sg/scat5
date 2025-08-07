
. Medical Spec

Implement the Standard Assessment of Concussion (SAC) Orientation module exactly as in SCAT5 (5th Edition), including both the canonical orientation questions and optional on‑field Maddocks questions.

1.1 Orientation Questions (5 points total)

What month is it?

What date is it today?

What day of the week is it?

What year is it?

What time is it right now? (within ±1 hour)

Scoring: 1 point per correct answer; maximum 5 points.Responses outside the ±1‑hour window count as incorrect.

1.2 Maddocks On‑Field Questions (5 points total, optional)

Use these for sideline assessments where sport context improves sensitivity:

What venue are we at today?

Which half is it now?

Who scored last in this game?

Who are we playing today?

Scoring: 1 point per correct answer; maximum 4–5 points depending on question set chosen.Include Maddocks only in Post‑Injury Mode and under clinician selection.

2. Volumetric UI Spec (Vision Pro)

2.1 Spatial Layout

Present each question on its own floating card in an ImmersiveSpace, centered ~1.2 m in front of the user at eye level.

Card size: 0.5 m wide × 0.2 m tall. Background: semi‑translucent ultraThinMaterial.

Display a question number badge (e.g. “Q1 of 5”) in the top‑left corner of the card (0.05 m diameter).

Under question text, render a grid of selectable responses:

For Month: 12 buttons in two rows (6×2). Button size 0.08 m × 0.08 m.

For Date: numeric keypad 1–31 in a scrollable 3×11 grid; each button 0.06 m.

For Day: 7 buttons (Sun–Sat) laid out horizontally; each 0.08 m.

For Year & Time: text field for manual entry or voice input (text field 0.4 m × 0.08 m).

Navigation controls: Next and Back buttons (each 0.1 m × 0.05 m) anchored to the bottom of the card.

2.2 Interaction & Sensor Integration

Gaze + Pinch Selection: Attach SpatialPointerInteraction to each response button. Gaze dwell ≥200 ms highlights the button; a pinch (thumb & index contact) confirms.

Scrolling Date Grid: Support hand-swipe gesture over the grid to scroll, or gaze-dwell on arrow icons above/below.

Voice Input Fallback: If the clinician or athlete says “Month: July” while gazing at the month question, use SFSpeechRecognizer to parse “July” and auto‑select button when confidence ≥0.9.

Auto-Advance: Upon valid selection, auto‑move to next question after a 300 ms confirmation pulse, unless clinician presses “Back”.

2.3 Visual & Audio Feedback

Selected button pulses scale by +10% and border glows accent color (#399EE6).

On question completion, play a soft “ding” audio cue.

If no selection within 30 s, show a subtle prompt “Please respond to continue.”

3. API Contract

struct OrientationResult: Codable {
  let questionCount: Int      // 5 or number of Maddocks used
  let correctCount: Int       // 0–questionCount
  let answers: [Int: String]  // questionIndex → responseValue
}

enum ModuleResult {
  case orientation(OrientationResult)
  // … other modules
}

class OrientationModule: SCATModule {
  let id: ModuleID = .orientation
  let title = "Orientation"
  var questions: [OrientationQuestion] = []
  var answers: [Int: String] = [:]
  var correctCount = 0

  func start(context: ModuleContext) {
    // 1. Build question set based on context.mode and config
    questions = OrientationQuestion.defaultSet(mode: context.mode)
    context.ui.showQuestions(questions)
  }

  func recordAnswer(questionIndex: Int, response: String) {
    answers[questionIndex] = response
    if questions[questionIndex].isCorrect(response) {
      correctCount += 1
    }
    context.ui.highlightCorrectness(at: questionIndex, correct: questions[questionIndex].isCorrect(response))
  }

  func complete() -> ModuleResult {
    let result = OrientationResult(
      questionCount: questions.count,
      correctCount: correctCount,
      answers: answers
    )
    return .orientation(result)
  }
}

Types:

struct OrientationQuestion {
  let prompt: String
  let choices: [String]
  let correctAnswer: String
  static func defaultSet(mode: SessionMode) -> [OrientationQuestion] {
    if mode == .postInjury {
      return MaddocksQuestion.defaultList()
    } else {
      return [
        // Month, Date, Day, Year, Time questions
      ]
    }
  }
  func isCorrect(_ response: String) -> Bool {
    // case‑insensitive comparison; for time, allow ±1h
  }
}

4. Data Mapping

TestSession.orientationScore = OrientationResult.correctCount

Persist answers in TestSession.metadata if detailed audit is needed.

5. Edge Cases & Validation

No response: After 60 s of inactivity, UI highlights all buttons in sequence to prompt.

Speech ambiguity: If multiple matches (e.g. “two” vs “too”), prompt “Did you mean…?” with choices.

Time question: Accept formats “2:30 PM”, “14:30”, and compute within ±1 hour.

Date bounds: Reject invalid dates (e.g. Feb 30) with inline error message.

6. Example Payload

{
  "type": "orientation",
  "questionCount": 5,
  "correctCount": 4,
  "answers": {
    "0": "August",
    "1": "7",
    "2": "Thursday",
    "3": "2025",
    "4": "15:00"
  }
}

