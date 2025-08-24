
1. Medical Spec

Implement exactly the SCAT5 Symptom Checklist (5th Edition) as published in the British Journal of Sports Medicine. This includes 22 symptoms rated on a 0–6 Likert scale.

Symptom List (exact order):

Headache

"Pressure in head"

Neck pain

Nausea or vomiting

Light sensitivity

Noise sensitivity

Feeling slowed down

Feeling "like in a fog"

"Don’t feel right"

Difficulty concentrating

Difficulty remembering

Fatigue or low energy

Confusion

Drowsiness

More emotional

Irritability

Sadness

Nervous or anxious

Balance problems

Dizziness

Blurred vision

"Trouble falling asleep" (omit immediately post-injury if acute)

Additional Items:

Worse with physical activity? (Yes/No)

Worse with mental activity? (Yes/No)

Percent of normal overall feeling (slider 0–100)

Scoring:

Symptom Count: number of ratings > 0 (max 22; max 21 if "sleep" omitted)

Symptom Severity: sum of all ratings (max 132)

2. Volumetric UI Spec (Vision Pro)

Layout & Spatial Placement

Use an ImmersiveSpace with a curved 3D panel positioned ~1.3 m in front of the user, subtending ~60° horizontal field. Panel radius = 0.8 m, height starting at user eye level and extending downward by 0.6 m.

Symptoms rendered as cards in a vertical carousel: each card is 0.4 m wide × 0.08 m tall, spaced 0.02 m apart in Z-depth to suggest layering.

The central card is highlighted by being 0.02 m closer; off-center cards fade to 0.7 opacity.

Beneath the carousel, place two toggle buttons for "Worse with Physical/Mental Activity" side by side, each 0.15 m × 0.08 m.

Below toggles, a horizontal slider 0.6 m long × 0.04 m tall for % normal, with a draggable thumb of 0.06 m diameter.

Interaction & Sensor Integration

Gaze-Driven Selection: Attach a SpatialPointerInteraction to each card and slider. When gaze rests ≥300 ms, show a subtle loader ring. On pinch (hand anchor index & thumb), confirm selection.

Carousel Scrolling: Detect hand-swipe gestures (via hand-tracking Joints.IndexTip movement >0.1 m horizontally) or gaze dwell on off-center cards to scroll list.

Pinch-to-Toggle: Tapping toggles via gaze + pinch; toggles switch states with haptic feedback on linked Apple Watch (optional).

Slider Drag: Use hand pinch + drag along slider rail, or gaze + repeated pinch to increment/decrement in 1% steps; also support voice commands "Set percent normal to 80%" via SFSpeechRecognizer.

Speech Recognition Fallback: If clinician says "Headache four" while gazing at symptom card, capture that with confidence ≥0.85 to set rating.

Visual & Audio Feedback

Selected card scales by +5% and border glows accent color (#399EE6).

Toggle buttons change from outline to filled accent when active.

Slider thumb pops outward when grabbed.

Audio cues: soft click on selection, gentle chime on module completion.

3. API Contract

struct SymptomResult: Codable {
  let ratings: [String: Int]            // symptom name → 0–6
  let worsensPhysical: Bool             // Yes/No
  let worsensMental: Bool               // Yes/No
  let percentNormal: Int                // 0–100
}
enum ModuleResult {
  case symptom(SymptomResult)
  // ... other modules
}

class SymptomModule: SCATModule {
  var ui: SymptomUIController  // handles 3D panel, gestures, speech

  func start(context: ModuleContext) {
    ui.loadSymptoms(names: symptomList)
    ui.showToggles()
    ui.showSlider()
  }

  func complete() -> ModuleResult {
    let result = SymptomResult(
      ratings: ui.currentRatings,
      worsensPhysical: ui.physicalToggleState,
      worsensMental: ui.mentalToggleState,
      percentNormal: ui.sliderValue
    )
    return .symptom(result)
  }
}

4. Data Mapping

TestSession.symptomCount ← result.ratings.filter{ $0.value>0 }.count

TestSession.symptomSeverity ← result.ratings.values.reduce(0,+)

TestSession.worsensWithPhysical ← result.worsensPhysical

TestSession.worsensWithMental ← result.worsensMental

TestSession.percentNormal ← result.percentNormal

5. Edge Cases & Validation

Missing ratings: default any unselected symptom to 0.

Omit "Trouble falling asleep" in Post-Injury Mode: module UI hides card 22 and adjusts count max to 21.

Gesture conflicts: if pinch not detected, allow gaze dwell + timer as fallback selection.

Speech misinterpretation: confirm ambiguous speech with a follow-up prompt ("Did you mean rating 4?").

6. Example Payload

{
  "type": "symptom",
  "ratings": {
    "Headache": 2,
    "Pressure in head": 0,
    "Neck pain": 1,
    // ... all 22 keys
  },
  "worsensPhysical": true,
  "worsensMental": false,
  "percentNormal": 85
}

