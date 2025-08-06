import SwiftUI

struct SymptomEvaluationView: View {
    @Bindable var symptomResult: SymptomResult

    var body: some View {
        List {
            Section(
                header: Text("Symptom Evaluation"),
                footer: summaryView
            ) {
                ForEach($symptomResult.items) { $item in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.symptom.rawValue)
                        HStack {
                            Slider(value: .init(get: { Double(item.severity) }, set: { item.severity = Int($0) }), in: 0...6, step: 1)
                            Text("\(item.severity)").frame(width: 20)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Symptom Checklist")
    }
    
    private var summaryView: some View {
        HStack {
            Text("Total Symptoms: \(symptomResult.numberOfSymptoms)").font(.headline)
            Spacer()
            Text("Total Score: \(symptomResult.totalScore)").font(.headline)
        }
        .padding()
    }
}