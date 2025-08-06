import Foundation
import SwiftData

@Model
final class CoordinationResult {
    var id: UUID
    var fingerToNoseNormal: Bool = true
    var tandemGaitNormal: Bool = true
    var testSession: TestSession?
    
    init(id: UUID = UUID()) {
        self.id = id
    }
}