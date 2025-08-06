import SwiftUI

struct TestSessionView: View {
    @Bindable var session: TestSession

    var body: some View {
        Form {
            Section("SCAT5 Modules") {
                if let result = session.symptomResult {
                    NavigationLink(destination: SymptomEvaluationView(symptomResult: result)) {
                        HStack {
                            Text("Symptom Evaluation")
                            Spacer()
                            Text("Score: \(result.totalScore)").foregroundStyle(.secondary)
                        }
                    }
                }
                
                if let result = session.cognitiveResult {
                    NavigationLink(destination: CognitiveTestRunnerView(cognitiveResult: result)) {
                        let totalScore = result.orientationScore + result.immediateMemoryTotalScore + result.concentrationScore
                        HStack {
                            Text("Cognitive Screen")
                            Spacer()
                            Text("Score: \(totalScore) / 25").foregroundStyle(.secondary)
                        }
                    }
                }
                
                if let result = session.coordinationResult {
                    NavigationLink(destination: CoordinationTestView(coordinationResult: result)) {
                        Text("Coordination Exam")
                    }
                }
                
                if let result = session.balanceResult {
                    NavigationLink(destination: BalanceTestView(balanceResult: result)) {
                        HStack {
                            Text("Balance Exam (BESS)")
                            Spacer()
                            Text("Errors: \(result.totalErrorScore)").foregroundStyle(.secondary)
                        }
                    }
                }
                
                if let result = session.cognitiveResult {
                    NavigationLink(destination: DelayedRecallTestView(cognitiveResult: result)) {
                        HStack {
                            Text("Delayed Recall")
                            Spacer()
                            Text("Score: \(result.delayedRecallScore) / 5").foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(sessionTitle)
    }
    
    private var sessionTitle: String {
        "Session: \(session.date.formatted(date: .numeric, time: .shortened))"
    }
}