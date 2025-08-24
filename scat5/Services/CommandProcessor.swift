import Foundation
import SwiftUI

// MARK: - Voice Commands
enum VoiceCommand: CustomStringConvertible {
    // Navigation
    case goToDashboard
    case goToConcussion
    case goToPostExercise
    case goToInteractiveDiagnosis
    case goBack
    case exitTest  // NEW: Exit current test back to carousel
    case closeTest // NEW: Close button equivalent
    
    // Carousel Control
    case nextItem
    case previousItem
    case selectItem
    case selectItemByName(String)
    
    // Test Control
    case startTest
    case completeTest
    case nextTrial
    case nextQuestion  // NEW: Navigate to next question
    case previousQuestion  // NEW: Navigate to previous question
    case startRecording
    case stopRecording
    case addError
    case rate(Int)
    case markCorrect
    case markIncorrect
    case submitAnswer
    case pauseTest  // NEW: Pause timer/test
    case resumeTest // NEW: Resume timer/test
    case resetTest  // NEW: Reset current test
    
    // General
    case help
    case enableSpeechControl
    case disableSpeechControl
    
    // Symptom Evaluation Specific
    case setSymptomRating(symptom: String, rating: Int)
    case setToggle(question: String, value: Bool)
    case setPercentNormal(Int)
    
    // Cognitive Test Specific
    case goToOrientation       // NEW: Jump to orientation section
    case goToImmediateMemory   // NEW: Jump to immediate memory section
    case goToConcentration     // NEW: Jump to concentration section
    case goToDelayedRecall     // NEW: Jump to delayed recall section
    
    // Balance Test Specific
    case nextStance      // NEW: Move to next balance stance
    case previousStance  // NEW: Move to previous balance stance
    case startTimer      // NEW: Start 20s timer
    case stopTimer       // NEW: Stop timer
    
    // Answer Selection (for multiple choice, dates, etc.)
    case selectAnswer(String)  // NEW: Select specific answer
    case selectMonth(String)   // NEW: Select specific month
    case selectDay(String)     // NEW: Select specific day
    case selectDate(Int)       // NEW: Select specific date number
    case selectYear(String)    // NEW: Select specific year
    
    var description: String {
        switch self {
        case .goToDashboard: return "Go to Dashboard"
        case .goToConcussion: return "Start Concussion Assessment"
        case .goToPostExercise: return "Start Post-Exercise Assessment"
        case .goToInteractiveDiagnosis: return "Open Interactive Diagnosis"
        case .goBack: return "Go Back"
        case .exitTest: return "Exit Test"
        case .closeTest: return "Close Test"
        case .nextItem: return "Next Item"
        case .previousItem: return "Previous Item"
        case .selectItem: return "Select Item"
        case .selectItemByName(let name): return "Select \(name)"
        case .startTest: return "Start Test"
        case .completeTest: return "Complete Test"
        case .nextTrial: return "Next Trial"
        case .nextQuestion: return "Next Question"
        case .previousQuestion: return "Previous Question"
        case .startRecording: return "Start Recording"
        case .stopRecording: return "Stop Recording"
        case .addError: return "Add Error"
        case .rate(let value): return "Rate \(value)"
        case .markCorrect: return "Mark Correct"
        case .markIncorrect: return "Mark Incorrect"
        case .submitAnswer: return "Submit Answer"
        case .pauseTest: return "Pause Test"
        case .resumeTest: return "Resume Test"
        case .resetTest: return "Reset Test"
        case .help: return "Show Help"
        case .enableSpeechControl: return "Enable Speech Control"
        case .disableSpeechControl: return "Disable Speech Control"
        
        // Symptom Evaluation
        case .setSymptomRating(let symptom, let rating): return "Set \(symptom) to \(rating)"
        case .setToggle(let question, let value): return "Set \(question) to \(value ? "Yes" : "No")"
        case .setPercentNormal(let value): return "Set Percent Normal to \(value)%"
        
        // Cognitive Test Navigation
        case .goToOrientation: return "Go to Orientation"
        case .goToImmediateMemory: return "Go to Immediate Memory"
        case .goToConcentration: return "Go to Concentration"
        case .goToDelayedRecall: return "Go to Delayed Recall"
        
        // Balance Test
        case .nextStance: return "Next Stance"
        case .previousStance: return "Previous Stance"
        case .startTimer: return "Start Timer"
        case .stopTimer: return "Stop Timer"
        
        // Answer Selection
        case .selectAnswer(let answer): return "Select \(answer)"
        case .selectMonth(let month): return "Select \(month)"
        case .selectDay(let day): return "Select \(day)"
        case .selectDate(let date): return "Select \(date)"
        case .selectYear(let year): return "Select \(year)"
        }
    }
}

