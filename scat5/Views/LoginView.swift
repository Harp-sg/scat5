import SwiftUI

struct LoginView: View {
    @Environment(AuthService.self) private var authService
    @Environment(ViewRouter.self) private var viewRouter
    @Environment(AppViewModel.self) private var appViewModel
    @State private var showingCreateAccount = false
    @State private var username = ""
    @State private var password = ""
    @State private var showingLoginError = false
    @FocusState private var focusedField: Field?
    
    enum Field: Hashable {
        case username
        case password
    }
    
    // Preview-only initializer remains
    init(previewUsername: String = "", previewPassword: String = "", showingError: Bool = false, showingCreate: Bool = false) {
        _username = State(initialValue: previewUsername)
        _password = State(initialValue: previewPassword)
        _showingLoginError = State(initialValue: showingError)
        _showingCreateAccount = State(initialValue: showingCreate)
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Left side – Standard Login
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 28) {
                    // App Icon & Title
                    VStack(spacing: 18) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.blue, Color.blue.opacity(0.85)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 88, height: 88)
                                .shadow(color: Color.blue.opacity(0.25), radius: 18, x: 0, y: 10)
                            
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 36, weight: .medium))
                                .foregroundColor(.white)
                        }
                        
                        VStack(spacing: 6) {
                            Text("SCAT5")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            Text("Assessment Platform")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Sign In Form
                    VStack(spacing: 22) {
                        VStack(spacing: 18) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Username")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                TextField("Enter username", text: $username)
                                    .textFieldStyle(LoginTextFieldStyle())
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .focused($focusedField, equals: .username)
                                    .submitLabel(.next)
                                    .onSubmit {
                                        focusedField = .password
                                    }
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Password")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                SecureField("Enter password", text: $password)
                                    .textFieldStyle(LoginTextFieldStyle())
                                    .focused($focusedField, equals: .password)
                                    .submitLabel(.go)
                                    .onSubmit {
                                        loginAction()
                                    }
                            }
                        }
                        
                        Button(action: loginAction) {
                            HStack {
                                Text("Sign In")
                                    .font(.system(size: 17, weight: .semibold))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(username.isEmpty || password.isEmpty ? Color.gray.opacity(0.3) : Color.blue)
                            )
                            .scaleEffect(username.isEmpty || password.isEmpty ? 0.98 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: username.isEmpty || password.isEmpty)
                        }
                        .disabled(username.isEmpty || password.isEmpty)
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: 320)
                }
                
                Spacer()
                
                // Create Account Link
                VStack(spacing: 16) {
                    Divider()
                        .frame(maxWidth: 320)
                    
                    Button("Create New Account") {
                        showingCreateAccount = true
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.blue)
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 36)
            }
            .frame(maxWidth: .infinity)
            .background(.regularMaterial)
            
            // Right side – Emergency Mode
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 40) {
                    // Emergency Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.red, Color.red.opacity(0.82)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)
                            .shadow(color: Color.red.opacity(0.35), radius: 20, x: 0, y: 10)
                        
                    Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 50, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(spacing: 14) {
                        Text("Emergency Mode")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Bypass login for immediate concussion assessment")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.horizontal, 12)
                    }
                    
                    Button(action: startEmergency) {
                        Text("Start Emergency Assessment")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.red)
                            .frame(maxWidth: 320)
                            .frame(height: 60)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(.white)
                                    .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 6)
                            )
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                // Info chips
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill").foregroundColor(.white.opacity(0.85))
                        Text("For immediate assessment without account setup")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "clock.fill").foregroundColor(.white.opacity(0.85))
                        Text("Complete assessment in 15–20 minutes")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.85))
                    }
                }
                .padding(.bottom, 36)
            }
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [Color.red, Color.red.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        .padding(.horizontal, 0)
        .frame(width: 900, height: 540)
        .glassBackgroundEffect()
        .sheet(isPresented: $showingCreateAccount) {
            CreateAccountView()
                .environment(authService)
                .environment(appViewModel)
        }
        .alert("Sign In Failed", isPresented: $showingLoginError) {
            Button("OK") {
                password = ""
            }
        } message: {
            Text("Please check your username and password and try again.")
        }
        .onAppear {
            focusedField = .username
        }
        .onChange(of: focusedField) { newValue in
            appViewModel.isTextEntryActive = newValue != nil
        }
        .onDisappear {
            appViewModel.isTextEntryActive = false
        }
    }
    
    private func loginAction() {
        if !authService.login(username: username, password: password) {
            showingLoginError = true
        } else {
            viewRouter.navigate(to: .dashboard)
        }
    }
    
    private func startEmergency() {
        authService.emergencyLogin()
        viewRouter.navigate(to: .dashboard)
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

#Preview("Default") {
    LoginView()
        .environment(AuthService())
        .environment(ViewRouter())
}

#Preview("Filled Fields") {
    LoginView(previewUsername: "demo", previewPassword: "password")
        .environment(AuthService())
        .environment(ViewRouter())
}

#Preview("Error Alert") {
    LoginView(previewUsername: "demo", previewPassword: "wrong", showingError: true)
        .environment(AuthService())
        .environment(ViewRouter())
}

#Preview("Create Account Sheet") {
    LoginView(showingCreate: true)
        .environment(AuthService())
        .environment(ViewRouter())
}

#Preview("Dark Mode") {
    LoginView()
        .environment(AuthService())
        .environment(ViewRouter())
        .preferredColorScheme(.dark)
}