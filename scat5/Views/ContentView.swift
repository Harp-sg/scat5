import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(AuthService.self) private var authService
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(ViewRouter.self) private var viewRouter
    @Environment(SpeechControlCoordinator.self) private var speechCoordinator
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        // Main content based on authentication state and routing
        Group {
            if !authService.isAuthenticated {
                switch viewRouter.currentView {
                case .login:
                    LoginView()
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                case .createAccount:
                    CreateAccountView()
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                default:
                    LoginView()
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            } else {
                switch viewRouter.currentView {
                case .dashboard:
                    MainDashboardView()
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                case .testSelection(let sessionType):
                    TestSelectionView(testType: sessionType)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                case .interactiveDiagnosis:
                    InteractiveDiagnosisView()
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                        
                default:
                    MainDashboardView()
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authService.isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: viewRouter.currentView)
        .overlay {
            // Voice Command Help Overlay
            if speechCoordinator.isShowingHelp {
                VoiceHelpOverlay()
                    .environment(speechCoordinator)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: speechCoordinator.isShowingHelp)
            }
        }
        .onAppear {
            // Set the model context for the auth service when the view appears
            authService.setModelContext(modelContext)
        }
        .onChange(of: viewRouter.currentView) { oldValue, newValue in
            // Prevent rapid successive changes that cause performance issues
            guard oldValue != newValue else { return }
            
            // Update speech coordinator context when view changes
            updateSpeechContext(for: newValue)
        }
        .task {
            // Handle any startup errors gracefully
            do {
                try await setupApplicationState()
            } catch {
                print("⚠️ Application setup error: \(error)")
                // Handle setup errors gracefully - don't crash the app
            }
        }
    }
    
    private func setupApplicationState() async throws {
        // Initialize any required services that might fail
        // This prevents crashes during app startup
        
        // Ensure speech coordinator is properly initialized with a valid context
        speechCoordinator.currentViewContext = .dashboard
    }
    
    private func updateSpeechContext(for view: AppView) {
        // Add safety checks to prevent crashes
        guard speechCoordinator.currentViewContext != contextForView(view) else { return }
        
        speechCoordinator.currentViewContext = contextForView(view)
    }
    
    private func contextForView(_ view: AppView) -> ViewContext {
        switch view {
        case .dashboard:
            return .dashboard
        case .testSelection:
            return .testSelection
        case .interactiveDiagnosis:
            return .interactiveDiagnosis
        case .aiSymptomAnalyzer:
            return .aiSymptomAnalyzer
        case .voicePatternAssessment:
            return .voicePatternAssessment
        case .eyeMovementTracking:
            return .eyeMovementTracking
        case .balancePrediction:
            return .balancePrediction
        case .riskFactorAnalysis:
            return .riskFactorAnalysis
        default:
            return .dashboard
        }
    }
}

// Extension to provide glass background effect used throughout the app
extension View {
    func glassBackgroundEffect() -> some View {
        self
            .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    ContentView()
        .environment(AuthService())
        .environment(AppViewModel())
        .environment(ViewRouter())
        .modelContainer(for: [User.self, TestSession.self, SymptomResult.self, CognitiveResult.self, OrientationResult.self, ConcentrationResult.self, MemoryTrial.self, NeurologicalResult.self, BalanceResult.self])
}