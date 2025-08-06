import SwiftUI

struct CoordinationTestView: View {
    @Bindable var coordinationResult: CoordinationResult

    var body: some View {
        Form {
            Section(header: Text("Coordination Exam")) {
                Toggle("Finger-to-Nose Test is Normal", isOn: $coordinationResult.fingerToNoseNormal)
                Toggle("Tandem Gait Test is Normal", isOn: $coordinationResult.tandemGaitNormal)
            }
        }
        .navigationTitle("Coordination Exam")
    }
}