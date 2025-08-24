import SwiftUI

struct BiodataView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthService.self) private var authService
    
    @State private var position = ""
    @State private var yearsExperience = 0
    @State private var height = 0.0
    @State private var weight = 0.0
    @State private var dominantHand = DominantHand.right
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .font(.system(size: 16))
                .foregroundColor(.blue)
                
                Spacer()
                
                Text("Update Biodata")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("Save") {
                    saveBiodata()
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.blue)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(Color(.systemBackground))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color(.systemGray4)),
                alignment: .bottom
            )
            
            ScrollView {
                VStack(spacing: 32) {
                    // Athletic Information
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Athletic Information")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.primary)
                        
                        VStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Position/Role")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                TextField("Enter position or role", text: $position)
                                    .textFieldStyle(MedicalTextFieldStyle())
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Years of Experience")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                HStack {
                                    Button {
                                        if yearsExperience > 0 {
                                            yearsExperience -= 1
                                        }
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.blue)
                                    }
                                    
                                    Text("\(yearsExperience) years")
                                        .font(.system(size: 16, weight: .medium))
                                        .frame(minWidth: 80)
                                    
                                    Button {
                                        if yearsExperience < 50 {
                                            yearsExperience += 1
                                        }
                                    } label: {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.blue)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(.systemGray4), lineWidth: 1)
                                )
                            }
                        }
                    }
                    
                    // Physical Measurements
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Physical Measurements")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.primary)
                        
                        VStack(spacing: 16) {
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Height (cm)")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.secondary)
                                    
                                    TextField("0", value: $height, format: .number)
                                        .textFieldStyle(MedicalTextFieldStyle())
                                        .keyboardType(.decimalPad)
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Weight (kg)")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.secondary)
                                    
                                    TextField("0", value: $weight, format: .number)
                                        .textFieldStyle(MedicalTextFieldStyle())
                                        .keyboardType(.decimalPad)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Dominant Hand")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                Picker("Dominant Hand", selection: $dominantHand) {
                                    ForEach(DominantHand.allCases, id: \.self) { hand in
                                        Text(hand.rawValue).tag(hand)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
            }
        }
        .frame(maxWidth: 500)
        .background(Color(.systemGroupedBackground))
        .onAppear {
            loadCurrentData()
        }
    }
    
    private func saveBiodata() {
        authService.updateUserBiodata(
            position: position,
            yearsExperience: yearsExperience,
            height: height,
            weight: weight,
            dominantHand: dominantHand
        )
        dismiss()
    }
    
    private func loadCurrentData() {
        guard let user = authService.currentUser else { return }
        position = user.position
        yearsExperience = user.yearsExperience
        height = user.height
        weight = user.weight
        dominantHand = user.dominantHand
    }
}

#Preview {
    BiodataView()
        .environment(AuthService())
}