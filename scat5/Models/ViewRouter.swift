import SwiftUI

enum AppView: Equatable {
    case dashboard
    case testSelection(SessionType)
}

@Observable
class ViewRouter {
    var currentView: AppView = .dashboard
    
    func navigate(to view: AppView) {
        currentView = view
    }
}