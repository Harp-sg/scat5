import SwiftUI

@Observable
class AppViewModel {
    var isImmersiveSpaceShown = false
    var currentModule: TestModule?
    var currentSession: TestSession?
    var isTextEntryActive = false
}