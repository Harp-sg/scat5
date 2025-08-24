import SwiftUI

struct CreateAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthService.self) private var authService
    
    @State private var username = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var dateOfBirth = Date()
    @State private var sport = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Text("Create Account")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button("Create") {
                        createAccount()
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isFormValid ? .blue : .gray)
                    .disabled(!isFormValid)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .background(Color(.systemGray6))
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color(.systemGray4)),
                    alignment: .bottom
                )
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Account Information Section
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Account Information")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.primary)
                            
                            VStack(spacing: 16) {
                                FormField(title: "Username", text: $username) {
                                    TextField("Choose a username", text: $username)
                                        .textFieldStyle(MedicalTextFieldStyle())
                                        .autocapitalization(.none)
                                        .autocorrectionDisabled()
                                        .onTapGesture {
                                            // Ensure field gets focus in visionOS
                                        }
                                }
                                
                                FormField(title: "Password", text: $password) {
                                    SecureField("Create a password", text: $password)
                                        .textFieldStyle(MedicalTextFieldStyle())
                                        .onTapGesture {
                                            // Ensure field gets focus in visionOS
                                        }
                                }
                                
                                FormField(title: "Confirm Password", text: $confirmPassword) {
                                    SecureField("Re-enter password", text: $confirmPassword)
                                        .textFieldStyle(MedicalTextFieldStyle())
                                        .onTapGesture {
                                            // Ensure field gets focus in visionOS
                                        }
                                }
                                
                                if !password.isEmpty && !confirmPassword.isEmpty && password != confirmPassword {
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.orange)
                                        Text("Passwords do not match")
                                            .font(.system(size: 14))
                                            .foregroundColor(.orange)
                                        Spacer()
                                    }
                                }
                            }
                        }
                        
                        // Personal Information Section
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Personal Information")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.primary)
                            
                            VStack(spacing: 16) {
                                FormField(title: "First Name", text: $firstName) {
                                    TextField("Enter first name", text: $firstName)
                                        .textFieldStyle(MedicalTextFieldStyle())
                                        .onTapGesture {
                                            // Ensure field gets focus in visionOS
                                        }
                                }
                                
                                FormField(title: "Last Name", text: $lastName) {
                                    TextField("Enter last name", text: $lastName)
                                        .textFieldStyle(MedicalTextFieldStyle())
                                        .onTapGesture {
                                            // Ensure field gets focus in visionOS
                                        }
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Date of Birth")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.secondary)
                                    
                                    DatePicker("", selection: $dateOfBirth, displayedComponents: .date)
                                        .datePickerStyle(.compact)
                                        .labelsHidden()
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 14)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color(.systemGray4), lineWidth: 1)
                                        )
                                }
                                
                                FormField(title: "Primary Sport", text: $sport) {
                                    TextField("Enter primary sport", text: $sport)
                                        .textFieldStyle(MedicalTextFieldStyle())
                                        .onTapGesture {
                                            // Ensure field gets focus in visionOS
                                        }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 32)
                }
                .frame(maxWidth: 600)
            }
        }
        .alert("Account Creation Failed", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var isFormValid: Bool {
        !username.isEmpty && 
        !password.isEmpty && 
        password == confirmPassword && 
        !firstName.isEmpty && 
        !lastName.isEmpty && 
        !sport.isEmpty &&
        password.count >= 6
    }
    
    private func createAccount() {
        if password != confirmPassword {
            errorMessage = "Passwords do not match."
            showingError = true
            return
        }
        
        if password.count < 6 {
            errorMessage = "Password must be at least 6 characters long."
            showingError = true
            return
        }
        
        if authService.createAccount(
            username: username,
            password: password,
            firstName: firstName,
            lastName: lastName,
            dateOfBirth: dateOfBirth,
            sport: sport
        ) {
            dismiss()
        } else {
            errorMessage = "Username already exists. Please choose a different username."
            showingError = true
        }
    }
}

struct FormField<Content: View>: View {
    let title: String
    let text: Binding<String>
    let content: Content
    
    init(title: String, text: Binding<String>, @ViewBuilder content: () -> Content) {
        self.title = title
        self.text = text
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            
            content
        }
    }
}

#Preview {
    CreateAccountView()
        .environment(AuthService())
}