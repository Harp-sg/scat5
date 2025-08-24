import SwiftUI

// MARK: - View Context
enum ViewContext {
    case dashboard
    case testSelection
    case interactiveDiagnosis
    case testInterface
    
    // Immersive Diagnosis Views
    case aiSymptomAnalyzer
    case voicePatternAssessment
    case eyeMovementTracking
    case balancePrediction
    case riskFactorAnalysis
}

// MARK: - Enhanced Controller Protocols
protocol CarouselController {
    func executeCommand(_ command: VoiceCommand)
}

protocol TestController {
    func executeCommand(_ command: VoiceCommand)
}

// NEW SEXY PROTOCOLS for detailed control
protocol QuestionController {
    func executeCommand(_ command: VoiceCommand)
}

protocol FormController {
    func executeCommand(_ command: VoiceCommand)
}

@Observable
class SpeechControlCoordinator: CommandExecutionDelegate {
    private var viewRouter: ViewRouter?
    private var appViewModel: AppViewModel?
    
    // State to track manual user interaction
    var isUserInteracting: Bool = false
    
    // Current view context for command execution
    var currentViewContext: ViewContext = .dashboard
    
    // Help overlay state
    var isShowingHelp: Bool = false
    
    // Carousel controls - these will be set by individual views
    var carouselController: CarouselController?
    var testController: TestController?
    
    // NEW: Question/Form controllers for detailed navigation
    var questionController: QuestionController?
    var formController: FormController?
    
    func setDependencies(viewRouter: ViewRouter, appViewModel: AppViewModel) {
        self.viewRouter = viewRouter
        self.appViewModel = appViewModel
    }
    
    // MARK: - Command Execution
    func executeNavigationCommand(_ command: VoiceCommand) {
        guard !isUserInteracting else { return }
        guard let viewRouter = viewRouter else { return }
        
        switch command {
        case .goToDashboard:
            viewRouter.navigate(to: .dashboard)
        case .goToConcussion:
            viewRouter.navigate(to: .testSelection(.concussion))
        case .goToPostExercise:
            viewRouter.navigate(to: .testSelection(.postExercise))
        case .goToInteractiveDiagnosis:
            viewRouter.navigate(to: .interactiveDiagnosis)
        case .goBack:
            // Simple back navigation - go to dashboard from any sub-page
            if viewRouter.currentView != .dashboard {
                viewRouter.navigate(to: .dashboard)
            }
        case .exitTest, .closeTest:
            // NEW SEXY FEATURE: Exit current test and return to carousel
            handleTestExit()
        default:
            break
        }
    }
    
    func executeCarouselCommand(_ command: VoiceCommand) {
        guard !isUserInteracting else { return }
        carouselController?.executeCommand(command)
    }
    
    func executeTestCommand(_ command: VoiceCommand) {
        guard !isUserInteracting else { return }
        
        // First try to handle it with the test controller
        testController?.executeCommand(command)
        
        // Then try question/form controllers for detailed navigation
        switch command {
        case .nextQuestion, .previousQuestion:
            questionController?.executeCommand(command)
        case .selectAnswer(_), .selectMonth(_), .selectDay(_), .selectDate(_), .selectYear(_):
            formController?.executeCommand(command)
        case .goToOrientation, .goToImmediateMemory, .goToConcentration, .goToDelayedRecall:
            // Handle cognitive test section navigation
            testController?.executeCommand(command)
        default:
            break
        }
    }
    
    func executeGeneralCommand(_ command: VoiceCommand) {
        guard !isUserInteracting else { return }
        
        switch command {
        case .help:
            // Show help overlay with context-specific commands
            isShowingHelp = true
            // Auto-hide after 8 seconds (longer to read more commands)
            DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) {
                self.isShowingHelp = false
            }
        case .enableSpeechControl, .disableSpeechControl:
            // These are handled by the SpeechControlManager directly
            break
        default:
            break
        }
    }
    
    // NEW SEXY FEATURE: Handle test exit with style
    private func handleTestExit() {
        guard let appViewModel = appViewModel else { return }
        
        // Close immersive space if open
        if appViewModel.isImmersiveSpaceShown {
            appViewModel.isImmersiveSpaceShown = false
            appViewModel.currentModule = nil
        }
        
        // Navigate back to appropriate test selection
        guard let viewRouter = viewRouter else { return }
        
        // Determine which test selection to return to based on current session
        if let session = appViewModel.currentSession {
            switch session.sessionType {
            case .concussion:
                viewRouter.navigate(to: .testSelection(.concussion))
            case .postExercise:
                viewRouter.navigate(to: .testSelection(.postExercise))
            case .baseline:
                viewRouter.navigate(to: .testSelection(.baseline))
            }
        } else {
            // Default to dashboard if no session
            viewRouter.navigate(to: .dashboard)
        }
    }
    
    // Enhanced context-aware help commands
    func getAvailableCommands() -> [String] {
        switch currentViewContext {
        case .dashboard:
            return [
                "\"Start concussion test\"",
                "\"Post exercise test\"", 
                "\"Interactive diagnosis\"",
                "\"Help\""
            ]
        case .testSelection:
            return [
                "\"Next\", \"Previous\"",
                "\"Select this\"",
                "\"Start symptoms\"",
                "\"Start cognitive\"",
                "\"Start balance\"",
                "\"Go back\"",
                "\"Help\""
            ]
        case .testInterface:
            return getTestSpecificCommands()
        default:
            return [
                "\"Go back\"",
                "\"Exit test\"",
                "\"Help\""
            ]
        }
    }
    
    // NEW: Get test-specific commands based on current module
    private func getTestSpecificCommands() -> [String] {
        guard let appViewModel = appViewModel,
              let currentModule = appViewModel.currentModule else {
            return defaultTestCommands()
        }
        
        switch currentModule {
        case .symptoms:
            return [
                "\"Rate 0\" through \"Rate 6\"",
                "\"Next question\"",
                "\"Previous question\"",
                "\"Complete test\"",
                "\"Exit test\"",
                "\"Help\""
            ]
        case .cognitive:
            return [
                "\"Next question\"",
                "\"Previous question\"",
                "\"Go to orientation\"",
                "\"Go to memory\"",
                "\"Go to concentration\"",
                "\"Select January\" (months)",
                "\"Select Monday\" (days)",
                "\"Select 15\" (dates)",
                "\"Complete test\"",
                "\"Exit test\""
            ]
        case .balance:
            return [
                "\"Start timer\"",
                "\"Stop timer\"",
                "\"Add error\"",
                "\"Next stance\"",
                "\"Previous stance\"",
                "\"Complete test\"",
                "\"Exit test\""
            ]
        case .coordination:
            return [
                "\"Start test\"",
                "\"Add error\"",
                "\"Next trial\"",
                "\"Complete test\"",
                "\"Exit test\""
            ]
        case .immediateMemory, .delayedRecall:
            return [
                "\"Start recording\"",
                "\"Stop recording\"",
                "\"Next trial\"",
                "\"Complete test\"",
                "\"Exit test\""
            ]
        }
    }
    
    private func defaultTestCommands() -> [String] {
        return [
            "\"Start test\"",
            "\"Next\", \"Previous\"", 
            "\"Rate 0-6\"",
            "\"Complete test\"",
            "\"Exit test\"",
            "\"Help\""
        ]
    }
}