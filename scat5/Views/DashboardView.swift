import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    let athlete: Athlete
    
    // Sort sessions once for consistent use in charts
    private var sortedSessions: [TestSession] {
        athlete.testSessions.sorted(by: { $0.date < $1.date })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                Text("Performance History")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                symptomScoreChart
                
                balanceErrorChart
                
                cognitiveScoreChart
            }
            .padding()
        }
        .navigationTitle("Dashboard: \(athlete.name)")
        .background(Color(.systemGroupedBackground))
    }
    
    @ViewBuilder
    private var symptomScoreChart: some View {
        if !sortedSessions.compactMap({ $0.symptomResult }).isEmpty {
            VStack(alignment: .leading) {
                Text("Symptom Severity Score")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Lower is better. Shows total score from the 22-item symptom checklist.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Chart {
                    ForEach(sortedSessions) { session in
                        if let symptomResult = session.symptomResult {
                            LineMark(
                                x: .value("Date", session.date, unit: .day),
                                y: .value("Score", symptomResult.totalScore)
                            )
                            .foregroundStyle(by: .value("Session Type", session.sessionType.rawValue))
                            
                            PointMark(
                                x: .value("Date", session.date, unit: .day),
                                y: .value("Score", symptomResult.totalScore)
                            )
                            .foregroundStyle(by: .value("Session Type", session.sessionType.rawValue))
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.month().day())
                    }
                }
                .frame(height: 250)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }
    
    @ViewBuilder
    private var balanceErrorChart: some View {
        if !sortedSessions.compactMap({ $0.balanceResult }).isEmpty {
            VStack(alignment: .leading) {
                Text("Balance Errors (BESS)")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Lower is better. Shows total errors across all 6 balance trials.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Chart {
                    ForEach(sortedSessions) { session in
                        if let balanceResult = session.balanceResult {
                            BarMark(
                                x: .value("Date", session.date, unit: .day),
                                y: .value("Errors", balanceResult.totalErrorScore)
                            )
                            .foregroundStyle(by: .value("Session Type", session.sessionType.rawValue))
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.month().day(), centered: true)
                    }
                }
                .frame(height: 250)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }
    
    @ViewBuilder
    private var cognitiveScoreChart: some View {
        if !sortedSessions.compactMap({ $0.cognitiveResult }).isEmpty {
            VStack(alignment: .leading) {
                Text("Cognitive Score")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Higher is better. Combines Orientation, Immediate Memory, and Concentration scores (Max 25).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Chart {
                    ForEach(sortedSessions) { session in
                        if let cognitiveResult = session.cognitiveResult {
                            let totalScore = cognitiveResult.orientationScore + cognitiveResult.immediateMemoryTotalScore + cognitiveResult.concentrationScore
                            PointMark(
                                x: .value("Date", session.date, unit: .day),
                                y: .value("Score", totalScore)
                            )
                            .foregroundStyle(by: .value("Session Type", session.sessionType.rawValue))
                            .symbol(by: .value("Session Type", session.sessionType.rawValue))
                        }
                    }
                }
                .chartYScale(domain: 0...25)
                .chartXAxis {
                     AxisMarks(values: .stride(by: .day)) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.month().day())
                    }
                }
                .frame(height: 250)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }
}