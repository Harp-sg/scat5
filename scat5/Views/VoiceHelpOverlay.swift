import SwiftUI

struct VoiceHelpOverlay: View {
    @Environment(SpeechControlCoordinator.self) private var speechCoordinator
    
    var body: some View {
        ZStack {
            // Background blur
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    speechCoordinator.isShowingHelp = false
                }
            
            // Help content
            VStack(spacing: 20) {
                // Header
                HStack {
                    Image(systemName: "mic.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    Text("Voice Commands")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button(action: {
                        speechCoordinator.isShowingHelp = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Commands list
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(speechCoordinator.getAvailableCommands(), id: \.self) { command in
                            HStack {
                                Image(systemName: "quote.bubble")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .frame(width: 16)
                                
                                Text(command)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.systemGray6).opacity(0.5))
                            )
                        }
                    }
                }
                .frame(maxHeight: 300)
                
                // Footer
                Text("Say \"Help\" anytime to see these commands")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .frame(maxWidth: 400)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
            )
        }
    }
}

#Preview {
    VoiceHelpOverlay()
        .environment(SpeechControlCoordinator())
}