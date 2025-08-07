import SwiftUI

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthService.self) private var authService
    @State private var showingBiodata = false
    @State private var showingBaselineSetup = false
    
    var body: some View {
        NavigationView {
            Form {
                if let user = authService.currentUser {
                    Section("Profile Information") {
                        HStack {
                            Text("Name")
                            Spacer()
                            Text(user.fullName)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Username")
                            Spacer()
                            Text(user.username)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Sport")
                            Spacer()
                            Text(user.sport)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Section("Assessment") {
                        Button {
                            showingBaselineSetup = true
                        } label: {
                            HStack {
                                Image(systemName: user.hasBaseline ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(user.hasBaseline ? .green : .orange)
                                Text("Set Baseline")
                                Spacer()
                            }
                        }
                        
                        Button {
                            showingBiodata = true
                        } label: {
                            HStack {
                                Image(systemName: "person.text.rectangle")
                                Text("Update Biodata")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        NavigationLink(destination: TestHistoryView()) {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                Text("Test History")
                            }
                        }
                    }
                    
                    Section {
                        Button("Logout") {
                            authService.logout()
                            dismiss()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingBiodata) {
                BiodataView()
                    .environment(authService)
            }
            .sheet(isPresented: $showingBaselineSetup) {
                BaselineSetupView()
                    .environment(authService)
            }
        }
    }
}

#Preview {
    ProfileView()
        .environment(AuthService())
}