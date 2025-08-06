import SwiftUI

struct CognitiveTestRunnerView: View {
    @Bindable var cognitiveResult: CognitiveResult

    var body: some View {
        Form {
            Section("Cognitive Assessment") {
                NavigationLink(destination: OrientationTestView(cognitiveResult: cognitiveResult)) {
                    HStack {
                        Text("Orientation")
                        Spacer()
                        Text("Score: \(cognitiveResult.orientationScore) / 5").foregroundStyle(.secondary)
                    }
                }
                
                NavigationLink(destination: ImmediateMemoryTestView(cognitiveResult: cognitiveResult)) {
                    HStack {
                        Text("Immediate Memory")
                        Spacer()
                        Text("Score: \(cognitiveResult.immediateMemoryTotalScore) / 15").foregroundStyle(.secondary)
                    }
                }
                
                NavigationLink(destination: ConcentrationTestView(cognitiveResult: cognitiveResult)) {
                    HStack {
                        Text("Concentration")
                        Spacer()
                        Text("Score: \(cognitiveResult.concentrationScore) / 5").foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Cognitive Tests")
    }
}