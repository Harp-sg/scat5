import Foundation
import SwiftData
import SwiftUI

@Model
final class SaccadesResult {
    var id: UUID
    var testSession: TestSession?
    
    // Test metadata
    var testDate: Date
    var testDuration: TimeInterval
    
    // Trial data (stored as JSON)
    var horizontalTrialsData: Data
    var verticalTrialsData: Data
    
    // Aggregate metrics
    var meanLatencyMs: Double?
    var medianLatencyMs: Double?
    var bestLatencyMs: Double?
    var worstLatencyMs: Double?
    var standardDeviationMs: Double?
    
    // Error metrics
    var errorRate: Double
    var timeoutRate: Double
    var anticipationRate: Double
    var invalidatedCount: Int
    
    // Head motion metrics
    var maxHeadMotionDeg: Double
    var averageHeadMotionDeg: Double
    var headMotionViolations: Int
    
    // Clinical indicators
    var overallScore: Int
    var hasConcussionIndicators: Bool
    
    // Computed convenience properties
    var horizontalTrials: [SaccadeTrial] {
        get {
            guard let trials = try? JSONDecoder().decode([SaccadeTrial].self, from: horizontalTrialsData) else {
                return []
            }
            return trials
        }
        set {
            horizontalTrialsData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }
    
    var verticalTrials: [SaccadeTrial] {
        get {
            guard let trials = try? JSONDecoder().decode([SaccadeTrial].self, from: verticalTrialsData) else {
                return []
            }
            return trials
        }
        set {
            verticalTrialsData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }
    
    var totalTrials: Int {
        horizontalTrials.count + verticalTrials.count
    }
    
    var validTrials: Int {
        horizontalTrials.filter { $0.isValid }.count + verticalTrials.filter { $0.isValid }.count
    }
    
    init(
        id: UUID = UUID(),
        testDate: Date = Date(),
        horizontalTrials: [SaccadeTrial] = [],
        verticalTrials: [SaccadeTrial] = []
    ) {
        self.id = id
        self.testDate = testDate
        self.testDuration = 0
        self.horizontalTrialsData = (try? JSONEncoder().encode(horizontalTrials)) ?? Data()
        self.verticalTrialsData = (try? JSONEncoder().encode(verticalTrials)) ?? Data()
        
        // Initialize with default values
        self.meanLatencyMs = nil
        self.medianLatencyMs = nil
        self.bestLatencyMs = nil
        self.worstLatencyMs = nil
        self.standardDeviationMs = nil
        self.errorRate = 0
        self.timeoutRate = 0
        self.anticipationRate = 0
        self.invalidatedCount = 0
        self.maxHeadMotionDeg = 0
        self.averageHeadMotionDeg = 0
        self.headMotionViolations = 0
        self.overallScore = 0
        self.hasConcussionIndicators = false
    }
    
    // Method to update results from test data
    func updateFromTestResults(_ testResults: SaccadesTestResults) {
        self.horizontalTrials = testResults.horizontalTrials
        self.verticalTrials = testResults.verticalTrials
        self.meanLatencyMs = testResults.meanLatencyMs
        self.medianLatencyMs = testResults.medianLatencyMs
        self.errorRate = testResults.errorRate
        self.invalidatedCount = testResults.invalidatedCount
        self.maxHeadMotionDeg = testResults.maxHeadMotionDeg
        self.overallScore = testResults.overallScore
        self.hasConcussionIndicators = testResults.hasConcussionIndicators
        
        // Calculate additional metrics
        let allTrials = horizontalTrials + verticalTrials
        let validLatencies = allTrials.compactMap { $0.latencyMs }
        
        self.bestLatencyMs = validLatencies.min()
        self.worstLatencyMs = validLatencies.max()
        
        if !validLatencies.isEmpty {
            let mean = validLatencies.reduce(0, +) / Double(validLatencies.count)
            let variance = validLatencies.reduce(0) { $0 + pow($1 - mean, 2) } / Double(validLatencies.count)
            self.standardDeviationMs = sqrt(variance)
        }
        
        let totalTrials = Double(allTrials.count)
        if totalTrials > 0 {
            self.timeoutRate = Double(allTrials.filter { $0.outcome == .timeout }.count) / totalTrials
            self.anticipationRate = Double(allTrials.filter { $0.outcome == .anticipation }.count) / totalTrials
        }
        
        self.averageHeadMotionDeg = allTrials.isEmpty ? 0 : 
            allTrials.map { ($0.headYawDeg + $0.headPitchDeg) / 2 }.reduce(0, +) / Double(allTrials.count)
        
        self.headMotionViolations = allTrials.filter { $0.outcome == .invalidated }.count
    }
}

// MARK: - Enums and Supporting Types

enum SaccadeDirection: String, Codable, CaseIterable {
    case left, right, up, down
    
    var displayName: String {
        switch self {
        case .left: return "Left"
        case .right: return "Right"
        case .up: return "Up"
        case .down: return "Down"
        }
    }
}

enum SaccadeTestDirection: String, Codable {
    case horizontal, vertical
    
    var displayName: String {
        switch self {
        case .horizontal: return "Horizontal"
        case .vertical: return "Vertical"
        }
    }
}

enum TrialOutcome: String, Codable {
    case correct
    case wrongTarget
    case timeout
    case invalidated
    case anticipation
    
    var displayName: String {
        switch self {
        case .correct: return "Correct"
        case .wrongTarget: return "Wrong Target"
        case .timeout: return "Timeout"
        case .invalidated: return "Invalidated (Head Motion)"
        case .anticipation: return "Anticipation"
        }
    }
    
    var isError: Bool {
        switch self {
        case .correct: return false
        default: return true
        }
    }
}

// MARK: - Trial Data Structure

struct SaccadeTrial: Codable, Identifiable, Equatable {
    let id = UUID()
    let index: Int
    let direction: SaccadeDirection
    let testDirection: SaccadeTestDirection
    let cueTime: TimeInterval
    var focusTime: TimeInterval?
    var latencyMs: Double?
    var outcome: TrialOutcome
    var headYawDeg: Double
    var headPitchDeg: Double
    var overshoots: Int = 0
    
    var isValid: Bool {
        outcome == .correct
    }
    
    var isError: Bool {
        outcome.isError
    }
    
    var maxHeadMotion: Double {
        max(headYawDeg, headPitchDeg)
    }
}

// MARK: - Test Results Structure

struct SaccadesTestResults: Codable, Equatable {
    let testId = UUID()
    let startedAt: Date
    let completedAt: Date
    let horizontalTrials: [SaccadeTrial]
    let verticalTrials: [SaccadeTrial]
    
    // Aggregate metrics
    let meanLatencyMs: Double?
    let medianLatencyMs: Double?
    let standardDeviationMs: Double?
    let bestLatencyMs: Double?
    let worstLatencyMs: Double?
    
    // Error rates
    let errorRate: Double
    let timeoutRate: Double
    let anticipationRate: Double
    let invalidatedCount: Int
    
    // Head motion metrics
    let maxHeadMotionDeg: Double
    let averageHeadMotionDeg: Double
    let headMotionViolations: Int
    
    // Clinical assessment
    var hasConcussionIndicators: Bool {
        // Clinical thresholds based on research
        let latencyFlag = (meanLatencyMs ?? 0) > 300  // > 300ms is concerning
        let errorFlag = errorRate > 0.15              // > 15% error rate
        let headMotionFlag = maxHeadMotionDeg > 10    // > 10° head motion
        
        return latencyFlag || errorFlag || headMotionFlag
    }
    
    var overallScore: Int {
        let allTrials = horizontalTrials + verticalTrials
        let validTrials = allTrials.filter { $0.isValid }
        
        guard !validTrials.isEmpty else { return 0 }
        
        // Base score from latency (200ms = 100 points, degrades from there)
        let avgLatency = validTrials.compactMap { $0.latencyMs }.reduce(0, +) / Double(validTrials.count)
        let latencyScore = max(0, min(100, Int(200 - (avgLatency - 200) * 0.3)))
        
        // Penalties
        let errorPenalty = Int(errorRate * 100)
        let headMotionPenalty = min(30, Int(maxHeadMotionDeg * 2))
        let invalidatedPenalty = invalidatedCount * 5
        
        return max(0, latencyScore - errorPenalty - headMotionPenalty - invalidatedPenalty)
    }
    
    var performanceCategory: String {
        switch overallScore {
        case 90...100: return "Excellent"
        case 80...89: return "Good"
        case 70...79: return "Fair"
        case 60...69: return "Poor"
        default: return "Concerning"
        }
    }
    
    var recommendsEvaluation: Bool {
        overallScore < 70 || hasConcussionIndicators
    }
    
    // Convenience properties
    var totalTrials: Int {
        horizontalTrials.count + verticalTrials.count
    }
    
    var validTrials: Int {
        horizontalTrials.filter { $0.isValid }.count + verticalTrials.filter { $0.isValid }.count
    }
    
    var testDuration: TimeInterval {
        completedAt.timeIntervalSince(startedAt)
    }
    
    // Direction-specific metrics
    var horizontalMeanLatency: Double? {
        let validHorizontal = horizontalTrials.filter { $0.isValid }.compactMap { $0.latencyMs }
        return validHorizontal.isEmpty ? nil : validHorizontal.reduce(0, +) / Double(validHorizontal.count)
    }
    
    var verticalMeanLatency: Double? {
        let validVertical = verticalTrials.filter { $0.isValid }.compactMap { $0.latencyMs }
        return validVertical.isEmpty ? nil : validVertical.reduce(0, +) / Double(validVertical.count)
    }
    
    var horizontalErrorRate: Double {
        let hTotal = horizontalTrials.count
        let hErrors = horizontalTrials.filter { $0.isError }.count
        return hTotal > 0 ? Double(hErrors) / Double(hTotal) : 0
    }
    
    var verticalErrorRate: Double {
        let vTotal = verticalTrials.count
        let vErrors = verticalTrials.filter { $0.isError }.count
        return vTotal > 0 ? Double(vErrors) / Double(vTotal) : 0
    }
}

// MARK: - Configuration

struct SaccadesConfig {
    // Geometry (immersive space coordinates) - eye level positioning
    let targetDepthM: Float = 1.2  // Closer for better gaze detection
    let horizontalOffsetM: Float = 0.32  // ~15° at 1.2m
    let verticalOffsetM: Float = 0.21    // ~10° at 1.2m
    
    // Test parameters - optimized for pure gaze detection
    let trialsPerDirection = 8
    let interCueInterval: TimeInterval = 1.8  // Slightly faster for gaze-only
    let responseTimeout: TimeInterval = 2.5   // Reduced timeout for gaze
    let anticipationThreshold: TimeInterval = 0.100  // Standard clinical threshold
    
    // Head motion thresholds - stricter for medical accuracy
    let maxHeadYawDeg: Double = 5.0
    let maxHeadPitchDeg: Double = 5.0
    let recenterGracePeriod: TimeInterval = 0.3
    
    // Visual parameters - optimized for gaze focus
    let targetDiameterM: Float = 0.08  // Larger for better gaze targeting
    let fixationDiameterM: Float = 0.04
    let pulseScale: Float = 1.5
    let pulseDuration: TimeInterval = 0.5  // Longer pulse for clear cueing
    
    // Colors for different targets
    static let leftTargetColor = Color.green
    static let rightTargetColor = Color.blue
    static let upTargetColor = Color.orange
    static let downTargetColor = Color.purple
    static let fixationColor = Color.white
}