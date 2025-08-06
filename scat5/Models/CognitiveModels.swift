import Foundation
import SwiftData

@Model
final class CognitiveResult {
    var id: UUID
    var orientationScore: Int = 0
    var concentrationScore: Int = 0
    @Relationship(deleteRule: .cascade)
    var immediateMemoryTrials: [MemoryTrial] = []
    var delayedRecalledWords: [String] = []
    var testSession: TestSession?

    var immediateMemoryTotalScore: Int {
        immediateMemoryTrials.reduce(0) { $0 + $1.score }
    }
    var delayedRecallScore: Int {
        guard let wordList = immediateMemoryTrials.first?.words else { return 0 }
        return Set(delayedRecalledWords).intersection(Set(wordList)).count
    }

    init(id: UUID = UUID()) {
        self.id = id
        let wordList = Self.getWordList()
        self.immediateMemoryTrials = (1...3).map { MemoryTrial(trialNumber: $0, words: wordList) }
    }
    
    static func getWordList() -> [String] {
        ["Elbow", "Apple", "Carpet", "Saddle", "Bubble"]
    }
}

@Model
class MemoryTrial {
    var id: UUID
    var trialNumber: Int
    var words: [String]
    var recalledWords: [String]
    
    var score: Int {
        Set(recalledWords).intersection(Set(words)).count
    }
    
    init(id: UUID = UUID(), trialNumber: Int, words: [String], recalledWords: [String] = []) {
        self.id = id
        self.trialNumber = trialNumber
        self.words = words
        self.recalledWords = recalledWords
    }
}