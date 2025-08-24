import Foundation
import SwiftData

@Model
final class MovingRoomResult {
    @Attribute(.unique) var id: UUID = UUID()
    var userId: UUID
    var date: Date = Date()

    // Stim params
    var mode: String      // "translate" | "rotate"
    var axis: String      // "AP" | "ML" | "both"
    var amplitudeCm: Double
    var frequencyHz: Double
    var durationSec: Int

    // Metrics
    var apPeakCm: Double
    var mlPeakCm: Double
    var apRmsCm: Double
    var mlRmsCm: Double
    var pathLenCm: Double
    var ellipseAreaCm2: Double?
    var instabilityEvents: Int
    var autoPaused: Bool

    // Symptoms
    var dizziness: Int
    var nausea: Int
    var headache: Int

    // Baseline deltas (optional)
    var apRmsDeltaPct: Double?
    var mlRmsDeltaPct: Double?

    init(
        userId: UUID = UUID(),
        mode: String, axis: String,
        amplitudeCm: Double, frequencyHz: Double, durationSec: Int,
        apPeakCm: Double, mlPeakCm: Double, apRmsCm: Double, mlRmsCm: Double,
        pathLenCm: Double, ellipseAreaCm2: Double?, instabilityEvents: Int,
        autoPaused: Bool, dizziness: Int, nausea: Int, headache: Int,
        apRmsDeltaPct: Double? = nil, mlRmsDeltaPct: Double? = nil
    ) {
        self.userId = userId
        self.mode = mode
        self.axis = axis
        self.amplitudeCm = amplitudeCm
        self.frequencyHz = frequencyHz
        self.durationSec = durationSec
        self.apPeakCm = apPeakCm
        self.mlPeakCm = mlPeakCm
        self.apRmsCm = apRmsCm
        self.mlRmsCm = mlRmsCm
        self.pathLenCm = pathLenCm
        self.ellipseAreaCm2 = ellipseAreaCm2
        self.instabilityEvents = instabilityEvents
        self.autoPaused = autoPaused
        self.dizziness = dizziness
        self.nausea = nausea
        self.headache = headache
        self.apRmsDeltaPct = apRmsDeltaPct
        self.mlRmsDeltaPct = mlRmsDeltaPct
    }
}