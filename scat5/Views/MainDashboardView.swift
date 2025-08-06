import SwiftUI

struct MainDashboardView: View {
    @Environment(AuthService.self) private var authService
    @State private var showingProfile = false
    @State private var showingConcussionTest = false
    @State private var showingPostExerciseTest = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Top Navigation Bar
                HStack {
                    HStack(spacing: 12) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 24))
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("SCAT5 Assessment")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.primary)
                            
                            if let user = authService.currentUser {
                                Text("Welcome, \(user.firstName)")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 16) {
                        // Status indicator
                        if let user = authService.currentUser {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(user.hasBaseline ? Color.green : Color.orange)
                                    .frame(width: 8, height: 8)
                                
                                Text(user.hasBaseline ? "Baseline Set" : "No Baseline")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Button {
                            showingProfile = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "person.circle")
                                    .font(.system(size: 20))
                                Text("Profile")
                                    .font(.system(size: 14))
                            }
                            .foregroundColor(.blue)
                        }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 20)
                .background(Color(.systemBackground))
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color(.systemGray5)),
                    alignment: .bottom
                )
                
                // Main Content
                ScrollView {
                    VStack(spacing: 40) {
                        // Header Section
                        VStack(spacing: 16) {
                            Text("Select Assessment Type")
                                .font(.system(size: 28, weight: .light))
                                .foregroundColor(.primary)
                            
                            Text("Choose the appropriate assessment protocol based on the clinical scenario")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 40)
                        
                        // Assessment Options
                        HStack(spacing: 32) {
                            Button(action: {
                                showingConcussionTest = true
                            }) {
                                AssessmentCard(
                                    title: "Concussion Assessment",
                                    subtitle: "SCAT5 Protocol",
                                    description: "Complete evaluation for suspected traumatic brain injury including symptom assessment, cognitive testing, and neurological examination.",
                                    icon: "brain.head.profile",
                                    color: .red,
                                    severity: "High Priority"
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Button(action: {
                                showingPostExerciseTest = true
                            }) {
                                AssessmentCard(
                                    title: "Post-Exercise Stability",
                                    subtitle: "Balance & Coordination",
                                    description: "Assess balance, coordination, and stability following physical activity to establish baseline or monitor recovery.",
                                    icon: "figure.walk",
                                    color: .blue,
                                    severity: "Standard"
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.horizontal, 32)
                        
                        Spacer(minLength: 40)
                    }
                }
                .background(Color(.systemGroupedBackground))
            }
            .navigationDestination(isPresented: $showingConcussionTest) {
                TestSelectionView(testType: .concussion)
                    .environment(authService)
            }
            .navigationDestination(isPresented: $showingPostExerciseTest) {
                TestSelectionView(testType: .postExercise)
                    .environment(authService)
            }
        }
        .sheet(isPresented: $showingProfile) {
            ProfileView()
                .environment(authService)
        }
    }
}

struct AssessmentCard: View {
    let title: String
    let subtitle: String
    let description: String
    let icon: String
    let color: Color
    let severity: String
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.1))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: icon)
                        .font(.system(size: 36, weight: .light))
                        .foregroundColor(color)
                }
                
                VStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(color)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(color.opacity(0.1))
                        .cornerRadius(12)
                }
            }
            .padding(.top, 32)
            .padding(.horizontal, 24)
            
            // Content
            VStack(spacing: 16) {
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                
                HStack {
                    Text(severity)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(color)
                    
                    Spacer()
                    
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(color)
                }
            }
            .padding(24)
            .background(Color(.systemBackground))
        }
        .frame(maxWidth: 320, minHeight: 280)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}