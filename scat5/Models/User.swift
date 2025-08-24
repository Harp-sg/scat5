import Foundation
import SwiftData

@Model
final class User {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var username: String
    var password: String // In production, this should be hashed
    var firstName: String
    var lastName: String
    var dateOfBirth: Date
    var sport: String
    var position: String
    var yearsExperience: Int
    var height: Double // in cm
    var weight: Double // in kg
    var dominantHand: DominantHand
    var hasBaseline: Bool = false
    
    @Relationship(deleteRule: .cascade, inverse: \TestSession.user)
    var testSessions: [TestSession]
    
    var fullName: String {
        "\(firstName) \(lastName)"
    }
    
    init(id: UUID = UUID(), username: String, password: String, firstName: String, lastName: String, dateOfBirth: Date, sport: String, position: String = "", yearsExperience: Int = 0, height: Double = 0, weight: Double = 0, dominantHand: DominantHand = .right) {
        self.id = id
        self.username = username
        self.password = password
        self.firstName = firstName
        self.lastName = lastName
        self.dateOfBirth = dateOfBirth
        self.sport = sport
        self.position = position
        self.yearsExperience = yearsExperience
        self.height = height
        self.weight = weight
        self.dominantHand = dominantHand
        self.testSessions = []
    }
}

enum DominantHand: String, Codable, CaseIterable {
    case left = "Left"
    case right = "Right"
    case ambidextrous = "Ambidextrous"
}