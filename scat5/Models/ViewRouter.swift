import SwiftUI

enum AppView: Equatable {
    case login
    case createAccount
    case dashboard
    case testSelection(SessionType)
    case interactiveDiagnosis
}

@Observable
class ViewRouter {
    var currentView: AppView = .dashboard
    
    func navigate(to view: AppView) {
        currentView = view
    }
}