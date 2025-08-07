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

#Preview {
    let container = try! ModelContainer(for: Athlete.self)
    let sampleAthlete = Athlete(name: "John Doe", dateOfBirth: Date(), sport: "Football")
    
    NavigationStack {
        AthleteProfileView(athlete: sampleAthlete)
    }
    .modelContainer(container)
}