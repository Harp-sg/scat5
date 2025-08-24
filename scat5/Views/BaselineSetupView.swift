import SwiftUI
import SwiftData

struct BaselineSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var authService
    @State private var showingTestSelection = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .font(.system(size: 16))
                .foregroundColor(.blue)
                
                Spacer()
                
                Text("Set Baseline")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Empty space for balance
                Text("")
                    .font(.system(size: 16))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(Color(.systemBackground))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color(.systemGray4)),
                alignment: .bottom
            )
            
            ScrollView {
                VStack(spacing: 40) {
                    VStack(spacing: 20) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                        
                        VStack(spacing: 12) {
                            Text("Establish Baseline")
                                .font(.system(size: 28, weight: .light))
                                .foregroundColor(.primary)
                            
                            Text("Complete a baseline assessment to establish your normal performance levels. This will be used to compare future test results and detect changes.")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                    }
                    .padding(.top, 40)
                    
                    VStack(spacing: 20) {
                        Text("Baseline Assessment Includes:")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.primary)
                        
                        VStack(spacing: 16) {
                            AssessmentModule(
                                icon: "list.bullet.clipboard",
                                title: "Symptom Evaluation",
                                description: "22-item symptom checklist"
                            )
                            
                            AssessmentModule(
                                icon: "brain",
                                title: "Cognitive Screen",
                                description: "Memory, attention, and concentration tests"
                            )
                            
                            AssessmentModule(
                                icon: "figure.stand",
                                title: "Balance Assessment",
                                description: "BESS balance error scoring system"
                            )
                            
                            AssessmentModule(
                                icon: "hand.point.up.braille",
                                title: "Coordination Tests",
                                description: "Finger-to-nose and tandem gait"
                            )
                            
                            AssessmentModule(
                                icon: "clock.arrow.circlepath",
                                title: "Delayed Recall",
                                description: "Memory retention assessment"
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Button(action: startBaselineTest) {
                        HStack {
                            Text("Begin Baseline Assessment")
                                .font(.system(size: 18, weight: .medium))
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: 16))
                        }
                        .frame(maxWidth: 300)
                        .frame(height: 56)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                    
                    Spacer(minLength: 40)
                }
            }
        }
        .frame(maxWidth: 600)
        .background(Color(.systemGroupedBackground))
        .navigationDestination(isPresented: $showingTestSelection) {
            if let user = authService.currentUser,
               let session = user.testSessions.last(where: { $0.sessionType == .baseline && !$0.isComplete }) {
                TestSelectionView(testType: .baseline)
                    .environment(authService)
            }
        }
    }
    
    private func startBaselineTest() {
        guard let user = authService.currentUser else { return }
        
        let baselineSession = TestSession(date: .now, sessionType: .baseline)
        user.testSessions.append(baselineSession)
        user.hasBaseline = true
        
        do {
            try modelContext.save()
            showingTestSelection = true
        } catch {
            print("Failed to create baseline session: \(error)")
        }
    }
}

struct AssessmentModule: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.green)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
    }
}

#Preview {
    NavigationStack {
        BaselineSetupView()
            .environment(AuthService())
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
}