import Foundation
import SwiftData

@Model
final class BalanceResult {
    var id: UUID
    var testSession: TestSession?
    
    // Updated properties to match the new spec
    var errorsByStance: [Int] = [0, 0, 0] // Index 0: Double, 1: Single, 2: Tandem
    var swayData: [Double] = [] // Optional sway data
    
    // Computed property for total errors
    var totalErrorScore: Int {
        errorsByStance.reduce(0, +)
    }
    
    init(id: UUID = UUID()) {
        self.id = id
    }
}

// BalanceTrialResult is no longer needed as we are using a simple array of Ints.

// Updated BalanceStance enum to only include the 3 required stances for mBESS
enum BalanceStance: String, Codable, CaseIterable, Identifiable {
    var id: String { rawValue }
    
    case doubleLeg = "Double Leg Stance"
    case singleLeg = "Single Leg Stance"
    case tandem = "Tandem Stance"
}