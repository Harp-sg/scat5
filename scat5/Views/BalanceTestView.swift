import SwiftUI

struct BalanceTestView: View {
    @Bindable var balanceResult: BalanceResult

    var body: some View {
        Form {
            Section(header: Text("Balance Examination (BESS)"), footer: Text("Total Errors: \(balanceResult.totalErrorScore)").font(.headline)) {
                Text("Tap a trial to begin the 20s test. Max 10 errors per trial.")
                    .font(.caption)
                
                ForEach(balanceResult.trials) { trial in
                    NavigationLink(destination: BalanceTrialActiveView(trial: trial)) {
                        HStack {
                            Text(trial.stance.rawValue)
                            Spacer()
                            Text("Errors: \(trial.errorCount)").foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Balance Exam")
    }
}