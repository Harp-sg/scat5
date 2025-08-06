import SwiftUI

struct LoginView: View {
    @Environment(AuthService.self) private var authService
    @State private var showingCreateAccount = false
    @State private var username = ""
    @State private var password = ""
    @State private var showingLoginError = false
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Left Panel - Branding
                VStack(spacing: 30) {
                    VStack(spacing: 20) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 80, weight: .thin))
                            .foregroundColor(.white)
                        
                        VStack(spacing: 8) {
                            Text("SCAT5")
                                .font(.system(size: 42, weight: .light, design: .default))
                                .foregroundColor(.white)
                            
                            Text("Assessment Platform")
                                .font(.system(size: 18, weight: .regular))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Professional Concussion Assessment")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                        
                        Text("• Evidence-based testing protocols")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                        
                        Text("• Standardized measurement tools")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                        
                        Text("• Secure data management")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: geometry.size.width * 0.4)
                .padding(40)
                .background(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.8), Color.blue.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                
                // Right Panel - Login Form
                VStack(spacing: 0) {
                    VStack(spacing: 30) {
                        VStack(spacing: 8) {
                            Text("Sign In")
                                .font(.system(size: 32, weight: .light))
                                .foregroundColor(.primary)
                            
                            Text("Access your assessment dashboard")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 60)
                        
                        VStack(spacing: 24) {
                            // Username Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Username")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                TextField("Enter username", text: $username)
                                    .textFieldStyle(MedicalTextFieldStyle())
                                    .autocapitalization(.none)
                                    .autocorrectionDisabled()
                            }
                            
                            // Password Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Password")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                SecureField("Enter password", text: $password)
                                    .textFieldStyle(MedicalTextFieldStyle())
                            }
                        }
                        
                        VStack(spacing: 16) {
                            Button(action: loginAction) {
                                HStack {
                                    Text("Sign In")
                                        .font(.system(size: 16, weight: .medium))
                                    
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 14))
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                            .disabled(username.isEmpty || password.isEmpty)
                            .opacity(username.isEmpty || password.isEmpty ? 0.6 : 1.0)
                            
                            Button("Create New Account") {
                                showingCreateAccount = true
                            }
                            .font(.system(size: 14))
                            .foregroundColor(.blue)
                        }
                        
                        Spacer()
                    }
                    .frame(maxWidth: 400)
                    .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity)
                .background(Color(.systemBackground))
            }
        }
        .sheet(isPresented: $showingCreateAccount) {
            CreateAccountView()
                .environment(authService)
        }
        .alert("Authentication Failed", isPresented: $showingLoginError) {
            Button("OK") { 
                username = ""
                password = ""
            }
        } message: {
            Text("Invalid credentials. Please check your username and password.")
        }
    }
    
    private func loginAction() {
        if !authService.login(username: username, password: password) {
            showingLoginError = true
        }
    }
}

struct MedicalTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(.systemBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.systemGray3), lineWidth: 1)
            )
            .font(.system(size: 16))
            .textInputAutocapitalization(.never)
            .submitLabel(.next)
    }
}