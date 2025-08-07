import SwiftUI

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