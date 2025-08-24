import SwiftUI

enum AppView: Equatable {
    case login
    case createAccount
    case dashboard
    case testSelection(SessionType)
    case interactiveDiagnosis
    
    // Immersive Diagnosis Views
    case aiSymptomAnalyzer
    case fallingBallCatch     // Added new falling ball test
    case voicePatternAssessment
    case eyeMovementTracking
    case saccadesTest
    case balancePrediction
    case balanceStationary
    case balanceRoomScale
    case riskFactorAnalysis
    case smoothPursuit
    case movingRoomTest
}

@Observable
class ViewRouter {
    var currentView: AppView = .dashboard
    
    private var currentImmersiveSpace: String?
    
    func navigate(to view: AppView) {
        currentView = view
    }
    
    @MainActor
    func navigateToImmersive(
        _ view: AppView, 
        openImmersiveSpace: @escaping (String) async throws -> Void, 
        dismissImmersiveSpace: @escaping () async -> Void,
        dismissMainWindow: @escaping () -> Void,
        openMainWindow: @escaping () -> Void
    ) async {
        if currentImmersiveSpace != nil {
            await dismissImmersiveSpace()
            currentImmersiveSpace = nil
        }

        let spaceId: String
        switch view {
        case .aiSymptomAnalyzer:
            spaceId = "AISymptomAnalyzer"
        case .fallingBallCatch:
            spaceId = "FallingBallCatch"
        case .voicePatternAssessment:
            spaceId = "VoicePatternAssessment"
        case .eyeMovementTracking:
            spaceId = "EyeMovementTracking"
        case .saccadesTest:
            spaceId = "SaccadesSpace"
        case .balancePrediction:
            spaceId = "BalancePrediction"
        case .balanceStationary:
            spaceId = "BalanceStationary"
        case .balanceRoomScale:
            spaceId = "BalanceRoomScale"
        case .riskFactorAnalysis:
            spaceId = "RiskFactorAnalysis"
        case .smoothPursuit:
            spaceId = "SmoothPursuitSpace"
        case .movingRoomTest:
            spaceId = "MovingRoomSpace"
        default:
            return
        }

        do {
            try await openImmersiveSpace(spaceId)
            currentImmersiveSpace = spaceId
            dismissMainWindow()
        } catch {
            print("Failed to open immersive space \(spaceId): \(error)")
            openMainWindow()
        }
    }
    
    @MainActor
    func closeImmersiveSpace(
        dismissImmersiveSpace: @escaping () async -> Void,
        openMainWindow: @escaping () -> Void
    ) async {
        if currentImmersiveSpace != nil {
            await dismissImmersiveSpace()
            currentImmersiveSpace = nil
            // Reopen the window after dismissing immersive space
            openMainWindow()
        }
    }
}