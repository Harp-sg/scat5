import Foundation
import SwiftData

@Model
final class BalanceResult {
    var id: UUID
    @Relationship(deleteRule: .cascade)
    var trials: [BalanceTrialResult] = []
    var testSession: TestSession?

    var totalErrorScore: Int {
        trials.reduce(0) { $0 + $1.errorCount }
    }
    
    init(id: UUID = UUID()) {
        self.id = id
        self.trials = BalanceStance.allCases.map { BalanceTrialResult(stance: $0) }
    }
}

@Model
final class BalanceTrialResult {
    var id: UUID
    var stance: BalanceStance
    var errorCount: Int = 0
    
    init(id: UUID = UUID(), stance: BalanceStance, errorCount: Int = 0) {
        self.id = id
        self.stance = stance
        self.errorCount = errorCount
    }
}

enum BalanceStance: String, Codable, CaseIterable, Identifiable {
    var id: String { rawValue }
    case doubleLegFirm = "Double Leg (Firm)", singleLegFirm = "Single Leg (Firm)", tandemLegFirm = "Tandem (Firm)", doubleLegFoam = "Double Leg (Foam)", singleLegFoam = "Single Leg (Foam)", tandemLegFoam = "Tandem (Foam)"
}