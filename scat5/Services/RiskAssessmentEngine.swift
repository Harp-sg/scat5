import Foundation

/// A service responsible for calculating risk based on Z-scores.
///
/// Z-score indicates how many standard deviations an element is from the mean.
/// It's a measure of how unusual or extreme a score is.
struct RiskAssessmentEngine {

    /// Calculates the Z-score for a given value.
    ///
    /// Z = (X - μ) / σ
    ///
    /// - Parameters:
    ///   - value: The individual data point (X) to be scored.
    ///   - mean: The average of the population data (μ).
    ///   - standardDeviation: The standard deviation of the population data (σ).
    /// - Returns: The calculated Z-score, or nil if standard deviation is zero to prevent division by zero.
    func calculateZScore(value: Double, mean: Double, standardDeviation: Double) -> Double? {
        // A standard deviation of 0 would mean all data points are the same.
        // In this case, any deviation is technically infinite, but a Z-score is not meaningful.
        guard standardDeviation > 0 else {
            return nil
        }
        return (value - mean) / standardDeviation
    }

    /// Interprets a Z-score to determine a qualitative risk level.
    ///
    /// This is a simplified interpretation. Clinical applications may require
    /// more nuanced thresholds based on established medical guidelines.
    ///
    /// - Parameter zScore: The Z-score to interpret.
    /// - Returns: A qualitative risk level.
    func interpretZScore(_ zScore: Double) -> RiskLevel {
        let absoluteZScore = abs(zScore)
        
        if absoluteZScore > 1.96 {
            // Corresponds to p < 0.05 (statistically significant)
            return .high
        } else if absoluteZScore > 1.0 {
            // Moderate deviation, warrants observation
            return .moderate
        } else {
            // Within one standard deviation, considered normal
            return .low
        }
    }
}

/// Represents the qualitative risk level determined from a Z-score.
enum RiskLevel: String, Codable {
    case low = "Low Risk"
    case moderate = "Moderate Risk"
    case high = "High Risk"
}