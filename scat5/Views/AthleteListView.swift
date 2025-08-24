import SwiftUI
import SwiftData

struct AthleteListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Athlete.name) private var athletes: [Athlete]
    @State private var showingAddAthlete = false

    var body: some View {
        NavigationView {
            List {
                ForEach(athletes) { athlete in
                    NavigationLink(destination: AthleteProfileView(athlete: athlete)) {
                        Text(athlete.name)
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .navigationTitle("Athletes")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddAthlete.toggle()
                    } label: {
                        Label("Add Athlete", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddAthlete) {
                AddAthleteView()
            }
            
            // A placeholder for the detail view in regular width contexts
            Text("Select an athlete to see their details.")
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(athletes[index])
            }
        }
    }
}

// A dedicated view for adding a new athlete, presented as a sheet.
struct AddAthleteView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var sport: String = ""
    @State private var dateOfBirth: Date = .now
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("New Athlete Details")) {
                    TextField("Full Name", text: $name)
                    TextField("Sport", text: $sport)
                    DatePicker("Date of Birth", selection: $dateOfBirth, displayedComponents: .date)
                }
            }
            .navigationTitle("Add New Athlete")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveAthlete()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
    
    private func saveAthlete() {
        let newAthlete = Athlete(name: name, dateOfBirth: dateOfBirth, sport: sport)
        modelContext.insert(newAthlete)
    }
}

#Preview("Athlete List") {
    AthleteListView()
        .modelContainer(for: [Athlete.self])
}

#Preview("Add Athlete") {
    AddAthleteView()
        .modelContainer(for: [Athlete.self])
}