// MARK: - Command Execution Delegate
protocol CommandExecutionDelegate: AnyObject {
    func executeNavigationCommand(_ command: VoiceCommand)
    func executeCarouselCommand(_ command: VoiceCommand)
    func executeTestCommand(_ command: VoiceCommand)
    func executeGeneralCommand(_ command: VoiceCommand)
}

// MARK: - Command Processor
class CommandProcessor {
    weak var delegate: CommandExecutionDelegate?
    
    // Exact command patterns - must match exactly
    private let exactCommandPatterns: [String: VoiceCommand] = [
        // Navigation commands - exact matches
        "go to dashboard": .goToDashboard,
        "home": .goToDashboard,
        "dashboard": .goToDashboard,
        "main menu": .goToDashboard,
        
        "start concussion": .goToConcussion,
        "concussion assessment": .goToConcussion,
        "concussion test": .goToConcussion,
        "urgent assessment": .goToConcussion,
        "concussion": .goToConcussion,
        "start concussion test": .goToConcussion,
        "begin concussion": .goToConcussion,
        "begin concussion test": .goToConcussion,
        "concussion assessment test": .goToConcussion,
        
        "post exercise": .goToPostExercise,
        "stability test": .goToPostExercise,
        "exercise assessment": .goToPostExercise,
        "post exercise test": .goToPostExercise,
        
        "interactive diagnosis": .goToInteractiveDiagnosis,
        "diagnosis": .goToInteractiveDiagnosis,
        "ai tools": .goToInteractiveDiagnosis,
        
        "go back": .goBack,
        "back": .goBack,
        "exit": .exitTest,           // NEW: Exit test
        "exit test": .exitTest,      // NEW: Exit test
        "close": .closeTest,         // NEW: Close test
        "close test": .closeTest,    // NEW: Close test
        
        // General commands
        "help": .help,
        "show commands": .help,
        "what can i say": .help,
        "show help": .help,
        
        "enable speech": .enableSpeechControl,
        "speech on": .enableSpeechControl,
        
        "disable speech": .disableSpeechControl,
        "speech off": .disableSpeechControl,
    ]
    
    // Partial command patterns - can match if text contains these
    private let partialCommandPatterns: [String: VoiceCommand] = [
        // Carousel commands
        "next": .nextItem,
        "next item": .nextItem,
        "move right": .nextItem,
        "right": .nextItem,
        
        "previous": .previousItem,
        "previous item": .previousItem,
        "move left": .previousItem,
        "left": .previousItem,
        
        "select": .selectItem,
        "choose": .selectItem,
        "pick": .selectItem,
        "select this": .selectItem,
        
        // Test commands - ENHANCED WITH MORE VARIANTS
        "start test": .startTest,
        "begin test": .startTest,
        "start": .startTest,
        "begin": .startTest,
        "start timer": .startTimer,
        "begin timer": .startTimer,
        
        "complete": .completeTest,
        "finish": .completeTest,
        "complete test": .completeTest,
        "finish test": .completeTest,
        "done": .completeTest,
        
        "next trial": .nextTrial,
        "continue": .nextTrial,
        "next question": .nextQuestion,
        "next q": .nextQuestion,
        
        "previous question": .previousQuestion,
        "previous q": .previousQuestion,
        "back question": .previousQuestion,
        
        "start recording": .startRecording,
        "record": .startRecording,
        "speak": .startRecording,
        
        "stop recording": .stopRecording,
        "stop": .stopRecording,
        "pause": .pauseTest,
        "pause test": .pauseTest,
        "pause timer": .stopTimer,
        
        "resume": .resumeTest,
        "resume test": .resumeTest,
        "resume timer": .startTimer,
        
        "submit": .submitAnswer,
        "enter": .submitAnswer,
        "confirm": .submitAnswer,
        
        "add error": .addError,
        "error": .addError,
        "plus one": .addError,
        "increase error": .addError,
        "mistake": .addError,
        
        "correct": .markCorrect,
        "yes": .markCorrect,
//        "right": .markCorrect,
        "true": .markCorrect,
        
        "incorrect": .markIncorrect,
        "no": .markIncorrect,
        "wrong": .markIncorrect,
        "false": .markIncorrect,
        
        // Cognitive test navigation - NEW SEXY COMMANDS
        "orientation": .goToOrientation,
        "go to orientation": .goToOrientation,
        "immediate memory": .goToImmediateMemory,
        "go to memory": .goToImmediateMemory,
        "memory": .goToImmediateMemory,
        "concentration": .goToConcentration,
        "go to concentration": .goToConcentration,
        "delayed recall": .goToDelayedRecall,
        "go to recall": .goToDelayedRecall,
        "recall": .goToDelayedRecall,
        
        // Balance test commands - NEW SEXY COMMANDS
        "next stance": .nextStance,
        "next position": .nextStance,
        "previous stance": .previousStance,
        "previous position": .previousStance,
        
        // Reset commands
        "reset": .resetTest,
        "reset test": .resetTest,
        "start over": .resetTest,
    ]
    
