import SwiftUI

struct SpeechControlTestView: View {
    @Environment(SpeechControlManager.self) private var speechManager
    @State private var testResults: [String] = []
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Speech Control Test")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // Status Section
            VStack(spacing: 12) {
                HStack {
                    Text("Status:")
                        .fontWeight(.semibold)
                    Spacer()
                    Text(speechManager.isListening ? "Listening" : "Stopped")
                        .foregroundColor(speechManager.isListening ? .green : .red)
                }
                
                if let error = speechManager.errorMessage {
                    HStack {
                        Text("Error:")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(error)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                HStack {
                    Text("Last Text:")
                        .fontWeight(.semibold)
                    Spacer()
                    Text(speechManager.lastRecognizedText.isEmpty ? "None" : speechManager.lastRecognizedText)
                        .multilineTextAlignment(.trailing)
                }
                
                HStack {
                    Text("Last Command:")
                        .fontWeight(.semibold)
                    Spacer()
                    Text(speechManager.currentCommand.isEmpty ? "None" : speechManager.currentCommand)
                        .multilineTextAlignment(.trailing)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            // Control Buttons
            HStack(spacing: 20) {
                Button(speechManager.isEnabled ? "Stop Speech" : "Start Speech") {
                    speechManager.toggleSpeechControl()
                }
                .padding()
                .background(speechManager.isEnabled ? Color.red : Color.green)
                .foregroundColor(.white)
                .cornerRadius(8)
                
                Button("Clear Results") {
                    testResults.removeAll()
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            
            // Test Commands Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Try these test commands:")
                    .fontWeight(.semibold)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("• \"Dashboard\" or \"Home\"")
                    Text("• \"Next\" or \"Previous\"")
                    Text("• \"Select\" or \"Choose\"")
                    Text("• \"Start Test\"")
                    Text("• \"Help\"")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            
            // Results History
            if !testResults.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Command History:")
                        .fontWeight(.semibold)
                    
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(testResults.enumerated()), id: \.offset) { index, result in
                                Text("\(index + 1). \(result)")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(6)
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
            }
            
            Spacer()
        }
        .padding()
        .onChange(of: speechManager.currentCommand) { oldValue, newValue in
            if !newValue.isEmpty && newValue != oldValue {
                testResults.append(newValue)
            }
        }
    }
}

#Preview {
    SpeechControlTestView()
        .environment(SpeechControlManager())
}