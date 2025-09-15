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
    private var isImmersiveSpaceActive = false
    
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
        // Only dismiss if there's actually an active immersive space
        if isImmersiveSpaceActive, let currentSpace = currentImmersiveSpace {
            print("🔄 Dismissing current immersive space: \(currentSpace)")
            await dismissImmersiveSpace()
            currentImmersiveSpace = nil
            isImmersiveSpaceActive = false
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
            print("⚠️ Attempted to navigate to non-immersive view: \(view)")
            return
        }

        do {
            print("🚀 Opening immersive space: \(spaceId)")
            try await openImmersiveSpace(spaceId)
            currentImmersiveSpace = spaceId
            isImmersiveSpaceActive = true
            dismissMainWindow()
            print("✅ Successfully opened immersive space: \(spaceId)")
        } catch {
            print("❌ Failed to open immersive space \(spaceId): \(error)")
            currentImmersiveSpace = nil
            isImmersiveSpaceActive = false
            openMainWindow()
        }
    }
    
    @MainActor
    func closeImmersiveSpace(
        dismissImmersiveSpace: @escaping () async -> Void,
        openMainWindow: @escaping () -> Void
    ) async {
        if isImmersiveSpaceActive, let currentSpace = currentImmersiveSpace {
            print("🔚 Closing immersive space: \(currentSpace)")
            await dismissImmersiveSpace()
            currentImmersiveSpace = nil
            isImmersiveSpaceActive = false
            // Reopen the window after dismissing immersive space
            openMainWindow()
            print("✅ Successfully closed immersive space and reopened main window")
        } else {
            print("⚠️ Attempted to close immersive space, but none was active")
            // Still ensure main window is open
            openMainWindow()
        }
    }
}