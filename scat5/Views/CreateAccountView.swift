import SwiftUI

struct CreateAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthService.self) private var authService
    @Environment(AppViewModel.self) private var appViewModel
    
    @State private var username = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var dateOfBirth = Date()
    @State private var sport = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    @FocusState private var focusedField: Field?
    
    enum Field: Hashable {
        case username, password, confirmPassword, firstName, lastName, sport
    }
    
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
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                        .focused($focusedField, equals: .username)
                                        .submitLabel(.next)
                                        .onSubmit { focusedField = .password }
                                }
                                
                                FormField(title: "Password", text: $password) {
                                    SecureField("Create a password", text: $password)
                                        .textFieldStyle(MedicalTextFieldStyle())
                                        .focused($focusedField, equals: .password)
                                        .submitLabel(.next)
                                        .onSubmit { focusedField = .confirmPassword }
                                }
                                
                                FormField(title: "Confirm Password", text: $confirmPassword) {
                                    SecureField("Re-enter password", text: $confirmPassword)
                                        .textFieldStyle(MedicalTextFieldStyle())
                                        .focused($focusedField, equals: .confirmPassword)
                                        .submitLabel(.next)
                                        .onSubmit { focusedField = .firstName }
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
                                        .focused($focusedField, equals: .firstName)
                                        .submitLabel(.next)
                                        .onSubmit { focusedField = .lastName }
                                }
                                
                                FormField(title: "Last Name", text: $lastName) {
                                    TextField("Enter last name", text: $lastName)
                                        .textFieldStyle(MedicalTextFieldStyle())
                                        .focused($focusedField, equals: .lastName)
                                        .submitLabel(.next)
                                        .onSubmit { focusedField = .sport }
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
                                        .focused($focusedField, equals: .sport)
                                        .submitLabel(.done)
                                        .onSubmit { createAccount() }
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
        .onAppear {
            focusedField = .username
            appViewModel.isTextEntryActive = true
        }
        .onChange(of: focusedField) { newValue in
            appViewModel.isTextEntryActive = newValue != nil
        }
        .onDisappear {
            appViewModel.isTextEntryActive = false
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