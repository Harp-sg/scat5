import Foundation
import SwiftData

@Model
final class SymptomResult {
    var id: UUID
    var testSession: TestSession?
    
    // Updated properties to match the new spec
    var ratings: [String: Int] = [:]
    var worsensWithPhysicalActivity: Bool = false
    var worsensWithMentalActivity: Bool = false
    var percentOfNormal: Int = 100

    // Computed properties as per the data mapping
    var totalScore: Int {
        ratings.values.reduce(0, +)
    }
    
    var numberOfSymptoms: Int {
        ratings.values.filter { $0 > 0 }.count
    }

    init(id: UUID = UUID()) {
        self.id = id
        // Initialize ratings dictionary with all symptoms set to 0
        for symptom in Symptom.allCases {
            self.ratings[symptom.rawValue] = 0
        }
    }
}

// The SymptomItem struct is no longer needed.

// Updated Symptom enum to match the exact medical spec
enum Symptom: String, Codable, CaseIterable {
    case headache = "Headache"
    case pressureInHead = "Pressure in head"
    case neckPain = "Neck Pain"
    case nauseaOrVomiting = "Nausea or vomiting"
    case lightSensitivity = "Light sensitivity"
    case noiseSensitivity = "Noise sensitivity"
    case feelingSlowedDown = "Feeling slowed down"
    case feelingLikeInAFog = "Feeling like in a fog"
    case dontFeelRight = "Don’t feel right"
    case difficultyConcentrating = "Difficulty concentrating"
    case difficultyRemembering = "Difficulty remembering"
    case fatigueOrLowEnergy = "Fatigue or low energy"
    case confusion = "Confusion"
    case drowsiness = "Drowsiness"
    case moreEmotional = "More emotional"
    case irritability = "Irritability"
    case sadness = "Sadness"
    case nervousOrAnxious = "Nervous or anxious"
    case balanceProblems = "Balance problems"
    case dizziness = "Dizziness"
    case blurredVision = "Blurred vision"
    case troubleFallingAsleep = "Trouble falling asleep"
}