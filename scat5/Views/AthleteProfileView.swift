import SwiftUI
import SwiftData

struct AthleteProfileView: View {
    @Bindable var athlete: Athlete

    var body: some View {
        Form {
            Section("Athlete Details") {
                TextField("Name", text: $athlete.name)
                DatePicker("Date of Birth", selection: $athlete.dateOfBirth, displayedComponents: .date)
                TextField("Sport", text: $athlete.sport)
            }
        }
        .navigationTitle("Athlete Profile")
    }
}