import SwiftUI

#if DEBUG
struct DebugMenuView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Speech Testing") {
                    NavigationLink("Speech Control Test") {
                        SpeechControlTestView()
                    }
                    
                    NavigationLink("Immediate Memory Test") {
                        // Your existing immediate memory view
                    }
                    
                    NavigationLink("Delayed Recall Test") {
                        // Your existing delayed recall view  
                    }
                }
            }
            .navigationTitle("Debug Menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    DebugMenuView()
        .environment(SpeechControlManager())
        .environment(SpeechControlCoordinator())
}
#endif