    // Keywords for symptom evaluation
    private let symptomKeywords: [String: String] = [
        "headache": "Headache",
        "pressure in head": "Pressure in head",
        "neck pain": "Neck pain",
        "nausea": "Nausea or vomiting",
        "dizziness": "Dizziness",
        "blurred vision": "Blurred vision",
        "balance problem": "Balance problems",
        "sensitivity to light": "Sensitivity to light",
        "sensitivity to noise": "Sensitivity to noise",
        "feeling slowed down": "Feeling slowed down",
        "feeling like in a fog": "Feeling like in a fog",
        "don't feel right": "Don't feel right",
        "difficulty concentrating": "Difficulty concentrating",
        "difficulty remembering": "Difficulty remembering",
        "fatigue": "Fatigue or low energy",
        "confusion": "Confusion",
        "drowsiness": "Drowsiness",
        "more emotional": "More emotional",
        "irritability": "Irritability",
        "sadness": "Sadness",
        "nervous or anxious": "Nervous or anxious",
        "trouble sleeping": "Trouble falling asleep"
    ]
    
    private let toggleKeywords: [String: String] = [
        "physical": "physical",
        "mental": "mental"
    ]
    
    // Test module names for dynamic selection - ENHANCED WITH MORE VARIANTS
    private let moduleNames: [String: String] = [
        "symptoms": "Symptom Evaluation",
        "symptom evaluation": "Symptom Evaluation",
        "symptom": "Symptom Evaluation",
        "rating": "Symptom Evaluation",
        "rate symptoms": "Symptom Evaluation",
        
        "cognitive": "Cognitive Screening", 
        "cognitive screening": "Cognitive Screening",
        "cognition": "Cognitive Screening",
        "brain test": "Cognitive Screening",
        "thinking": "Cognitive Screening",
        
        "memory": "Immediate Memory",
        "immediate memory": "Immediate Memory",
        "immediate": "Immediate Memory",
        "word recall": "Immediate Memory",
        "remember words": "Immediate Memory",
        
        "balance": "Balance Examination",
        "balance test": "Balance Examination",
        "balance examination": "Balance Examination",
        "stability": "Balance Examination",
        "standing": "Balance Examination",
        
        "coordination": "Coordination Examination",
        "coordination test": "Coordination Examination",
        "coordination examination": "Coordination Examination",
        "finger to nose": "Coordination Examination",
        "movement": "Coordination Examination",
        
        "recall": "Delayed Recall", 
        "delayed recall": "Delayed Recall",
        "delayed": "Delayed Recall",
        "remember": "Delayed Recall",
    ]
    
    // Diagnosis items for InteractiveDiagnosisView
    private let diagnosisNames: [String: String] = [
        "ai symptom": "Catch Diagnosis",
        "symptom analyzer": "Catch Diagnosis",
        "ai": "Catch Diagnosis",
        
        "voice pattern": "Balance Assessment",
        "voice": "Balance Assessment",
        "pattern": "Balance Assessment",
        
        "eye movement": "Eye Movement Tracking",
        "eye": "Eye Movement Tracking",
        "tracking": "Eye Movement Tracking",
        
        "balance prediction": "Walk the Plank",
        "prediction": "Walk the Plank",
        
        "risk factor": "Risk Factor Analysis",
        "risk": "Risk Factor Analysis",
        "analysis": "Risk Factor Analysis"
    ]

