import Foundation
import SwiftData

@Model
final class TestSession {
    var id: UUID
    var date: Date
    var sessionType: SessionType
    var isComplete: Bool = false
    
    var user: User?
    
    @Relationship(deleteRule: .cascade)
    var symptomResult: SymptomResult?
    
    @Relationship(deleteRule: .cascade)
    var cognitiveResult: CognitiveResult?
    
    @Relationship(deleteRule: .cascade)
    var coordinationResult: CoordinationResult?
    
    @Relationship(deleteRule: .cascade)
    var balanceResult: BalanceResult?
    
    // Progress tracking
    var completedModules: [String] = []
    
    var progressPercentage: Double {
        let totalModules = 5.0 // Symptom, Cognitive, Coordination, Balance, Delayed Recall
        return Double(completedModules.count) / totalModules
    }
    
    init(id: UUID = UUID(), date: Date, sessionType: SessionType) {
        self.id = id
        self.date = date
        self.sessionType = sessionType
        self.symptomResult = SymptomResult()
        self.cognitiveResult = CognitiveResult()
        self.coordinationResult = CoordinationResult()
        self.balanceResult = BalanceResult()
    }
    
    func markModuleComplete(_ moduleName: String) {
        if !completedModules.contains(moduleName) {
            completedModules.append(moduleName)
        }
        checkIfSessionComplete()
    }
    
    private func checkIfSessionComplete() {
        isComplete = completedModules.count >= 5
    }
}

enum SessionType: String, Codable, CaseIterable {
    case baseline = "Baseline"
    case postExercise = "Post-Exercise Stability"
    case concussion = "Concussion Assessment"
}