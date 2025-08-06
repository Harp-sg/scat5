import SwiftUI
import SwiftData

@main
struct scat5App: App {
    @State private var authService = AuthService()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authService)
        }
        .modelContainer(for: [
            User.self,
            TestSession.self,
            SymptomResult.self,
            CognitiveResult.self,
            MemoryTrial.self,
            CoordinationResult.self,
            BalanceResult.self,
            BalanceTrialResult.self
        ])
    }
}