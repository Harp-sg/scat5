import SwiftUI

struct MainDashboardView: View {
    @Environment(AuthService.self) private var authService
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(ViewRouter.self) private var viewRouter
    @State private var showingProfile = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Section
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SCAT5 Assessment Platform")
                            .font(.system(size: 28, weight: .medium, design: .rounded))
                            .foregroundColor(.primary)
                        
                        if let user = authService.currentUser {
                            Text("Welcome back, \(user.firstName)")
                                .font(.system(size: 18, weight: .light))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Status indicator
                    if let user = authService.currentUser {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(user.hasBaseline ? Color.green : Color.orange)
                                .frame(width: 8, height: 8)
                                .scaleEffect(user.hasBaseline ? 1.0 : 1.2)
                                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: user.hasBaseline)
                            
                            Text(user.hasBaseline ? "Baseline Ready" : "Setup Required")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(user.hasBaseline ? .green : .orange)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray6).opacity(0.8))
                        .cornerRadius(12)
                    }
                }
            }
            .padding(.horizontal, 40)
            .padding(.top, 30)
            
            Spacer()
            
            // Main Assessment Cards
            VStack(spacing: 30) {
                // Primary: Concussion Assessment - Large & Urgent
                Button(action: {
                    viewRouter.navigate(to: .testSelection(.concussion))
                }) {
                    UrgentAssessmentCard()
                }
                .buttonStyle(VolumetricButtonStyle())
                
                // Secondary Options Row
                HStack(spacing: 25) {
                    Button(action: {
                        viewRouter.navigate(to: .testSelection(.postExercise))
                    }) {
                        SecondaryAssessmentCard(
                            title: "Post-Exercise\nStability",
                            icon: "figure.walk",
                            color: .blue,
                            description: "Evaluate performance after activity"
                        )
                    }
                    .buttonStyle(VolumetricButtonStyle())
                    
                    Button(action: {
                        viewRouter.navigate(to: .interactiveDiagnosis)
                    }) {
                        SecondaryAssessmentCard(
                            title: "Interactive\nDiagnosis",
                            icon: "wand.and.rays",
                            color: .gray,
                            description: "AI-powered diagnostic tools"
                        )
                    }
                    .buttonStyle(VolumetricButtonStyle())
                }
            }
            
            Spacer()
            
            // Footer with Profile Button
            HStack {
                Spacer()
                
                Button(action: {
                    showingProfile = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 18))
                        Text("Profile")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6).opacity(0.8))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 30)
        }
        .padding(40)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(.systemGray6).opacity(0.3),
                    Color(.systemGray5).opacity(0.2)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(25)
        .sheet(isPresented: $showingProfile) {
            ProfileView()
                .environment(authService)
        }
    }
}

// Urgent Primary Assessment Card for Concussion
struct UrgentAssessmentCard: View {
    @State private var pulseAnimation = false
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 25)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.red.opacity(0.2),
                            Color.red.opacity(0.1),
                            Color.red.opacity(0.05)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 25)
                        .stroke(Color.red.opacity(0.6), lineWidth: 2)
                )
                .scaleEffect(pulseAnimation ? 1.02 : 1.0)
                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: pulseAnimation)
            
            HStack(spacing: 25) {
                VStack(spacing: 15) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 45, weight: .light))
                        .foregroundColor(.red)
                        .shadow(color: .red.opacity(0.3), radius: 8, x: 0, y: 2)
                    
                    Text("URGENT")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.red)
                        .tracking(2)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Concussion Assessment")
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("Immediate evaluation for suspected head injury")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                        Text("~15-20 minutes")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.orange)
                    }
                    .padding(.top, 4)
                }
                
                Spacer()
                
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.red)
                    .opacity(0.8)
            }
            .padding(30)
        }
        .frame(height: 160)
        .shadow(color: Color.red.opacity(0.2), radius: 15, x: 0, y: 8)
        .onAppear {
            pulseAnimation = true
        }
    }
}

// Secondary Assessment Card
struct SecondaryAssessmentCard: View {
    let title: String
    let icon: String
    let color: Color
    let description: String
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            color.opacity(0.15),
                            color.opacity(0.08),
                            color.opacity(0.03)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(color.opacity(0.4), lineWidth: 1.5)
                )
            
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 35, weight: .light))
                    .foregroundColor(color)
                    .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 2)
                
                Text(title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                Text(description)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 8)
            }
            .padding(20)
        }
        .frame(width: 200, height: 140)
        .shadow(color: color.opacity(0.15), radius: 10, x: 0, y: 5)
    }
}

// Custom button style for volumetric effect
struct VolumetricButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    MainDashboardView()
        .environment(AuthService())
        .environment(AppViewModel())
        .environment(ViewRouter())
}