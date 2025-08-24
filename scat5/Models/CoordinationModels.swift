import Foundation
import SwiftData

// Renaming to NeurologicalResult to better match the comprehensive spec
@Model
final class NeurologicalResult {
    var id: UUID
    var testSession: TestSession?

    // Properties from the new spec
    var neckPain: Bool = false
    var readingNormal: Bool = true
    var doubleVision: Bool = false
    var fingerNoseNormal: Bool = true
    var tandemGaitNormal: Bool = true
    var tandemGaitTime: TimeInterval? = nil
    
    // Overall assessment based on sub-tests
    var isNormal: Bool {
        return !neckPain && readingNormal && !doubleVision && fingerNoseNormal && tandemGaitNormal
    }
    
    init(id: UUID = UUID()) {
        self.id = id
    }
}