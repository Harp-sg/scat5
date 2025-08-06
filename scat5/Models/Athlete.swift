import Foundation
import SwiftData

@Model
final class Athlete {
    @Attribute(.unique) var id: UUID
    var name: String
    var dateOfBirth: Date
    var sport: String
    
    @Relationship(inverse: \TestSession.athlete)
    var testSessions: [TestSession]
    
    init(id: UUID = UUID(), name: String, dateOfBirth: Date, sport: String, testSessions: [TestSession] = []) {
        self.id = id
        self.name = name
        self.dateOfBirth = dateOfBirth
        self.sport = sport
        self.testSessions = testSessions
    }
}