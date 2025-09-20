import Foundation

/// Comprehensive data transfer object for sending complete SCAT5 diagnosis results via MultiPeer Connectivity
struct SCAT5DiagnosisTransfer: Codable, Sendable {
    // MARK: - Session Information
    let sessionId: UUID
    let sessionDate: Date
    let sessionType: SessionType
    let isComplete: Bool
    let completedModules: [String]
    let skippedModules: [String]
    let progressPercentage: Double
    
    // MARK: - Patient Information
    let patientInfo: PatientInfo?
    
    // MARK: - Test Results
    let symptomResults: SymptomResultTransfer
    let cognitiveResults: CognitiveResultTransfer
    let neurologicalResults: NeurologicalResultTransfer
    let balanceResults: BalanceResultTransfer
    
    // MARK: - Risk Assessment & Analytics
    let riskAssessment: RiskAssessmentTransfer?
    
    init(from testSession: TestSession, skippedModules: [String] = []) {
        self.sessionId = testSession.id
        self.sessionDate = testSession.date
        self.sessionType = testSession.sessionType
        self.isComplete = testSession.isComplete
        self.completedModules = testSession.completedModules
        self.skippedModules = skippedModules
        self.progressPercentage = testSession.progressPercentage
        
        // Patient info (prefer User over Athlete for more detailed info)
        if let user = testSession.user {
            self.patientInfo = PatientInfo(from: user)
        } else if let athlete = testSession.athlete {
            self.patientInfo = PatientInfo(from: athlete)
        } else {
            self.patientInfo = nil
        }
        
        // Test results
        self.symptomResults = SymptomResultTransfer(from: testSession.symptomResult)
        self.cognitiveResults = CognitiveResultTransfer(from: testSession.cognitiveResult)
        self.neurologicalResults = NeurologicalResultTransfer(from: testSession.neurologicalResult)
        self.balanceResults = BalanceResultTransfer(from: testSession.balanceResult)
        
        // Risk assessment with Z-scores
        self.riskAssessment = RiskAssessmentTransfer(from: testSession)
    }
}

// MARK: - Patient Information Transfer
struct PatientInfo: Codable, Sendable {
    let id: UUID
    let name: String
    let dateOfBirth: Date
    let sport: String
    let position: String?
    let yearsExperience: Int?
    let height: Double?
    let weight: Double?
    let dominantHand: String?
    let hasBaseline: Bool?
    
    init(from user: User) {
        self.id = user.id
        self.name = user.fullName
        self.dateOfBirth = user.dateOfBirth
        self.sport = user.sport
        self.position = user.position.isEmpty ? nil : user.position
        self.yearsExperience = user.yearsExperience
        self.height = user.height
        self.weight = user.weight
        self.dominantHand = user.dominantHand.rawValue
        self.hasBaseline = user.hasBaseline
    }
    
    init(from athlete: Athlete) {
        self.id = athlete.id
        self.name = athlete.name
        self.dateOfBirth = athlete.dateOfBirth
        self.sport = athlete.sport
        self.position = nil
        self.yearsExperience = nil
        self.height = nil
        self.weight = nil
        self.dominantHand = nil
        self.hasBaseline = nil
    }
}

// MARK: - Symptom Results Transfer
struct SymptomResultTransfer: Codable, Sendable {
    let id: UUID
    let ratings: [String: Int]
    let worsensWithPhysicalActivity: Bool
    let worsensWithMentalActivity: Bool
    let percentOfNormal: Int
    let totalScore: Int
    let numberOfSymptoms: Int
    let wasSkipped: Bool
    
