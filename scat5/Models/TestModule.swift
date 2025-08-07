import Foundation

enum TestModule: String, CaseIterable, Identifiable {
    case symptoms = "Symptom Evaluation"
    case cognitive = "Cognitive Screening"
    case balance = "Balance Assessment"
    case coordination = "Coordination Exam"
    case delayedRecall = "Delayed Recall"

    var icon: String {
        switch self {
        case .symptoms: return "list.bullet.clipboard"
        case .cognitive: return "brain"
        case .balance: return "figure.stand"
        case .coordination: return "hand.point.up.braille"
        case .delayedRecall: return "clock.arrow.circlepath"
        }
    }

    var instructions: String {
        switch self {
        case .symptoms:
            return "Rate your current symptoms on a scale of 0-6, where 0 means no symptoms and 6 means severe symptoms."
        case .cognitive:
            return "Complete orientation, memory, and concentration tests. Follow the examiner's instructions carefully."
        case .balance:
            return "Perform balance tests in different stances. Stay as still as possible during each 20-second trial."
        case .coordination:
            return "Complete finger-to-nose and tandem gait tests. Follow the examiner's guidance."
        case .delayedRecall:
            return "Try to recall the words from the earlier memory test. Say all the words you can remember."
        }
    }
    
    var id: String { self.rawValue }
}