    private let numberWords: [String: Int] = [
        "zero": 0, "one": 1, "two": 2, "three": 3,
        "four": 4, "five": 5, "six": 6
    ]
    
    // NEW: Month names for date selection - SEXY MONTH COMMANDS
    private let monthNames: [String] = [
        "january", "february", "march", "april", "may", "june",
        "july", "august", "september", "october", "november", "december"
    ]
    
    // NEW: Day names for day selection - SEXY DAY COMMANDS
    private let dayNames: [String] = [
        "sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"
    ]
    
    func parseCommand(from text: String) -> VoiceCommand? {
        // Clean the text by removing punctuation and normalizing
        let cleanedText = text.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[.?!,;:]", with: "", options: .regularExpression) // Remove punctuation
            .replacingOccurrences(of: "-", with: " ") // Replace hyphens with spaces
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression) // Normalize multiple spaces
            .trimmingCharacters(in: .whitespaces)
        
        print("🎤 Parsing command from text: '\(cleanedText)'")
        
        // 1. First try exact pattern matching (highest priority)
        if let command = exactCommandPatterns[cleanedText] {
            print("✅ Found exact match: \(command)")
            return command
        }
        
        // 2. Check for month selection - NEW SEXY FEATURE
        for month in monthNames {
            if cleanedText == month || cleanedText == "select \(month)" {
                print("✅ Found month selection: \(month)")
                return .selectMonth(month.capitalized)
            }
        }
        
        // 3. Check for day selection - NEW SEXY FEATURE
        for day in dayNames {
            if cleanedText == day || cleanedText == "select \(day)" {
                print("✅ Found day selection: \(day)")
                return .selectDay(day.capitalized)
            }
        }
        
        // 4. Check for date number selection - NEW SEXY FEATURE
        if let dateNumber = extractDateNumber(from: cleanedText) {
            print("✅ Found date selection: \(dateNumber)")
            return .selectDate(dateNumber)
        }
        
        // 5. Check for year selection - NEW SEXY FEATURE
        if cleanedText.contains("year") {
            let yearComponents = cleanedText.components(separatedBy: " ")
            for component in yearComponents {
                if let year = Int(component), year >= 2020 && year <= 2030 {
                    print("✅ Found year selection: \(year)")
                    return .selectYear(String(year))
                }
            }
        }
        
        // 6. Check for Symptom Evaluation commands
        if let command = parseSymptomCommand(from: cleanedText) {
            return command
        }
        
        // 7. Check for number commands (ratings)
        if let n = extractStandaloneRating(from: cleanedText) {
            print("✅ Found rating: \(n)")
            return .rate(n)
        }
        
        if cleanedText.contains("rate ") || cleanedText.contains("set ") {
            if let n = extractRating(from: cleanedText) {
                print("✅ Found rating command: \(n)")
                return .rate(n)
            }
        }
        
        // 8. Check for module selection commands (for TestSelectionView)
        for (moduleName, displayName) in moduleNames {
            if cleanedText == moduleName || 
               cleanedText == "select \(moduleName)" || 
               cleanedText == "choose \(moduleName)" ||
               cleanedText == "open \(moduleName)" ||
               cleanedText == "start \(moduleName)" ||
               cleanedText == "begin \(moduleName)" {
                print("✅ Found module selection: \(displayName)")
                return .selectItemByName(displayName)
            }
        }
        
        // 9. Check for diagnosis selection commands (for InteractiveDiagnosisView)
        for (diagnosisName, displayName) in diagnosisNames {
            if cleanedText == diagnosisName ||
               cleanedText == "select \(diagnosisName)" || 
               cleanedText == "choose \(diagnosisName)" ||
               cleanedText == "open \(diagnosisName)" {
                print("✅ Found diagnosis selection: \(displayName)")
                return .selectItemByName(displayName)
            }
        }
        
