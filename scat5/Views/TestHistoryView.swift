import SwiftUI
import SwiftData

struct TestHistoryView: View {
    @Environment(AuthService.self) private var authService
    
    var sortedSessions: [TestSession] {
        authService.currentUser?.testSessions.sorted { $0.date > $1.date } ?? []
    }
    
    var body: some View {
        List {
            ForEach(sortedSessions) { session in
                NavigationLink(destination: TestResultsView(session: session)) {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(session.sessionType.rawValue)
                                .font(.headline)
                            
                            Spacer()
                            
                            if session.isComplete {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else {
                                Text("\(Int(session.progressPercentage * 100))%")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                        }
                        
                        Text(session.date, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(session.date, style: .time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("Test History")
    }
}

struct TestResultsView: View {
    let session: TestSession
    private let riskEngine = RiskAssessmentEngine()
    
    @State private var multipeerManager = MultipeerManager()
    @State private var showingDeviceList = false
    @State private var showingShareSheet = false
    @State private var shareableContent: ShareableContent?
    @State private var diagnosisTransfer: SCAT5DiagnosisTransfer?
    
    var body: some View {
        List {
            Section("Session Details") {
                HStack {
                    Text("Type")
                    Spacer()
                    Text(session.sessionType.rawValue)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Date")
                    Spacer()
                    Text(session.date, style: .date)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Status")
                    Spacer()
                    Text(session.isComplete ? "Complete" : "In Progress")
                        .foregroundColor(session.isComplete ? .green : .orange)
                }
            }
            
            // Only show sharing options if session is complete
            if session.isComplete {
                Section("Share Results") {
                    Button {
                        showingDeviceList = true
                    } label: {
                        HStack {
                            Image(systemName: "iphone")
                                .foregroundStyle(.blue)
                            Text("Send to iPhone")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Button {
                        if let diagnosis = diagnosisTransfer {
                            shareableContent = multipeerManager.generateShareableContent(from: diagnosis)
                            showingShareSheet = true
                        }
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundStyle(.green)
                            Text("Export Results")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            
            // Only show risk analysis if this is not a baseline session itself
            if session.sessionType != .baseline {
                Section("Risk Analysis (vs. Baseline)") {
                    // Symptom Severity Z-Score
                    if let zScore = session.symptomSeverityZScore {
                        RiskAnalysisRow(
                            title: "Symptom Severity Z-Score",
                            zScore: zScore,
                            interpretation: riskEngine.interpretZScore(zScore),
                            higherIsWorse: true
                        )
                    }
                    
                    // Orientation Z-Score (New)
                    if let zScore = session.orientationZScore {
                        RiskAnalysisRow(
                            title: "Orientation Z-Score",
                            zScore: zScore,
                            interpretation: riskEngine.interpretZScore(zScore),
                            higherIsWorse: false
                        )
                    }
                    
                    // Immediate Memory Z-Score
                    if let zScore = session.immediateMemoryZScore {
                        RiskAnalysisRow(
                            title: "Immediate Memory Z-Score",
                            zScore: zScore,
                            interpretation: riskEngine.interpretZScore(zScore),
                            higherIsWorse: false
                        )
                    }
                    
                    // Concentration Z-Score
                    if let zScore = session.concentrationZScore {
                        RiskAnalysisRow(
                            title: "Concentration Z-Score",
                            zScore: zScore,
                            interpretation: riskEngine.interpretZScore(zScore),
                            higherIsWorse: false
                        )
                    }
                    
                    // Delayed Recall Z-Score
                    if let zScore = session.delayedRecallZScore {
                        RiskAnalysisRow(
                            title: "Delayed Recall Z-Score",
                            zScore: zScore,
                            interpretation: riskEngine.interpretZScore(zScore),
                            higherIsWorse: false
                        )
                    }
                }
            }
            
            Section("Results") {
                if let symptomResult = session.symptomResult {
                    HStack {
                        Text("Symptom Score")
                        Spacer()
                        Text("\(symptomResult.totalScore)")
                            .foregroundColor(.secondary)
                    }
                }
                
                if let cognitiveResult = session.cognitiveResult {
                    let orientationScore = cognitiveResult.orientationResult?.correctCount ?? 0
                    let concentrationScore = cognitiveResult.concentrationResult?.totalScore ?? 0
                    let totalCognitiveScore = orientationScore + cognitiveResult.immediateMemoryTotalScore + concentrationScore
                    HStack {
                        Text("Cognitive Score")
                        Spacer()
                        Text("\(totalCognitiveScore) / 25") // Note: Max score might need adjustment
                            .foregroundColor(.secondary)
                    }
                }
                
                if let balanceResult = session.balanceResult {
                    HStack {
                        Text("Balance Errors")
                        Spacer()
                        Text("\(balanceResult.totalErrorScore)")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Test Results")
        .onAppear {
            diagnosisTransfer = SCAT5DiagnosisTransfer(from: session)
        }
        .sheet(isPresented: $showingDeviceList) {
            DeviceSelectionView(multipeerManager: multipeerManager, diagnosis: diagnosisTransfer)
        }
        .sheet(isPresented: $showingShareSheet) {
            if let content = shareableContent {
                ShareSheet(items: content.activityItems)
            }
        }
    }
}

/// A reusable view row for displaying a Z-score and its interpretation.
struct RiskAnalysisRow: View {
    let title: String
    let zScore: Double
    let interpretation: RiskLevel
    let higherIsWorse: Bool

    private var interpretationColor: Color {
        switch interpretation {
        case .low:
            return .green
        case .moderate:
            return .orange
        case .high:
            return .red
        case .normal:
            return .orange
        }
    }
    
    private var zScoreString: String {
        String(format: "%+.2f", zScore)
    }

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            VStack(alignment: .trailing) {
                Text(zScoreString)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.bold)
                Text(interpretation.rawValue)
                    .font(.caption)
                    .foregroundColor(interpretationColor)
            }
        }
    }
}

#Preview("Test History") {
    NavigationStack {
        TestHistoryView()
            .environment(AuthService())
    }
}

#Preview("Test Results") {
    let container = try! ModelContainer(for: TestSession.self, SymptomResult.self, CognitiveResult.self)
    let sampleSession = TestSession(date: .now, sessionType: .concussion)
    
    NavigationStack {
        TestResultsView(session: sampleSession)
    }
    .modelContainer(container)
}