    init(from symptomResult: SymptomResult?) {
        if let result = symptomResult {
            self.id = result.id
            self.ratings = result.ratings
            self.worsensWithPhysicalActivity = result.worsensWithPhysicalActivity
            self.worsensWithMentalActivity = result.worsensWithMentalActivity
            self.percentOfNormal = result.percentOfNormal
            self.totalScore = result.totalScore
            self.numberOfSymptoms = result.numberOfSymptoms
            // Check if this appears to be default/skipped values
            self.wasSkipped = result.totalScore == 0 && result.percentOfNormal == 100
        } else {
            // Default values if no result
            self.id = UUID()
            self.ratings = [:]
            self.worsensWithPhysicalActivity = false
            self.worsensWithMentalActivity = false
            self.percentOfNormal = 100
            self.totalScore = 0
            self.numberOfSymptoms = 0
            self.wasSkipped = true
        }
    }
}

// MARK: - Cognitive Results Transfer
struct CognitiveResultTransfer: Codable, Sendable {
    let id: UUID
    let orientationResults: OrientationResultTransfer
    let concentrationResults: ConcentrationResultTransfer
    let immediateMemoryResults: ImmediateMemoryResultTransfer
    let delayedRecallResults: DelayedRecallResultTransfer
    
    init(from cognitiveResult: CognitiveResult?) {
        if let result = cognitiveResult {
            self.id = result.id
            self.orientationResults = OrientationResultTransfer(from: result.orientationResult)
            self.concentrationResults = ConcentrationResultTransfer(from: result.concentrationResult)
            self.immediateMemoryResults = ImmediateMemoryResultTransfer(from: result)
            self.delayedRecallResults = DelayedRecallResultTransfer(from: result)
        } else {
            self.id = UUID()
            self.orientationResults = OrientationResultTransfer(from: nil)
            self.concentrationResults = ConcentrationResultTransfer(from: nil)
            self.immediateMemoryResults = ImmediateMemoryResultTransfer(from: nil)
            self.delayedRecallResults = DelayedRecallResultTransfer(from: nil)
        }
    }
}

struct OrientationResultTransfer: Codable, Sendable {
    let id: UUID
    let questionCount: Int
    let correctCount: Int
    let answers: [String: String]
    let wasSkipped: Bool
    
    init(from orientationResult: OrientationResult?) {
        if let result = orientationResult {
            self.id = result.id
            self.questionCount = result.questionCount
            self.correctCount = result.correctCount
            self.answers = result.answers
            // Check if answers contain "Skipped" values
            self.wasSkipped = result.answers.values.contains("Skipped")
        } else {
            self.id = UUID()
            self.questionCount = 5
            self.correctCount = 0
            self.answers = [:]
            self.wasSkipped = true
        }
    }
}

struct ConcentrationResultTransfer: Codable, Sendable {
    let id: UUID
    let digitSequencesPresented: [[Int]]
    let digitResponses: [[Int]]
    let digitScore: Int
    let monthsCorrect: Bool
    let monthsScore: Int
    let totalScore: Int
    let wasSkipped: Bool
    
    init(from concentrationResult: ConcentrationResult?) {
        if let result = concentrationResult {
            self.id = result.id
            self.digitSequencesPresented = result.digitSequencesPresented
            self.digitResponses = result.digitResponses
            self.digitScore = result.digitScore
            self.monthsCorrect = result.monthsCorrect
            self.monthsScore = result.monthsScore
            self.totalScore = result.totalScore
            // Check if this appears to be perfect default values
            self.wasSkipped = result.digitScore == 4 && result.monthsCorrect == true && result.digitResponses.allSatisfy { $0.isEmpty }
        } else {
            self.id = UUID()
            self.digitSequencesPresented = []
            self.digitResponses = []
            self.digitScore = 0
            self.monthsCorrect = false
            self.monthsScore = 0
            self.totalScore = 0
            self.wasSkipped = true
        }
    }
}

struct ImmediateMemoryResultTransfer: Codable, Sendable {
    let trials: [MemoryTrialTransfer]
    let totalScore: Int
    let wordList: [String]
    let wasSkipped: Bool
    
