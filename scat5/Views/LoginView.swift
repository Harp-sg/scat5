import SwiftUI

struct LoginView: View {
    @Environment(AuthService.self) private var authService
    @State private var showingCreateAccount = false
    @State private var username = ""
    @State private var password = ""
    @State private var showingLoginError = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Branding Header
            VStack(spacing: 12) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 60, weight: .light))
                    .foregroundColor(.primary)
                
                Text("SCAT5 Assessment Platform")
                    .font(.title)
                
                Text("Please Sign In")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 20)
            
            // Form Fields
            VStack(spacing: 20) {
                TextField("Username", text: $username)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .frame(maxWidth: 300)
            
            // Action Buttons
            VStack(spacing: 12) {
                Button(action: loginAction) {
                    Text("Sign In")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(username.isEmpty || password.isEmpty)
                .opacity(username.isEmpty || password.isEmpty ? 0.6 : 1.0)
                
                Button("Create New Account") {
                    showingCreateAccount = true
                }
                .font(.headline)
            }
            .frame(maxWidth: 300)
        }
        .padding(40)
        .glassBackgroundEffect()
        .sheet(isPresented: $showingCreateAccount) {
            CreateAccountView()
                .environment(authService)
        }
        .alert("Authentication Failed", isPresented: $showingLoginError) {
            Button("OK") {
                password = ""
            }
        } message: {
            Text("Invalid credentials. Please check your username and password and try again.")
        }
    }
    
    private func loginAction() {
        if !authService.login(username: username, password: password) {
            showingLoginError = true
        }
    }
}

#Preview {
    LoginView()
        .environment(AuthService())
}