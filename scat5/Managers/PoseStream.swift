import Foundation
import ARKit
import RealityKit
import Combine
import SwiftUI

@MainActor
class PoseStream: ObservableObject {
    private var arkitSession: ARKitSession?
    private var worldTracking: WorldTrackingProvider?
    
    @Published var isRunning = false
    @Published var currentYawDeg: Float = 0
    @Published var currentYawRate: Float = 0 // degrees/second
    @Published var currentFrequency: Float = 0 // Hz
    @Published var shouldAutoPause = false
    @Published var autoPauseReason = ""
    
    private var lastYawDeg: Float = 0
    private var lastTimestamp: TimeInterval = 0
    private var originPose: simd_float4x4?
    private var yawHistory: [(Float, TimeInterval)] = []
    private let maxHistoryLength = 100
    
    // Filtering
    private var yawRateLP: Float = 0
    private let filterAlpha: Float = 0.1
    
    // Zero-crossing frequency estimation
    private var lastZeroCrossing: TimeInterval = 0
    private var crossingIntervals: [TimeInterval] = []
    
    func startTracking() async {
        guard !isRunning else { return }
        
        arkitSession = ARKitSession()
        worldTracking = WorldTrackingProvider()
        
        guard let session = arkitSession, let provider = worldTracking else { return }
        
        do {
            try await session.run([provider])
            isRunning = true
            startFrameUpdates()
        } catch {
            print("Failed to start ARKit session: \(error)")
        }
    }
    
    func stopTracking() {
        arkitSession?.stop()
        isRunning = false
        originPose = nil
        yawHistory.removeAll()
        crossingIntervals.removeAll()
    }
    
    func captureOrigin() {
        guard let provider = worldTracking else { return }
        originPose = provider.queryDeviceAnchor(atTimestamp: CACurrentMediaTime())?.originFromAnchorTransform
    }
    
    private func startFrameUpdates() {
        Task {
            guard let provider = worldTracking else { return }
            
            for await update in provider.anchorUpdates {
                guard isRunning else { break }
                
                if let deviceAnchor = update.anchor as? DeviceAnchor {
                    await processFrame(deviceAnchor.originFromAnchorTransform, timestamp: CACurrentMediaTime())
                }
            }
        }
    }
    
    private func processFrame(_ transform: simd_float4x4, timestamp: TimeInterval) async {
        // Extract yaw from rotation matrix - fix simd_float4 access
        let col0 = simd_float3(transform.columns.0.x, transform.columns.0.y, transform.columns.0.z)
        let col1 = simd_float3(transform.columns.1.x, transform.columns.1.y, transform.columns.1.z)
        let col2 = simd_float3(transform.columns.2.x, transform.columns.2.y, transform.columns.2.z)
        let rotationMatrix = simd_float3x3(col0, col1, col2)
        
        let yawRad = atan2(rotationMatrix[1,0], rotationMatrix[0,0])
        let yawDeg = yawRad * 180.0 / Float.pi
        
        currentYawDeg = yawDeg
        
        // Calculate yaw rate
        if lastTimestamp > 0 {
            let dt = Float(timestamp - lastTimestamp)
            if dt > 0 {
                var deltaYaw = yawDeg - lastYawDeg
                
                // Unwrap angle to avoid 360° jumps
                if deltaYaw > 180 { deltaYaw -= 360 }
                if deltaYaw < -180 { deltaYaw += 360 }
                
                let instantYawRate = deltaYaw / dt
                
                // Low-pass filter
                yawRateLP = filterAlpha * instantYawRate + (1 - filterAlpha) * yawRateLP
                currentYawRate = yawRateLP
                
                // Update frequency estimation
                updateFrequencyEstimate(yawDeg, timestamp: timestamp)
                
                // Safety checks
                checkSafetyLimits(transform)
            }
        }
        
        lastYawDeg = yawDeg
        lastTimestamp = timestamp
        
        // Keep history for analysis
        yawHistory.append((yawDeg, timestamp))
        if yawHistory.count > maxHistoryLength {
            yawHistory.removeFirst()
        }
    }
    
    private func updateFrequencyEstimate(_ yawDeg: Float, timestamp: TimeInterval) {
        // Simple zero-crossing detection for frequency
        if yawHistory.count >= 2 {
            let prevYaw = yawHistory[yawHistory.count - 2].0
            
            // Check for zero crossing (sign change)
            if (prevYaw < 0 && yawDeg >= 0) || (prevYaw > 0 && yawDeg <= 0) {
                if lastZeroCrossing > 0 {
                    let interval = timestamp - lastZeroCrossing
                    crossingIntervals.append(interval)
                    
                    // Keep only recent intervals
                    if crossingIntervals.count > 10 {
                        crossingIntervals.removeFirst()
                    }
                    
                    // Calculate frequency from average interval (2 crossings per cycle) - fix reduce usage
                    if crossingIntervals.count >= 2 {
                        let sum = crossingIntervals.reduce(0.0, +)
                        let avgInterval = sum / TimeInterval(crossingIntervals.count)
                        currentFrequency = Float(1.0 / (2.0 * avgInterval))
                    }
                }
                lastZeroCrossing = timestamp
            }
        }
    }
    
    private func checkSafetyLimits(_ transform: simd_float4x4) {
        guard let origin = originPose else { return }
        
        // Check displacement from origin
        let currentPos = transform.translation
        let originPos = origin.translation
        let displacement = distance(currentPos, originPos)
        
        if displacement > 0.25 { // 25cm limit
            shouldAutoPause = true
            autoPauseReason = "sway_limit"
            return
        }
        
        // Check excessive yaw rate
        if abs(currentYawRate) > 400 {
            shouldAutoPause = true
            autoPauseReason = "excess_yaw_rate"
            return
        }
    }
    
    // Analysis methods for final results
    func calculateMetrics(duration: TimeInterval) -> (meanYawRate: Float, medianYawRate: Float, frequency: Float, amplitude: Float) {
        guard !yawHistory.isEmpty else { return (0, 0, 0, 0) }
        
        let yawRates = yawHistory.compactMap { (yaw, timestamp) -> Float? in
            // Calculate instantaneous rates from history
            guard let index = yawHistory.firstIndex(where: { $0.1 == timestamp }),
                  index > 0 else { return nil }
            
            let prevYaw = yawHistory[index - 1].0
            let dt = Float(timestamp - yawHistory[index - 1].1)
            
            var deltaYaw = yaw - prevYaw
            if deltaYaw > 180 { deltaYaw -= 360 }
            if deltaYaw < -180 { deltaYaw += 360 }
            
            return abs(deltaYaw / dt)
        }
        
        let meanRate = yawRates.isEmpty ? 0 : yawRates.reduce(0, +) / Float(yawRates.count)
        let medianRate = yawRates.isEmpty ? 0 : yawRates.sorted()[yawRates.count / 2]
        
        let yawValues = yawHistory.map { $0.0 }
        let amplitude = yawValues.isEmpty ? 0 : (yawValues.max()! - yawValues.min()!) / 2.0
        
        return (meanRate, medianRate, currentFrequency, amplitude)
    }
}

extension simd_float4x4 {
    var translation: simd_float3 {
        return simd_float3(columns.3.x, columns.3.y, columns.3.z)
    }
}