    init(from cognitiveResult: CognitiveResult?) {
        if let result = cognitiveResult {
            self.trials = result.immediateMemoryTrials.map { MemoryTrialTransfer(from: $0) }
            self.totalScore = result.immediateMemoryTotalScore
            self.wordList = CognitiveResult.getWordList()
            // Check if all trials have perfect scores (indicating skip)
            self.wasSkipped = result.immediateMemoryTrials.allSatisfy { $0.score == $0.words.count }
        } else {
            self.trials = []
            self.totalScore = 0
            self.wordList = []
            self.wasSkipped = true
        }
    }
}

struct MemoryTrialTransfer: Codable, Sendable {
    let id: UUID
    let trialNumber: Int
    let words: [String]
    let recalledWords: [String]
    let score: Int
    
    init(from memoryTrial: MemoryTrial) {
        self.id = memoryTrial.id
        self.trialNumber = memoryTrial.trialNumber
        self.words = memoryTrial.words
        self.recalledWords = memoryTrial.recalledWords
        self.score = memoryTrial.score
    }
}

struct DelayedRecallResultTransfer: Codable, Sendable {
    let wordList: [String]
    let recalledWords: [String]
    let score: Int
    let wasSkipped: Bool
    
    init(from cognitiveResult: CognitiveResult?) {
        if let result = cognitiveResult {
            self.wordList = result.delayedRecallWordList
            self.recalledWords = result.delayedRecalledWords
            self.score = result.delayedRecallScore
            // Check if perfect score (indicating skip)
            self.wasSkipped = result.delayedRecallScore == result.delayedRecallWordList.count && !result.delayedRecallWordList.isEmpty
        } else {
            self.wordList = []
            self.recalledWords = []
            self.score = 0
            self.wasSkipped = true
        }
    }
}

// MARK: - Neurological Results Transfer
struct NeurologicalResultTransfer: Codable, Sendable {
    let id: UUID
    let neckPain: Bool
    let readingNormal: Bool
    let doubleVision: Bool
    let fingerNoseNormal: Bool
    let tandemGaitNormal: Bool
    let tandemGaitTime: TimeInterval?
    let isNormal: Bool
    let wasSkipped: Bool
    
    init(from neurologicalResult: NeurologicalResult?) {
        if let result = neurologicalResult {
            self.id = result.id
            self.neckPain = result.neckPain
            self.readingNormal = result.readingNormal
            self.doubleVision = result.doubleVision
            self.fingerNoseNormal = result.fingerNoseNormal
            self.tandemGaitNormal = result.tandemGaitNormal
            self.tandemGaitTime = result.tandemGaitTime
            self.isNormal = result.isNormal
            // Check if all values are perfect defaults
            self.wasSkipped = !result.neckPain && result.readingNormal && !result.doubleVision && 
                             result.fingerNoseNormal && result.tandemGaitNormal && result.tandemGaitTime == 0.0
        } else {
            self.id = UUID()
            self.neckPain = false
            self.readingNormal = true
            self.doubleVision = false
            self.fingerNoseNormal = true
            self.tandemGaitNormal = true
            self.tandemGaitTime = nil
            self.isNormal = true
            self.wasSkipped = true
        }
    }
}

// MARK: - Balance Results Transfer
struct BalanceResultTransfer: Codable, Sendable {
    let id: UUID
    let errorsByStance: [Int]
    let swayData: [Double]
    let totalErrorScore: Int
    let stanceNames: [String] = ["Double Leg Stance", "Single Leg Stance", "Tandem Stance"]
    let wasSkipped: Bool
    
    init(from balanceResult: BalanceResult?) {
        if let result = balanceResult {
            self.id = result.id
            self.errorsByStance = result.errorsByStance
            self.swayData = result.swayData
            self.totalErrorScore = result.totalErrorScore
            // Check if all errors are 0 (indicating perfect/skipped)
            self.wasSkipped = result.errorsByStance.allSatisfy { $0 == 0 } && result.swayData.isEmpty
        } else {
            self.id = UUID()
            self.errorsByStance = [0, 0, 0]
            self.swayData = []
            self.totalErrorScore = 0
            self.wasSkipped = true
        }
    }
}

