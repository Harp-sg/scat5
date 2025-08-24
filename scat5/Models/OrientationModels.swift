import Foundation
import SwiftData

@Model
final class OrientationResult {
    var id: UUID
    var questionCount: Int = 5 // Default to 5 for the standard questions
    var correctCount: Int = 0
    var answers: [String: String] = [:] // Using String keys for question prompts for simplicity
    
    @Relationship(inverse: \CognitiveResult.orientationResult)
    var cognitiveResult: CognitiveResult?

    init(id: UUID = UUID()) {
        self.id = id
        // Initialize answers dictionary
        for question in OrientationQuestion.standardQuestions {
            answers[question.prompt] = ""
        }
    }
}

// Represents a single orientation question
struct OrientationQuestion: Identifiable {
    var id: String { prompt }
    let prompt: String
    let answerType: AnswerType
    
    enum AnswerType {
        case month, date, day, year, time, text
    }

    // Define the standard set of questions
    static var standardQuestions: [OrientationQuestion] {
        [
            OrientationQuestion(prompt: "What month is it?", answerType: .month),
            OrientationQuestion(prompt: "What is the date today?", answerType: .date),
            OrientationQuestion(prompt: "What is the day of the week?", answerType: .day),
            OrientationQuestion(prompt: "What year is it?", answerType: .year),
            OrientationQuestion(prompt: "What time is it right now? (within ±1 hour)", answerType: .time)
        ]
    }
    
    // Add Maddocks questions later if needed
}