import SwiftUI
import SwiftData

struct TestSelectionView: View {
    let testType: SessionType
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var authService
    @State private var currentSession: TestSession?
    @State private var showingTestInterface = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 10) {
                Image(systemName: testType == .concussion ? "brain.head.profile" : "figure.walk")
                    .font(.system(size: 50))
                    .foregroundColor(testType == .concussion ? .red : .blue)
                
                Text(testType.rawValue)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Complete all modules for accurate assessment")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Progress Bar
            if let session = currentSession {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Overall Progress")
                            .font(.headline)
                        Spacer()
                        Text("\(Int(session.progressPercentage * 100))%")
                            .font(.headline)
                            .foregroundColor(.blue)
                    }
                    
                    ProgressView(value: session.progressPercentage)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                        .scaleEffect(x: 1, y: 2, anchor: .center)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            // Test Modules
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 15) {
                ModuleCard(
                    title: "Symptom\nEvaluation",
                    icon: "list.bullet.clipboard",
                    isCompleted: currentSession?.completedModules.contains("Symptom") ?? false
                ) {
                    startModule("Symptom")
                }
                
                ModuleCard(
                    title: "Cognitive\nScreen",
                    icon: "brain",
                    isCompleted: currentSession?.completedModules.contains("Cognitive") ?? false
                ) {
                    startModule("Cognitive")
                }
                
                ModuleCard(
                    title: "Balance\nAssessment",
                    icon: "figure.stand",
                    isCompleted: currentSession?.completedModules.contains("Balance") ?? false
                ) {
                    startModule("Balance")
                }
                
                ModuleCard(
                    title: "Coordination\nTest",
                    icon: "hand.point.up.braille",
                    isCompleted: currentSession?.completedModules.contains("Coordination") ?? false
                ) {
                    startModule("Coordination")
                }
                
                ModuleCard(
                    title: "Delayed\nRecall",
                    icon: "clock.arrow.circlepath",
                    isCompleted: currentSession?.completedModules.contains("DelayedRecall") ?? false
                ) {
                    startModule("DelayedRecall")
                }
            }
            
            Spacer()
            
            if currentSession?.isComplete == true {
                Button("View Results") {
                    // Navigate to results view
                }
                .buttonStyle(.borderedProminent)
                .font(.headline)
            }
        }
        .padding()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            createOrLoadSession()
        }
        .sheet(isPresented: $showingTestInterface) {
            if let session = currentSession {
                TestInterfaceView(session: session)
                    .environment(authService)
            }
        }
    }
    
    private func createOrLoadSession() {
        guard let user = authService.currentUser else { return }
        
        // Check for existing incomplete session of this type
        if let existingSession = user.testSessions.first(where: { $0.sessionType == testType && !$0.isComplete }) {
            currentSession = existingSession
        } else {
            // Create new session
            let newSession = TestSession(date: .now, sessionType: testType)
            user.testSessions.append(newSession)
            currentSession = newSession
            
            do {
                try modelContext.save()
            } catch {
                print("Failed to create session: \(error)")
            }
        }
    }
    
    private func startModule(_ moduleName: String) {
        showingTestInterface = true
    }
}

struct ModuleCard: View {
    let title: String
    let icon: String
    let isCompleted: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 15) {
                ZStack {
                    Circle()
                        .fill(isCompleted ? Color.green : Color.blue)
                        .frame(width: 50, height: 50)
                    
                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.title2)
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: icon)
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isCompleted ? Color.green : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .frame(height: 120)
    }
}