// MARK: - Risk Assessment Transfer
struct RiskAssessmentTransfer: Codable, Sendable {
    let symptomSeverityZScore: Double?
    let immediateMemoryZScore: Double?
    let orientationZScore: Double?
    let concentrationZScore: Double?
    let delayedRecallZScore: Double?
    let hasBaseline: Bool
    let riskLevel: RiskLevel
    let recommendations: [String]
    
    init(from testSession: TestSession) {
        self.symptomSeverityZScore = testSession.symptomSeverityZScore
        self.immediateMemoryZScore = testSession.immediateMemoryZScore
        self.orientationZScore = testSession.orientationZScore
        self.concentrationZScore = testSession.concentrationZScore
        self.delayedRecallZScore = testSession.delayedRecallZScore
        self.hasBaseline = (testSession.user?.hasBaseline ?? false) || testSession.athlete != nil
        
        // Calculate risk level based on available data
        self.riskLevel = Self.calculateRiskLevel(from: testSession)
        self.recommendations = Self.generateRecommendations(riskLevel: self.riskLevel, testSession: testSession)
    }
    
    private static func calculateRiskLevel(from session: TestSession) -> RiskLevel {
        // Simplified risk assessment logic
        let symptomScore = session.symptomResult?.totalScore ?? 0
        let balanceErrors = session.balanceResult?.totalErrorScore ?? 0
        let cognitiveIssues = !(session.neurologicalResult?.isNormal ?? true)
        
        if symptomScore > 30 || balanceErrors > 15 || cognitiveIssues {
            return .high
        } else if symptomScore > 15 || balanceErrors > 8 {
            return .moderate
        } else if symptomScore > 5 || balanceErrors > 3 {
            return .low
        } else {
            return .normal
        }
    }
    
    private static func generateRecommendations(riskLevel: RiskLevel, testSession: TestSession) -> [String] {
        var recommendations: [String] = []
        
        switch riskLevel {
        case .high:
            recommendations.append("Immediate medical evaluation recommended")
            recommendations.append("Remove from play immediately")
            recommendations.append("Follow return-to-play protocol")
        case .moderate:
            recommendations.append("Medical evaluation recommended")
            recommendations.append("Monitor symptoms closely")
            recommendations.append("Consider removing from play")
        case .low:
            recommendations.append("Continue monitoring")
            recommendations.append("Re-test if symptoms worsen")
        case .normal:
            recommendations.append("No immediate concerns")
            recommendations.append("Continue regular monitoring")
        }
        
        // Add specific recommendations based on test results
        if let symptomResult = testSession.symptomResult, symptomResult.totalScore > 10 {
            recommendations.append("Address reported symptoms")
        }
        
        if let balanceResult = testSession.balanceResult, balanceResult.totalErrorScore > 8 {
            recommendations.append("Balance assessment recommended")
        }
        
        if let neuroResult = testSession.neurologicalResult, !neuroResult.isNormal {
            recommendations.append("Neurological evaluation recommended")
        }
        
        return recommendations
    }
}

