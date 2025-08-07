import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(AuthService.self) private var authService
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(ViewRouter.self) private var viewRouter
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        // Main content based on authentication state and routing
        Group {
            if !authService.isAuthenticated {
                LoginView()
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            } else {
                switch viewRouter.currentView {
                case .dashboard:
                    MainDashboardView()
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                case .testSelection(let sessionType):
                    TestSelectionView(testType: sessionType)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authService.isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: viewRouter.currentView)
        .onAppear {
            // Set the model context for the auth service when the view appears
            authService.setModelContext(modelContext)
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