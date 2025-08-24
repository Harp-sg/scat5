import SwiftUI

struct SpeechControlOverlay: View {
    @Environment(SpeechControlManager.self) private var speechManager
    @State private var showingCommands = false
    @State private var showingToggle = true
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                
                // Speech control toggle
                if showingToggle {
                    speechControlToggle
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            
            Spacer()
            
            // Status indicator when listening
            if speechManager.isListening {
                listeningIndicator
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Commands help sheet
            if showingCommands {
                commandsOverlay
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: speechManager.isListening)
        .animation(.easeInOut(duration: 0.3), value: showingCommands)
    }
    
    // MARK: - Speech Control Toggle
    private var speechControlToggle: some View {
        VStack(spacing: 8) {
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    speechManager.isEnabled.toggle()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: speechManager.isEnabled ? "mic.fill" : "mic.slash.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(speechManager.isEnabled ? .blue : .gray)
                    
                    Text(speechManager.isEnabled ? "Voice ON" : "Voice OFF")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(speechManager.isEnabled ? .blue : .gray)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(speechManager.isEnabled ? Color.blue.opacity(0.5) : Color.gray.opacity(0.3), lineWidth: 1)
                        )
                )
                .shadow(color: speechManager.isEnabled ? Color.blue.opacity(0.3) : Color.clear, radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            
            // Show error message if any
            if let errorMessage = speechManager.errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
            }
            
            // Debug: Reset button when command is stuck
            #if DEBUG
            if !speechManager.currentCommand.isEmpty {
                Button("Clear") {
                    speechManager.currentCommand = ""
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.red)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }
            
            // Add restart button for debugging
            if speechManager.isEnabled {
                Button("Restart") {
                    speechManager.forceRestart()
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }
            #endif
            
            // Help button
            if speechManager.isEnabled {
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showingCommands.toggle()
                    }
                }) {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.blue.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.trailing, 20)
        .padding(.top, 20)
    }
    
    // MARK: - Listening Indicator
    private var listeningIndicator: some View {
        HStack(spacing: 8) {
            // Animated microphone icon
            Image(systemName: "mic.fill")
                .font(.system(size: 16))
                .foregroundColor(.blue)
                .scaleEffect(speechManager.isListening ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: speechManager.isListening)
            
            Text("Listening...")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.blue)
            
            if !speechManager.currentCommand.isEmpty {
                Text("• \(speechManager.currentCommand)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            // Debug info for API version (can be removed in production)
            #if DEBUG
            if #available(iOS 26.0, visionOS 26.0, *) {
                Text("• Modern API")
                    .font(.system(size: 10))
                    .foregroundColor(.green)
            } else {
                Text("• Legacy API")
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
            }
            #endif
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.blue.opacity(0.5), lineWidth: 1)
                )
        )
        .padding(.bottom, 80)
    }
    
    // MARK: - Commands Help Overlay
    private var commandsOverlay: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Text("Voice Commands")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button("Close") {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showingCommands = false
                        }
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue)
                }
                
                // Command categories
                CommandCategoryView(title: "Navigation", commands: [
                    "\"Dashboard\" or \"Home\"",
                    "\"Start Concussion\"",
                    "\"Post Exercise\"",
                    "\"Interactive Diagnosis\"",
                    "\"Go Back\""
                ])
                
                CommandCategoryView(title: "Carousel Control", commands: [
                    "\"Next\" or \"Right\"",
                    "\"Previous\" or \"Left\"",
                    "\"Select\" or \"Choose\"",
                    "\"Select [Module Name]\""
                ])
                
                CommandCategoryView(title: "Test Control", commands: [
                    "\"Start Test\"",
                    "\"Complete\" or \"Finish\"",
                    "\"Next Trial\"",
                    "\"Start Recording\"",
                    "\"Stop Recording\""
                ])
                
                CommandCategoryView(title: "General", commands: [
                    "\"Help\"",
                    "\"Speech Off\""
                ])
            }
            .padding(20)
        }
        .frame(maxHeight: 400)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 40)
        .padding(.bottom, 40)
    }
}

// MARK: - Command Category View
struct CommandCategoryView: View {
    let title: String
    let commands: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 4) {
                ForEach(commands, id: \.self) { command in
                    Text("• \(command)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.2)
        SpeechControlOverlay()
    }
    .environment(SpeechControlManager())
}