// MARK: - Helper Extensions for Encoding/Decoding
extension SCAT5DiagnosisTransfer {
    /// Encode the diagnosis transfer object to Data for MultiPeer Connectivity transmission
    func encodeForTransmission() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }
    
    /// Decode a diagnosis transfer object from Data received via MultiPeer Connectivity
    static func decodeFromTransmission(_ data: Data) throws -> SCAT5DiagnosisTransfer {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(SCAT5DiagnosisTransfer.self, from: data)
    }
    
    /// Generate a summary report string for quick review
    func generateSummaryReport() -> String {
        var report = """
        SCAT5 Assessment Summary
        ========================
        
        Patient: \(patientInfo?.name ?? "Unknown")
        Date: \(sessionDate.formatted(date: .abbreviated, time: .shortened))
        Session Type: \(sessionType.rawValue)
        Completion: \(isComplete ? "Complete" : "Incomplete") (\(Int(progressPercentage * 100))%)
        
        """
        
        if !skippedModules.isEmpty {
            report += """
            SKIPPED MODULES:
            ================
            \(skippedModules.joined(separator: ", "))
            (Default values used for skipped modules)
            
            """
        }
        
        report += """
        RESULTS SUMMARY:
        ================
        
        Symptom Evaluation: \(symptomResults.wasSkipped ? "[SKIPPED]" : "")
        - Total Score: \(symptomResults.totalScore)/132
        - Number of Symptoms: \(symptomResults.numberOfSymptoms)
        - Physical Activity Impact: \(symptomResults.worsensWithPhysicalActivity ? "Yes" : "No")
        - Mental Activity Impact: \(symptomResults.worsensWithMentalActivity ? "Yes" : "No")
        
        Cognitive Assessment:
        - Orientation Score: \(cognitiveResults.orientationResults.correctCount)/\(cognitiveResults.orientationResults.questionCount) \(cognitiveResults.orientationResults.wasSkipped ? "[SKIPPED]" : "")
        - Immediate Memory Total: \(cognitiveResults.immediateMemoryResults.totalScore)/15 \(cognitiveResults.immediateMemoryResults.wasSkipped ? "[SKIPPED]" : "")
        - Concentration Score: \(cognitiveResults.concentrationResults.totalScore)/5 \(cognitiveResults.concentrationResults.wasSkipped ? "[SKIPPED]" : "")
        - Delayed Recall Score: \(cognitiveResults.delayedRecallResults.score)/5 \(cognitiveResults.delayedRecallResults.wasSkipped ? "[SKIPPED]" : "")
        
        Neurological Examination: \(neurologicalResults.wasSkipped ? "[SKIPPED]" : "")
        - Overall Status: \(neurologicalResults.isNormal ? "Normal" : "Abnormal")
        - Neck Pain: \(neurologicalResults.neckPain ? "Present" : "Absent")
        - Double Vision: \(neurologicalResults.doubleVision ? "Present" : "Absent")
        - Coordination: \(neurologicalResults.fingerNoseNormal ? "Normal" : "Abnormal")
        
        Balance Assessment (mBESS): \(balanceResults.wasSkipped ? "[SKIPPED]" : "")
        - Total Errors: \(balanceResults.totalErrorScore)
        - Double Leg: \(balanceResults.errorsByStance[0]) errors
        - Single Leg: \(balanceResults.errorsByStance[1]) errors  
        - Tandem: \(balanceResults.errorsByStance[2]) errors
        
        """
        
        if let riskAssessment = riskAssessment {
            report += """
            
            RISK ASSESSMENT:
            ================
            Risk Level: \(riskAssessment.riskLevel.rawValue)
            
            Recommendations:
            """
            for recommendation in riskAssessment.recommendations {
                report += "\n- \(recommendation)"
            }
            
            if riskAssessment.hasBaseline {
                report += "\n\nBaseline Comparison (Z-Scores):"
                if let symptomZ = riskAssessment.symptomSeverityZScore {
                    report += "\n- Symptom Severity: \(String(format: "%.2f", symptomZ))"
                }
                if let memoryZ = riskAssessment.immediateMemoryZScore {
                    report += "\n- Immediate Memory: \(String(format: "%.2f", memoryZ))"
                }
                if let orientationZ = riskAssessment.orientationZScore {
                    report += "\n- Orientation: \(String(format: "%.2f", orientationZ))"
                }
                if let concentrationZ = riskAssessment.concentrationZScore {
                    report += "\n- Concentration: \(String(format: "%.2f", concentrationZ))"
                }
                if let recallZ = riskAssessment.delayedRecallZScore {
                    report += "\n- Delayed Recall: \(String(format: "%.2f", recallZ))"
                }
            }
        }
        
        if !skippedModules.isEmpty {
            report += """
            
            
            NOTE: Some modules were skipped and default values were used.
            This may affect the accuracy of the assessment.
            """
        }
        
        report += "\n\n========================\nEnd of Report"
        
        return report
    }
}