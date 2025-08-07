import SwiftUI

struct LoginView: View {
    @Environment(AuthService.self) private var authService
    @State private var showingCreateAccount = false
    @State private var username = ""
    @State private var password = ""
    @State private var showingLoginError = false
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // App Icon and Title
            VStack(spacing: 16) {
                // Simplified App Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.blue, Color.blue.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                        .shadow(color: Color.blue.opacity(0.3), radius: 12, x: 0, y: 6)
                    
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(.white)
                }
                
                VStack(spacing: 4) {
                    Text("SCAT5")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("Assessment Platform")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 48)
            
            // Sign In Form
            VStack(spacing: 20) {
                VStack(spacing: 16) {
                    // Username Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Username")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        TextField("Enter username", text: $username)
                            .textFieldStyle(LoginTextFieldStyle())
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                    }
                    
                    // Password Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        SecureField("Enter password", text: $password)
                            .textFieldStyle(LoginTextFieldStyle())
                    }
                }
                
                // Sign In Button
                Button(action: loginAction) {
                    Text("Sign In")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(
                                    username.isEmpty || password.isEmpty 
                                        ? Color.gray.opacity(0.3)
                                        : Color.blue
                                )
                        )
                        .scaleEffect(username.isEmpty || password.isEmpty ? 0.98 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: username.isEmpty || password.isEmpty)
                }
                .disabled(username.isEmpty || password.isEmpty)
                .buttonStyle(.plain)
            }
            .frame(maxWidth: 280)
            
            Spacer()
            
            // Create Account Section
            VStack(spacing: 16) {
                Divider()
                    .frame(maxWidth: 280)
                
                Button("Create New Account") {
                    showingCreateAccount = true
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.blue)
                .buttonStyle(.plain)
            }
            .padding(.bottom, 32)
        }
        .padding(.horizontal, 32)
        .frame(width: 400, height: 500)
        .glassBackgroundEffect()
        .sheet(isPresented: $showingCreateAccount) {
            CreateAccountView()
                .environment(authService)
        }
        .alert("Sign In Failed", isPresented: $showingLoginError) {
            Button("OK") {
                password = ""
            }
        } message: {
            Text("Please check your username and password and try again.")
        }
    }
    
    private func loginAction() {
        if !authService.login(username: username, password: password) {
            showingLoginError = true
        }
    }
}

// Clean TextField Style
struct LoginTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.system(size: 16))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
            )
    }
}

#Preview {
    LoginView()
        .environment(AuthService())
}