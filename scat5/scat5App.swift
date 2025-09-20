import SwiftUI
import SwiftData

@main
struct scat5App: App {
    @State private var authService = AuthService()
    @State private var appViewModel = AppViewModel()
    @State private var viewRouter = ViewRouter()
    @State private var speechManager = SpeechControlManager()
    @State private var speechCoordinator = SpeechControlCoordinator()

    var body: some Scene {
        WindowGroup(id: "MainWindow") {
            ContentView()
                .environment(authService)
                .environment(appViewModel)
                .environment(viewRouter)
                .environment(speechManager)
                .environment(speechCoordinator)
                .modelContainer(sharedModelContainer)
                .overlay {
                    if !appViewModel.isTextEntryActive {
                        SpeechControlOverlay()
                            .environment(speechManager)
                    }
                }
                .onAppear {
                    speechCoordinator.setDependencies(viewRouter: viewRouter, appViewModel: appViewModel)
                    speechManager.setCommandDelegate(speechCoordinator)
                }
        }

        ImmersiveSpace(id: "TestImmersiveSpace") {
            TestInterfaceView()
                .environment(appViewModel)
                .environment(speechCoordinator)
                .environment(speechManager)
                .environment(authService)
                .environment(viewRouter)
                .modelContainer(sharedModelContainer)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)

        // Immersive Diagnosis Spaces
        ImmersiveSpace(id: "AISymptomAnalyzer") {
            AISymptomAnalyzerView()
                .environment(viewRouter)
                .environment(speechCoordinator)
                .environment(speechManager)
                .modelContainer(sharedModelContainer)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)

        ImmersiveSpace(id: "VoicePatternAssessment") {
            VoicePatternAssessmentView()
                .environment(viewRouter)
                .environment(speechCoordinator)
                .environment(speechManager)
                .modelContainer(sharedModelContainer)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)

        ImmersiveSpace(id: "EyeMovementTracking") {
            EyeMovementTrackingView()
                .environment(viewRouter)
                .environment(speechCoordinator)
                .environment(speechManager)
                .modelContainer(sharedModelContainer)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)

        ImmersiveSpace(id: "BalancePrediction") {
            BalancePredictionView()
                .environment(viewRouter)
                .environment(speechCoordinator)
                .environment(speechManager)
                .modelContainer(sharedModelContainer)
        }
        .immersionStyle(selection: .constant(.full), in: .full)

        // NEW: Stationary Balance Test
        ImmersiveSpace(id: "BalanceStationary") {
            BalanceStationaryView()
                .environment(viewRouter)
                .environment(speechCoordinator)
                .environment(speechManager)
                .modelContainer(sharedModelContainer)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)

        // NEW: Room-Scale Balance Test  
        ImmersiveSpace(id: "BalanceRoomScale") {
            BalanceRoomScaleView()
                .environment(viewRouter)
                .environment(speechCoordinator)
                .environment(speechManager)
                .modelContainer(sharedModelContainer)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)

        ImmersiveSpace(id: "RiskFactorAnalysis") {
            RiskFactorAnalysisView()
                .environment(viewRouter)
                .environment(speechCoordinator)
                .environment(speechManager)
                .modelContainer(sharedModelContainer)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)

        ImmersiveSpace(id: "SmoothPursuitSpace") {
            SmoothPursuitScene()
                .environment(viewRouter)
                .environment(speechCoordinator)
                .environment(speechManager)
                .modelContainer(sharedModelContainer)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)

        ImmersiveSpace(id: "SaccadesSpace") {
            SaccadesTestView()
                .environment(viewRouter)
                .environment(speechCoordinator)
                .environment(speechManager)
                .modelContainer(sharedModelContainer)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)

        ImmersiveSpace(id: "MovingRoomSpace") {
            MovingRoomView()
                .environment(viewRouter)
                .environment(speechCoordinator)
                .environment(speechManager)
                .modelContainer(sharedModelContainer)
        }
        .immersionStyle(selection: .constant(.full), in: .full)

        // NEW: Falling Ball Catch Test
        ImmersiveSpace(id: "FallingBallCatch") {
            FallingBallCatchView()
                .environment(viewRouter)
                .environment(speechCoordinator)
                .environment(speechManager)
                .modelContainer(sharedModelContainer)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            User.self,
            TestSession.self,
            SymptomResult.self,
            CognitiveResult.self,
            OrientationResult.self,
            ConcentrationResult.self,
            MemoryTrial.self,
            NeurologicalResult.self,
            BalanceResult.self,
            SaccadesResult.self,
            // NOTE: No new models required for MVP Smooth Pursuit
            MovingRoomResult.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
}