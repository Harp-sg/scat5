import SwiftUI

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
                    let totalScore = cognitiveResult.orientationScore + cognitiveResult.immediateMemoryTotalScore + cognitiveResult.concentrationScore
                    HStack {
                        Text("Cognitive Score")
                        Spacer()
                        Text("\(totalScore) / 25")
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
    }
}