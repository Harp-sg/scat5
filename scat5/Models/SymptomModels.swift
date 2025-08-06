import Foundation
import SwiftData

@Model
final class SymptomResult {
    var id: UUID
    var items: [SymptomItem]
    var testSession: TestSession?
    
    var totalScore: Int {
        items.reduce(0) { $0 + $1.severity }
    }
    
    var numberOfSymptoms: Int {
        items.filter { $0.severity > 0 }.count
    }

    init(id: UUID = UUID(), items: [SymptomItem] = Symptom.allCases.map { SymptomItem(symptom: $0) }) {
        self.id = id
        self.items = items
    }
}

struct SymptomItem: Codable, Identifiable, Hashable {
    var id: String { symptom.rawValue }
    let symptom: Symptom
    var severity: Int = 0
}

enum Symptom: String, Codable, CaseIterable {
    case headache = "Headache", pressureInHead = "Pressure in head", neckPain = "Neck Pain", nauseaOrVomiting = "Nausea or vomiting", dizziness = "Dizziness", blurredVision = "Blurred vision", balanceProblems = "Balance problems", sensitivityToLight = "Sensitivity to light", sensitivityToNoise = "Sensitivity to noise", feelingSlowedDown = "Feeling slowed down", feelingLikeInAFog = "Feeling like in a fog", dontFeelRight = "Don't feel right", difficultyConcentrating = "Difficulty concentrating", difficultyRemembering = "Difficulty remembering", fatigueOrLowEnergy = "Fatigue or low energy", confusion = "Confusion", drowsiness = "Drowsiness", moreEmotional = "More emotional", irritability = "Irritability", sadness = "Sadness", nervousOrAnxious = "Nervous or anxious", troubleFallingAsleep = "Trouble falling asleep"
}