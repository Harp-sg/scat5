import Foundation
import SwiftData

@Model
final class TestSession {
    var id: UUID
    var date: Date
    var sessionType: SessionType
    var isComplete: Bool = false
    
    var user: User?
    var athlete: Athlete?
    
    @Relationship(deleteRule: .cascade)
    var symptomResult: SymptomResult?
    
    @Relationship(deleteRule: .cascade)
    var cognitiveResult: CognitiveResult?
    
    @Relationship(deleteRule: .cascade)
    var neurologicalResult: NeurologicalResult?
    
    @Relationship(deleteRule: .cascade)
    var balanceResult: BalanceResult?
    
    // MARK: - Risk Assessment
    
    @Transient
    private var riskEngine = RiskAssessmentEngine()
    
    /// Finds the user's most recent completed baseline test session.
    private var baselineSession: TestSession? {
        guard let user = self.user else { return nil }
        return user.testSessions.first { $0.sessionType == .baseline && $0.isComplete }
    }
    
    /// Calculates the Z-score for the total symptom severity compared to the user's baseline.
    /// A positive score indicates more severe symptoms than the baseline.
    var symptomSeverityZScore: Double? {
        guard let currentScore = symptomResult?.totalScore,
              let baselineScore = baselineSession?.symptomResult?.totalScore else {
            return nil
        }
        
        // Placeholder standard deviation. In a real-world scenario, this would
        // come from clinical population data for this specific metric.
        let standardDeviation = 3.0
        
        return riskEngine.calculateZScore(
            value: Double(currentScore),
            mean: Double(baselineScore),
            standardDeviation: standardDeviation
        )
    }
    
    /// Calculates the Z-score for the immediate memory score compared to the user's baseline.
    /// A negative score indicates worse performance than the baseline.
    var immediateMemoryZScore: Double? {
        guard let currentScore = cognitiveResult?.immediateMemoryTotalScore,
              let baselineScore = baselineSession?.cognitiveResult?.immediateMemoryTotalScore else {
            return nil
        }
        
        // Placeholder standard deviation.
        let standardDeviation = 2.5
        
        return riskEngine.calculateZScore(
            value: Double(currentScore),
            mean: Double(baselineScore),
            standardDeviation: standardDeviation
        )
    }
    
    /// Calculates the Z-score for the orientation score compared to the user's baseline.
    /// A negative score indicates worse performance than the baseline.
    var orientationZScore: Double? {
        guard let currentScore = cognitiveResult?.orientationResult?.correctCount,
              let baselineScore = baselineSession?.cognitiveResult?.orientationResult?.correctCount else {
            return nil
        }
        
        // Placeholder for orientation standard deviation
        let standardDeviation = 1.0 
        
        return riskEngine.calculateZScore(
            value: Double(currentScore),
            mean: Double(baselineScore),
            standardDeviation: standardDeviation
        )
    }
    
    /// Calculates the Z-score for the concentration score compared to the user's baseline.
    /// A negative score indicates worse performance than the baseline.
    var concentrationZScore: Double? {
        guard let currentScore = cognitiveResult?.concentrationResult?.totalScore,
              let baselineScore = baselineSession?.cognitiveResult?.concentrationResult?.totalScore else {
            return nil
        }
        
        // Placeholder standard deviation.
        let standardDeviation = 1.0
        
        return riskEngine.calculateZScore(
            value: Double(currentScore),
            mean: Double(baselineScore),
            standardDeviation: standardDeviation
        )
    }
    
    /// Calculates the Z-score for the delayed recall score compared to the user's baseline.
    /// A negative score indicates worse performance than the baseline.
    var delayedRecallZScore: Double? {
        guard let currentScore = cognitiveResult?.delayedRecallScore,
              let baselineScore = baselineSession?.cognitiveResult?.delayedRecallScore else {
            return nil
        }
        
        // Placeholder standard deviation.
        let standardDeviation = 1.5
        
        return riskEngine.calculateZScore(
            value: Double(currentScore),
            mean: Double(baselineScore),
            standardDeviation: standardDeviation
        )
    }
    
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
        self.neurologicalResult = NeurologicalResult()
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