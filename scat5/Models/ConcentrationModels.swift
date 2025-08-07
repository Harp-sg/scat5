import Foundation
import SwiftData

@Model
final class ConcentrationResult {
    var id: UUID
    
    // Properties for Digit Span Backwards test
    var digitSequencesPresented: [[Int]] = []
    var digitResponses: [[Int]] = []
    var digitScore: Int = 0
    
    // Properties for Months in Reverse test
    var monthsCorrect: Bool = false
    var monthsScore: Int {
        monthsCorrect ? 1 : 0
    }
    
    // Total score as per the spec
    var totalScore: Int {
        digitScore + monthsScore
    }
    
    @Relationship(inverse: \CognitiveResult.concentrationResult)
    var cognitiveResult: CognitiveResult?

    init(id: UUID = UUID()) {
        self.id = id
        // You can pre-populate digitSequencesPresented here if they are static
        self.digitSequencesPresented = [
            [7,2,4],
            [3,8,1,6],
            [5,2,9,4,1],
            [2,9,6,8,3,7]
            // Add more lists if needed, as per spec
        ]
        self.digitResponses = Array(repeating: [], count: self.digitSequencesPresented.count)
    }
}