        // 10. Finally try partial matching for other commands (lowest priority)
        for (pattern, command) in partialCommandPatterns {
            if cleanedText.contains(pattern) {
                print("✅ Found partial match for pattern '\(pattern)': \(command)")
                return command
            }
        }
        
        print("❌ No command match found for: '\(cleanedText)'")
        return nil
    }
    
    // NEW: Extract date numbers (1-31) - SEXY DATE PARSING
    private func extractDateNumber(from text: String) -> Int? {
        let components = text.components(separatedBy: " ")
        for component in components {
            if let number = Int(component), number >= 1 && number <= 31 {
                return number
            }
        }
        
        // Check for written numbers
        let writtenNumbers = [
            "first": 1, "second": 2, "third": 3, "fourth": 4, "fifth": 5,
            "sixth": 6, "seventh": 7, "eighth": 8, "ninth": 9, "tenth": 10,
            "eleventh": 11, "twelfth": 12, "thirteenth": 13, "fourteenth": 14, "fifteenth": 15,
            "sixteenth": 16, "seventeenth": 17, "eighteenth": 18, "nineteenth": 19, "twentieth": 20,
            "twenty first": 21, "twenty second": 22, "twenty third": 23, "twenty fourth": 24,
            "twenty fifth": 25, "twenty sixth": 26, "twenty seventh": 27, "twenty eighth": 28,
            "twenty ninth": 29, "thirtieth": 30, "thirty first": 31
        ]
        
        for (written, number) in writtenNumbers {
            if text.contains(written) {
                return number
            }
        }
        
        return nil
    }

    private func parseSymptomCommand(from text: String) -> VoiceCommand? {
        // "Set percent normal to 80%" or "80 percent"
        if text.contains("percent") || text.contains("normal") {
            let numbers = text.components(separatedBy: .decimalDigits.inverted).compactMap { Int($0) }
            if let number = numbers.first, (0...100).contains(number) {
                return .setPercentNormal(number)
            }
        }

        // "Headache four" or "set Neck Pain to 3"
        for (keyword, symptomName) in symptomKeywords {
            if text.contains(keyword) {
                if let rating = extractRating(from: text) {
                    return .setSymptomRating(symptom: symptomName, rating: rating)
                }
            }
        }
        
        // "Physical yes" or "Mental no"
        for (keyword, questionName) in toggleKeywords {
            if text.contains(keyword) {
                if text.contains("yes") {
                    return .setToggle(question: questionName, value: true)
                } else if text.contains("no") {
                    return .setToggle(question: questionName, value: false)
                }
            }
        }
        
        return nil
    }
    
    private func extractRating(from text: String) -> Int? {
        // look for digit in 0...6
        if let digit = text.split(separator: " ").compactMap({ Int($0) }).first, (0...6).contains(digit) {
            return digit
        }
        // look for number words
        for (word, n) in numberWords where text.contains(word) {
            return n
        }
        return nil
    }

    private func extractStandaloneRating(from text: String) -> Int? {
        // if text is exactly a number or number word
        if let n = Int(text), (0...6).contains(n) { return n }
        if let n = numberWords[text] { return n }
        return nil
    }

    func executeCommand(_ command: VoiceCommand) {
        print("🎤 Executing command: \(command)")
        switch command {
        case .goToDashboard, .goToConcussion, .goToPostExercise, .goToInteractiveDiagnosis, .goBack, .exitTest, .closeTest:
            delegate?.executeNavigationCommand(command)
        case .nextItem, .previousItem, .selectItem, .selectItemByName:
            delegate?.executeCarouselCommand(command)
        case .startTest, .completeTest, .nextTrial, .nextQuestion, .previousQuestion, .startRecording, .stopRecording,
             .addError, .rate, .markCorrect, .markIncorrect, .submitAnswer, .pauseTest, .resumeTest, .resetTest,
             .goToOrientation, .goToImmediateMemory, .goToConcentration, .goToDelayedRecall,
             .nextStance, .previousStance, .startTimer, .stopTimer,
             .selectAnswer, .selectMonth, .selectDay, .selectDate, .selectYear:
            delegate?.executeTestCommand(command)
        case .help, .enableSpeechControl, .disableSpeechControl:
            delegate?.executeGeneralCommand(command)
        case .setSymptomRating, .setToggle, .setPercentNormal:
            delegate?.executeTestCommand(command)
        }
    }
}
