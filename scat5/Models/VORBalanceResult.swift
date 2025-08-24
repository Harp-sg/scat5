import Foundation
import SwiftData

@Model
final class VORBalanceResult {
    @Attribute(.unique) var id = UUID()
    var userId: UUID
    var startedAt: Date
    var durationSec: Double

    // Head motion
    var meanYawRate_dps: Double
    var medianYawRate_dps: Double
    var freq_Hz: Double
    var yawAmplitude_deg: Double   // peak-to-peak/2

    // Fixation
    var gazeOnPct: Double          // 0–100
    var gazeSlipCount: Int
    var meanSlipDuration_ms: Double

    // Sway (vs standing baseline captured same session)
    var apRMS_cm: Double
    var mlRMS_cm: Double
    var pathLen_cm: Double
    var apRMS_deltaPct: Double     // relative to baseline
    var mlRMS_deltaPct: Double

    // Symptoms (delta from pre-test if you capture it)
    var dizzinessDelta: Int   // 0..10
    var headacheDelta: Int
    var nauseaDelta: Int
    var fogginessDelta: Int

    // Compliance & safety
    var completed: Bool
    var abortedReason: String?  // user_stop, auto_pause_threshold, etc.

    init(userId: UUID, 
         startedAt: Date,
         durationSec: Double = 0,
         meanYawRate_dps: Double = 0,
         medianYawRate_dps: Double = 0,
         freq_Hz: Double = 0,
         yawAmplitude_deg: Double = 0,
         gazeOnPct: Double = 0,
         gazeSlipCount: Int = 0,
         meanSlipDuration_ms: Double = 0,
         apRMS_cm: Double = 0,
         mlRMS_cm: Double = 0,
         pathLen_cm: Double = 0,
         apRMS_deltaPct: Double = 0,
         mlRMS_deltaPct: Double = 0,
         dizzinessDelta: Int = 0,
         headacheDelta: Int = 0,
         nauseaDelta: Int = 0,
         fogginessDelta: Int = 0,
         completed: Bool = false,
         abortedReason: String? = nil) {
        self.userId = userId
        self.startedAt = startedAt
        self.durationSec = durationSec
        self.meanYawRate_dps = meanYawRate_dps
        self.medianYawRate_dps = medianYawRate_dps
        self.freq_Hz = freq_Hz
        self.yawAmplitude_deg = yawAmplitude_deg
        self.gazeOnPct = gazeOnPct
        self.gazeSlipCount = gazeSlipCount
        self.meanSlipDuration_ms = meanSlipDuration_ms
        self.apRMS_cm = apRMS_cm
        self.mlRMS_cm = mlRMS_cm
        self.pathLen_cm = pathLen_cm
        self.apRMS_deltaPct = apRMS_deltaPct
        self.mlRMS_deltaPct = mlRMS_deltaPct
        self.dizzinessDelta = dizzinessDelta
        self.headacheDelta = headacheDelta
        self.nauseaDelta = nauseaDelta
        self.fogginessDelta = fogginessDelta
        self.completed = completed
        self.abortedReason = abortedReason
    }
}