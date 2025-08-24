import Foundation
import simd

@MainActor
class SwayMetrics: ObservableObject {
    @Published var apRMS: Float = 0 // Anterior-Posterior RMS (cm)
    @Published var mlRMS: Float = 0 // Medial-Lateral RMS (cm)
    @Published var pathLength: Float = 0 // Total path length (cm)
    @Published var displacement: Float = 0 // Current displacement from origin (cm)
    
    private var positionHistory: [(simd_float3, TimeInterval)] = []
    private var originPosition: simd_float3?
    private var baselineAPRMS: Float = 0
    private var baselineMLRMS: Float = 0
    private var lastPosition: simd_float3?
    
    private let filterAlpha: Float = 0.1
    private let maxHistoryLength = 1000
    
    func setOrigin(_ position: simd_float3) {
        originPosition = position
        positionHistory.removeAll()
        pathLength = 0
        lastPosition = nil
    }
    
    func captureBaseline() {
        // Capture current RMS as baseline for comparison
        baselineAPRMS = apRMS
        baselineMLRMS = mlRMS
    }
    
    func update(position: simd_float3, timestamp: TimeInterval) {
        guard let origin = originPosition else { return }
        
        // Convert to cm and relative to origin
        let relativePos = (position - origin) * 100 // meters to cm
        
        // Apply light filtering
        let filteredPos: simd_float3
        if let lastPos = lastPosition {
            filteredPos = filterAlpha * relativePos + (1 - filterAlpha) * lastPos
        } else {
            filteredPos = relativePos
        }
        
        // Update path length
        if let lastPos = lastPosition {
            pathLength += distance(filteredPos, lastPos)
        }
        
        lastPosition = filteredPos
        positionHistory.append((filteredPos, timestamp))
        
        // Limit history size
        if positionHistory.count > maxHistoryLength {
            positionHistory.removeFirst()
        }
        
        // Calculate current displacement
        displacement = distance(filteredPos, simd_float3(0, 0, 0))
        
        // Calculate RMS sway
        calculateRMS()
    }
    
    private func calculateRMS() {
        guard positionHistory.count > 1 else { return }
        
        let positions = positionHistory.map { $0.0 }
        let count = Float(positions.count)
        
        // Calculate mean position
        let meanX = positions.map { $0.x }.reduce(0, +) / count
        let meanZ = positions.map { $0.z }.reduce(0, +) / count
        
        // Calculate RMS for ML (x-axis) and AP (z-axis)
        let mlSquaredDeviations = positions.map { pow($0.x - meanX, 2) }
        let apSquaredDeviations = positions.map { pow($0.z - meanZ, 2) }
        
        mlRMS = sqrt(mlSquaredDeviations.reduce(0, +) / count)
        apRMS = sqrt(apSquaredDeviations.reduce(0, +) / count)
    }
    
    func getBaselineDeltaPercent() -> (apDelta: Float, mlDelta: Float) {
        guard baselineAPRMS > 0, baselineMLRMS > 0 else { return (0, 0) }
        
        let apDelta = ((apRMS - baselineAPRMS) / baselineAPRMS) * 100
        let mlDelta = ((mlRMS - baselineMLRMS) / baselineMLRMS) * 100
        
        return (apDelta, mlDelta)
    }
    
    func reset() {
        positionHistory.removeAll()
        apRMS = 0
        mlRMS = 0
        pathLength = 0
        displacement = 0
        lastPosition = nil
    }
}