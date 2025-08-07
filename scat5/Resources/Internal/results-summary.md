## 1. Medical Spec

The **Results Summary** module aggregates all SCAT5 sub-test outcomes into one clear display. It must:

1. **List each domain’s raw score** exactly as per SCAT5:
   - **Symptom Count** (0–22) and **Severity** (0–132)  
   - **Orientation** (0–5)  
   - **Immediate Memory** (0–15 or 0–30)  
   - **Concentration** (0–5)  
   - **Delayed Recall** (0–5 or 0–10)  
   - **Balance Error Score** (0–30)  
   - **Neuro Exam** (Normal / Abnormal)  

2. **Compare to Baseline** (if available):
   - Show **Δ (difference)** = Post-Injury − Baseline for each numeric domain.  
   - Compute a **Z-score**:  
     \[  
       Z = \tfrac{\text{PostInjury} - \text{BaselineMean}}{\text{BaselineSD}}  
     \]  
     using the athlete’s stored baseline mean & SD (or published norms).  

3. **Flag clinically significant changes**:
   - Highlight any Δ or Z beyond configured thresholds (e.g.  
     • Δ > 30% in symptoms  
     • Z > 1.5 in cognitive or balance)  
   - Provide a **Return-to-Play Recommendation** per SCAT5 guidelines:
     - **Green**: within baseline/normal  
     - **Yellow**: mild deviation—retest in 24 h  
     - **Red**: significant deviation—no return to play  

4. **Clinician Notes & Sign-off**:
   - Free-text field for notes.  
   - “Clinician:” signature line (auto-filled from profile).  
   - Date/time stamp.

---

## 2. Volumetric UI Spec (Vision Pro)

### 2.1 Layout

- **Overview Panel** (1.2 m wide × 0.7 m tall) centered ~1.3 m ahead:
  - Top: Title “SCAT5 Results Summary” + date/time stamp (16 pt).
  - Middle: **Grid of 7 cards** (2 rows × 4 cols, last cell blank if needed):
    - Each card (~0.28 m × 0.28 m) shows:
      - Domain name (14 pt)
      - Raw score (24 pt, bold)
      - Δ or Z below (12 pt)
      - A **color ring** border (green/yellow/red) indicating status.
  - Bottom:  
    - **Return-to-Play Recommendation** text banner (18 pt, bold).  
    - **Notes** button to expand the notes field.  
    - **Sign-Off** button (“Clinician Sign-Off”) to finalize session.

### 2.2 Interaction

- **Gaze + Pinch** on any card to expand details:
  - Show a volumetric sub-panel with historical trend chart (sparkline) for that domain.
- **Notes Entry**:
  - Gaze-focus text area pops up; voice dictation or on-panel keyboard available.
- **Sign-Off**:
  - Gaze + pinch brings up clinician list (from profile); pinch again to confirm.
- **Progress Ring Animation**:
  - On loading, each card’s border animates from gray to its status color.

---

## 3. API Contract

```swift
struct SummaryComparison: Codable {
  let baselineRaw: Int?     // nil if no baseline
  let postRaw: Int
  let delta: Int?           // postRaw - baselineRaw
  let zScore: Double?       // computed if baseline SD available
  let status: Status        // .green, .yellow, .red
}

struct ResultsSummary: Codable {
  let timestamp: TimeInterval
  let symptom: SummaryComparison
  let orientation: SummaryComparison
  let memory: SummaryComparison
  let concentration: SummaryComparison
  let delayedRecall: SummaryComparison
  let balance: SummaryComparison
  let neuroNormal: Bool
  let recommendation: String
  let clinicianID: UUID
  let notes: String?
}

enum ModuleResult {
  case summary(ResultsSummary)
}

class SummaryModule: SCATModule {
  func start(context: ModuleContext) {
    let session = context.session
    let baseline = context.athlete.baselineSession

    func makeComp(post: Int, base: Int?, sd: Double?) -> SummaryComparison {
      let d = base.map { post - $0 }
      let z = (d != nil && sd != nil) ? Double(d!) / sd! : nil
      let status = SummaryModule.evaluateStatus(delta: d, zScore: z)
      return SummaryComparison(
        baselineRaw: base,
        postRaw: post,
        delta: d,
        zScore: z,
        status: status
      )
    }

    let summary = ResultsSummary(
      timestamp: CACurrentMediaTime(),
      symptom: makeComp(post: session.symptomSeverity,
                       base: baseline?.symptomSeverity,
                       sd: baseline?.symptomSeveritySD),
      orientation: makeComp(post: session.orientationScore,
                            base: baseline?.orientationScore,
                            sd: baseline?.orientationScoreSD),
      memory: makeComp(post: session.memoryScore,
                       base: baseline?.memoryScore,
                       sd: baseline?.memoryScoreSD),
      concentration: makeComp(post: session.concentrationScore,
                              base: baseline?.concentrationScore,
                              sd: baseline?.concentrationScoreSD),
      delayedRecall: makeComp(post: session.delayedRecallScore,
                              base: baseline?.delayedRecallScore,
                              sd: baseline?.delayedRecallScoreSD),
      balance: makeComp(post: session.balanceErrorsTotal,
                        base: baseline?.balanceErrorsTotal,
                        sd: baseline?.balanceErrorsSD),
      neuroNormal: session.neuroExamNormal,
      recommendation: SummaryModule.computeRecommendation(from: summary),
      clinicianID: context.currentClinician.id,
      notes: context.ui.enteredNotes
    )

    context.completeModule(with: .summary(summary))
  }

  static func evaluateStatus(delta: Int?, zScore: Double?) -> Status { ... }
  static func computeRecommendation(from s: ResultsSummary) -> String { ... }
}
4. Data Mapping
Persist the entire ResultsSummary in TestSession.summary JSON field.

Extract individual fields for quick queries (e.g. TestSession.wasConcussionLikely = (status == .red)).

5. Edge Cases & Validation
Missing Baseline: show “No baseline” in comparisons and default status logic to normative thresholds.

SD = 0 or nil: omit Z-score and rely on Δ or normative cutoffs.

Clinician skips sign-off: block session completion until sign-off is confirmed.

Overlong notes: cap at 500 characters.

6. Example Payload
json
Copy
Edit
{
  "type": "summary",
  "timestamp": 6876200.112,
  "symptom": {
    "baselineRaw": 10,
    "postRaw": 25,
    "delta": 15,
    "zScore": 2.5,
    "status": "red"
  },
  "orientation": { ... },
  "memory": { ... },
  "concentration": { ... },
  "delayedRecall": { ... },
  "balance": { ... },
  "neuroNormal": false,
  "recommendation": "No same-day return to play.",
  "clinicianID": "550e8400-e29b-41d4-a716-446655440000",
  "notes": "Athlete exhibited >2 SD drop in memory."
}
