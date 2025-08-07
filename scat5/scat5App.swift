import SwiftUI
import SwiftData

@main
struct scat5App: App {
    @State private var authService = AuthService()
    @State private var appViewModel = AppViewModel()
    @State private var viewRouter = ViewRouter()
    
    // Define the shared model container
    private var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            User.self,
            TestSession.self,
            SymptomResult.self,
            CognitiveResult.self,
            OrientationResult.self,
            ConcentrationResult.self,
            MemoryTrial.self,
            NeurologicalResult.self,
            BalanceResult.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environment(authService)
                .environment(appViewModel)
                .environment(viewRouter)
        }
        .modelContainer(sharedModelContainer) // Apply container to the WindowGroup
        .windowStyle(.plain)
        .defaultSize(width: 1200, height: 800)
        
        ImmersiveSpace(id: "TestImmersiveSpace") {
            TestInterfaceView()
                 .environment(authService)
                 .environment(appViewModel)
                 .environment(viewRouter)
        }
        .modelContainer(sharedModelContainer) // Apply the same container to the ImmersiveSpace
    }
}