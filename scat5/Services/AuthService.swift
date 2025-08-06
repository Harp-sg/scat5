import Foundation
import SwiftData

@MainActor
@Observable
class AuthService {
    var currentUser: User?
    var isAuthenticated: Bool { currentUser != nil }
    
    private var modelContext: ModelContext?
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    func login(username: String, password: String) -> Bool {
        guard let context = modelContext else { return false }
        
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate<User> { user in
                user.username == username && user.password == password
            }
        )
        
        do {
            let users = try context.fetch(descriptor)
            if let user = users.first {
                currentUser = user
                return true
            }
        } catch {
            print("Login error: \(error)")
        }
        
        return false
    }
    
    func createAccount(username: String, password: String, firstName: String, lastName: String, dateOfBirth: Date, sport: String) -> Bool {
        guard let context = modelContext else { return false }
        
        // Check if username already exists
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate<User> { user in
                user.username == username
            }
        )
        
        do {
            let existingUsers = try context.fetch(descriptor)
            if !existingUsers.isEmpty {
                return false // Username already exists
            }
            
            let newUser = User(
                username: username,
                password: password,
                firstName: firstName,
                lastName: lastName,
                dateOfBirth: dateOfBirth,
                sport: sport
            )
            
            context.insert(newUser)
            try context.save()
            currentUser = newUser
            return true
            
        } catch {
            print("Account creation error: \(error)")
            return false
        }
    }
    
    func logout() {
        currentUser = nil
    }
    
    func updateUserBiodata(position: String, yearsExperience: Int, height: Double, weight: Double, dominantHand: DominantHand) {
        guard let user = currentUser, let context = modelContext else { return }
        
        user.position = position
        user.yearsExperience = yearsExperience
        user.height = height
        user.weight = weight
        user.dominantHand = dominantHand
        
        do {
            try context.save()
        } catch {
            print("Update biodata error: \(error)")
        }
    }
}