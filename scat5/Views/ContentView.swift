import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var authService
    @Environment(ViewRouter.self) private var viewRouter
    @Environment(AppViewModel.self) private var appViewModel

    var body: some View {
        ZStack {
            Group {
                if authService.isAuthenticated {
                    switch viewRouter.currentView {
                    case .dashboard:
                        MainDashboardView()
                    case .testSelection(let sessionType):
                        TestSelectionView(testType: sessionType)
                    }
                } else {
                    LoginView()
                }
            }
            .onAppear {
                authService.setModelContext(modelContext)
            }
            .blur(radius: appViewModel.isImmersiveSpaceShown ? 2 : 0) // Very subtle blur
            .scaleEffect(appViewModel.isImmersiveSpaceShown ? 0.99 : 1.0) // Almost no scale change
            .opacity(appViewModel.isImmersiveSpaceShown ? 0.8 : 1.0) // Light dimming for integration

            if appViewModel.isImmersiveSpaceShown {
                Color.black.opacity(0.1) // Very light overlay - just enough to show focus
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: appViewModel.isImmersiveSpaceShown)
    }
}

#Preview("Dashboard") {
    ContentView()
        .environment(AuthService())
        .environment(ViewRouter())
        .environment(AppViewModel())
        .modelContainer(for: [
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
}

#Preview("Login") {
    ContentView()
        .environment({
            let authService = AuthService()
            // Don't authenticate for login preview
            return authService
        }())
        .environment(ViewRouter())
        .environment(AppViewModel())
}