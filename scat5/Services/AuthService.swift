import Foundation
import SwiftData

@MainActor
@Observable
class AuthService {
    var currentUser: User?
    var isAuthenticated: Bool { currentUser != nil }
    
    private var modelContext: ModelContext?
    
    // UserDefaults key for storing the current user's username
    private let currentUserKey = "SCAT5_CurrentUser"
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        // Try to restore the previous session when model context is set
        restoreUserSession()
    }
    
    private func restoreUserSession() {
        guard let context = modelContext else { return }
        
        // Check if there's a stored username from previous session
        let storedUsername = UserDefaults.standard.string(forKey: currentUserKey)
        guard let username = storedUsername else { return }
        
        // Try to fetch the user from the database
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate<User> { user in
                user.username == username
            }
        )
        
        do {
            let users = try context.fetch(descriptor)
            if let user = users.first {
                currentUser = user
                print("Restored user session for: \(username)")
            } else {
                // User no longer exists, clear the stored session
                clearStoredSession()
            }
        } catch {
            print("Error restoring user session: \(error)")
            clearStoredSession()
        }
    }
    
    private func storeUserSession(_ username: String) {
        UserDefaults.standard.set(username, forKey: currentUserKey)
    }
    
    private func clearStoredSession() {
        UserDefaults.standard.removeObject(forKey: currentUserKey)
    }
    
    func login(username: String, password: String) -> Bool {
        guard let context = modelContext else { return false }
        
        // Step 1: Fetch the user by username only.
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate<User> { user in
                user.username == username
            }
        )
        
        do {
            let users = try context.fetch(descriptor)
            // Step 2: If a user is found, verify their password.
            if let user = users.first {
                if user.password == password {
                    currentUser = user
                    // Store the session for next app launch
                    storeUserSession(username)
                    return true // Login successful
                }
            }
        } catch {
            print("Login error: \(error)")
        }
        
        // If the user is not found or the password does not match, return false.
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
            // Store the session for next app launch
            storeUserSession(username)
            return true
            
        } catch {
            print("Account creation error: \(error)")
            return false
        }
    }
    
    func logout() {
        currentUser = nil
        // Clear the stored session
        clearStoredSession()
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