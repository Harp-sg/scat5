import SwiftUI
import SwiftData

struct FullAssessmentFlowView: View {
    let sessionType: SessionType
    
    @Environment(AuthService.self) private var authService
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(ViewRouter.self) private var viewRouter
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    
    @State private var session: TestSession?
    @State private var currentIndex: Int = 0
    @State private var lastCompletedCount: Int = 0
    @State private var isAdvancing: Bool = false
    @State private var showingCompletionView: Bool = false
    
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
            
            if showingCompletionView {
                // Show completion view when diagnosis is finished
                if let session = session {
                    DiagnosisCompletionView(session: session) {
                        // Handle dismissal - return to test selection
                        showingCompletionView = false
                        viewRouter.navigate(to: .testSelection(sessionType))
                    }
                }
            } else {
                VStack(spacing: 16) {
                    Text("SCAT5: Full Diagnosis")
                        .font(.title2.weight(.bold))
                    
                    if currentIndex < orderedModules.count {
                        Text("Module \(currentIndex + 1) of \(orderedModules.count): \(orderedModules[currentIndex].rawValue)")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Completing assessment...")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    
                    // Use actual session progress instead of currentIndex
                    if let session = session {
                        let progress = session.progressPercentage
                        ProgressView(value: progress, total: 1.0)
                            .progressViewStyle(.linear)
                            .padding(.horizontal, 24)
                        
                        Text("\(Int(progress * 100))% Complete")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ProgressView(value: 0, total: 1.0)
                            .progressViewStyle(.linear)
                            .padding(.horizontal, 24)
                    }
                    
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                        Text("Runs all SCAT5 modules in order. You can exit anytime.")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    
                    Button {
                        Task { await exitFlow() }
                    } label: {
                        Label("Exit Full Diagnosis", systemImage: "xmark.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
                .padding(20)
                .glassBackgroundEffect()
                .padding(.horizontal, 40)
            }
        }
        .overlay(alignment: .topTrailing) {
            if !showingCompletionView {
                Button {
                    Task { await exitFlow() }
                } label: {
                    Image(systemName: "xmark")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(12)
                        .background(.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .padding()
            }
        }
        .onAppear {
            prepareSessionAndStart()
        }
        .onChange(of: session?.completedModules.count ?? 0) { newCount in
            guard newCount > lastCompletedCount else { return }
            // Persist progress
            do { try modelContext.save() } catch { print("Save error: \(error)") }
            lastCompletedCount = newCount
            
            // Check if we've completed all modules
            if newCount >= orderedModules.count {
                Task { await finishFlow() }
            } else {
                advanceToNextModule()
            }
        }
        .onChange(of: appViewModel.isImmersiveSpaceShown) { isShown in
            if !isShown, isAdvancing {
                isAdvancing = false
                startCurrentModule()
            }
        }
    }
    
    private func prepareSessionAndStart() {
        guard let user = authService.currentUser else {
            return
        }
        
        if let existing = user.testSessions.first(where: { $0.sessionType == sessionType && !$0.isComplete }) {
            session = existing
        } else {
            let newSession = TestSession(date: .now, sessionType: sessionType)
            user.testSessions.append(newSession)
            session = newSession
            do { try modelContext.save() } catch { print("Failed to create session: \(error)") }
        }
        
        appViewModel.currentSession = session
        
        // Resume from first incomplete module
        let completed = Set(session?.completedModules ?? [])
        if let firstIncomplete = orderedModules.firstIndex(where: { !completed.contains($0.rawValue) }) {
            currentIndex = firstIncomplete
        } else {
            // Already complete - show completion view
            showingCompletionView = true
            return
        }
        lastCompletedCount = session?.completedModules.count ?? 0
        
        startCurrentModule()
    }
    
    private func startCurrentModule() {
        guard let session = session else { return }
        guard currentIndex >= 0 && currentIndex < orderedModules.count else {
            Task { await finishFlow() }
            return
        }
        let module = orderedModules[currentIndex]
        appViewModel.currentModule = module
        appViewModel.currentSession = session
        
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
        
        // Persist final state
        do { 
            try modelContext.save() 
        } catch { 
            print("Final save error: \(error)") 
        }
        
        // Show completion view instead of immediately returning to selection
        await MainActor.run {
            showingCompletionView = true
        }
    }
    
    private func exitFlow() async {
        await dismissImmersiveSpace()
        await MainActor.run {
            appViewModel.isImmersiveSpaceShown = false
        }
        // Save progress before exiting
        do { try modelContext.save() } catch { print("Exit save error: \(error)") }
        await MainActor.run {
            viewRouter.navigate(to: .testSelection(sessionType))
        }
    }
}