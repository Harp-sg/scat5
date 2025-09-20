import SwiftUI
import SwiftData

struct EmergencyAssessmentFlowView: View {
    @Environment(AuthService.self) private var authService
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(ViewRouter.self) private var viewRouter
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    
    @State private var session: TestSession = TestSession(date: .now, sessionType: .concussion)
    @State private var currentIndex: Int = 0
    @State private var lastCompletedCount: Int = 0
    @State private var isAdvancing: Bool = false
    
    private let orderedModules: [TestModule] = [
        .symptoms,
        .cognitive,
        .immediateMemory,
        .balance,
        .coordination,
        .delayedRecall
    ]
    
    var body: some View {
        ZStack {
            Color.clear.ignoresSafeArea()
            
            VStack(spacing: 16) {
                Text("Emergency Assessment")
                    .font(.title2.weight(.bold))
                
                Text("Module \(currentIndex + 1) of \(orderedModules.count): \(orderedModules[currentIndex].rawValue)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                ProgressView(value: Double(currentIndex), total: Double(orderedModules.count))
                    .progressViewStyle(.linear)
                    .padding(.horizontal, 24)
                
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text("Emergency mode locks dashboard and carousel")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                
                Button {
                    Task { await exitEmergency() }
                } label: {
                    Label("Exit Emergency", systemImage: "xmark.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
            .padding(20)
            .glassBackgroundEffect()
            .padding(.horizontal, 40)
        }
        .overlay(alignment: .topTrailing) {
            Button {
                Task { await exitEmergency() }
            } label: {
                Image(systemName: "xmark")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .padding(12)
                    .background(.regularMaterial, in: Circle())
                    .overlay(
                        Circle()
                            .stroke(.primary.opacity(0.2), lineWidth: 1)
                    )
            }
            .padding(24)
            .buttonStyle(.plain)
        }
        .onAppear {
            appViewModel.currentSession = session
            currentIndex = 0
            lastCompletedCount = session.completedModules.count
            startCurrentModule()
        }
        .onChange(of: session.completedModules.count) { newCount in
            guard newCount > lastCompletedCount else { return }
            lastCompletedCount = newCount
            advanceToNextModule()
        }
        .onChange(of: appViewModel.isImmersiveSpaceShown) { isShown in
            if !isShown, isAdvancing {
                isAdvancing = false
                startCurrentModule()
            }
        }
    }
    
    private func startCurrentModule() {
        guard currentIndex >= 0 && currentIndex < orderedModules.count else {
            Task { await finishFlow() }
            return
        }
        
        let module = orderedModules[currentIndex]
        appViewModel.currentModule = module
        
        Task {
            do {
                try await openImmersiveSpace(id: "TestImmersiveSpace")
                await MainActor.run {
                    appViewModel.isImmersiveSpaceShown = true
                }
            } catch {
                print("Failed to open TestImmersiveSpace: \(error)")
            }
        }
    }
    
    private func advanceToNextModule() {
        guard currentIndex + 1 < orderedModules.count else {
            Task { await finishFlow() }
            return
        }
        
        currentIndex += 1
        isAdvancing = true
        
        Task {
            await dismissImmersiveSpace()
            await MainActor.run {
                appViewModel.isImmersiveSpaceShown = false
            }
        }
    }
    
    private func finishFlow() async {
        await dismissImmersiveSpace()
        await MainActor.run {
            appViewModel.isImmersiveSpaceShown = false
        }
        await exitEmergency()
    }
    
    private func exitEmergency() async {
        await dismissImmersiveSpace()
        await MainActor.run {
            appViewModel.isImmersiveSpaceShown = false
            authService.logout()
            viewRouter.navigate(to: .login)
        }
    }
}