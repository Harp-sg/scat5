import SwiftUI
import SwiftData

struct TestSelectionView: View, CarouselController {
    let testType: SessionType
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var authService
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(ViewRouter.self) private var viewRouter
    @Environment(SpeechControlCoordinator.self) private var speechCoordinator
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    
    @State private var currentSession: TestSession?
    @State private var selectedIndex = 0
    @State private var dragOffset: CGFloat = 0
    
    private let cardWidth: CGFloat = 280
    private let cardHeight: CGFloat = 360
    
    var body: some View {
        VStack(spacing: 20) {
            // Floating header pane
            headerPane
            
            Spacer()
            
            // Main carousel content - centered
            carouselWithControls
            
            Spacer()
            
            // Progress pane at bottom
            if let session = currentSession {
                progressPane(for: session)
            }
            
            // Results button
            if currentSession?.isComplete == true {
                resultsButton
                    .padding(.bottom, 20)
            }
        }
        .padding(.vertical, 20)
        .background(.clear)
        .onAppear {
            print("TestSelectionView appeared - setting up speech control")
            createOrLoadSession()
            speechCoordinator.currentViewContext = .testSelection
            speechCoordinator.carouselController = self
        }
        .onDisappear {
            print("TestSelectionView disappeared - cleaning up speech control")
            speechCoordinator.carouselController = nil
        }
        .onChange(of: selectedIndex) { oldValue, newValue in
            // Debounce rapid changes to prevent multiple updates per frame
            if oldValue != newValue {
                speechCoordinator.isUserInteracting = false
            }
        }
        .simultaneousGesture(
            DragGesture()
                .onChanged { _ in
                    // Mute speech commands during manual drag
                    speechCoordinator.isUserInteracting = true
                }
                .onEnded { _ in
                    // Use a small delay to prevent immediate state changes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        speechCoordinator.isUserInteracting = false
                    }
                }
        )
    }
    
    // MARK: - Speech Control Integration
    func executeCommand(_ command: VoiceCommand) {
        print("TestSelectionView executing command: \(command)")
        
        switch command {
        case .nextItem:
            print("Moving to next item")
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                selectedIndex = min(selectedIndex + 1, TestModule.allCases.count - 1)
            }
        case .previousItem:
            print("Moving to previous item")
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                selectedIndex = max(selectedIndex - 1, 0)
            }
        case .selectItem:
            print("Selecting current item")
            selectCurrentModule()
        case .selectItemByName(let name):
            print("Selecting item by name: \(name)")
            if let index = TestModule.allCases.firstIndex(where: { $0.rawValue == name }) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    selectedIndex = index
                }
                // Auto-select after a brief delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    selectCurrentModule()
                }
            }
        case .goBack, .exitTest, .closeTest:
            // NEW SEXY FEATURE: Handle back/exit commands
            print("Navigating back to dashboard")
            viewRouter.navigate(to: .dashboard)
        default:
            print("Unhandled command in TestSelectionView: \(command)")
            break
        }
    }
    
    private func selectCurrentModule() {
        let module = TestModule.allCases[selectedIndex]
        print("Voice command selected module: \(module.rawValue)")
        appViewModel.currentModule = module
        appViewModel.currentSession = currentSession
        
        // Prevent multiple rapid selections
        guard !appViewModel.isImmersiveSpaceShown else {
            print("⚠️ Immersive space already shown, ignoring selection")
            return
        }
        
        Task {
            await openImmersiveSpace(id: "TestImmersiveSpace")
            await MainActor.run {
                appViewModel.isImmersiveSpaceShown = true
            }
        }
    }

    // MARK: - Header Pane
    
    private var headerPane: some View {
        HStack {
            Button(action: {
                viewRouter.navigate(to: .dashboard)
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                        .font(.title3.weight(.semibold))
                    Text("Dashboard")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundColor(.primary)
            }
            .buttonStyle(.borderedProminent)
            .tint(.clear)
            
            Spacer()
            
            VStack(spacing: 4) {
                Image(systemName: testType == .concussion ? "brain.head.profile" : "figure.walk")
                    .font(.title2.weight(.medium))
                    .foregroundStyle(LinearGradient(
                        colors: [testType == .concussion ? Color.red : Color.blue, testType == .concussion ? Color.orange : Color.teal],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                
                Text(testType.rawValue)
                    .font(.title3.weight(.bold))
                    .foregroundColor(.primary)
                
                Text("Select a module to begin")
                    .font(.caption2.weight(.medium))
                    .foregroundColor(.secondary)
                    .opacity(0.8)
            }
            
            Spacer()
            
            // Balance with invisible button
            Button(action: {}) {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                        .font(.title3.weight(.semibold))
                    Text("Dashboard")
                        .font(.subheadline.weight(.semibold))
                }
            }
            .opacity(0)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .glassBackgroundEffect()
        .padding(.horizontal, 20)
    }
    
    // MARK: - Progress Pane
    
    private func progressPane(for session: TestSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Overall Progress")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(Int(session.progressPercentage * 100))%")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(LinearGradient(
                        colors: [testType == .concussion ? Color.red : Color.blue, testType == .concussion ? Color.orange : Color.teal],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
            }
            
            ProgressView(value: session.progressPercentage)
                .progressViewStyle(LinearProgressViewStyle(tint: testType == .concussion ? Color.red : Color.blue))
                .scaleEffect(x: 1, y: 3, anchor: .center)
        }
        .padding(20)
        .glassBackgroundEffect()
        .padding(.horizontal, 20)
    }
    
    // MARK: - Carousel with Controls
    
    private var carouselWithControls: some View {
        HStack(spacing: 30) {
            // Left arrow button
            Button(action: {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    selectedIndex = max(selectedIndex - 1, 0)
                }
            }) {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.white, Color.white.opacity(0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                    )
            }
            .buttonStyle(.plain)
            .opacity(selectedIndex == 0 ? 0.4 : 1.0)
            .disabled(selectedIndex == 0)
            .scaleEffect(selectedIndex == 0 ? 0.9 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: selectedIndex)
            
            // Carousel
            carousel
            
            // Right arrow button
            Button(action: {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    selectedIndex = min(selectedIndex + 1, TestModule.allCases.count - 1)
                }
            }) {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.white, Color.white.opacity(0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                    )
            }
            .buttonStyle(.plain)
            .opacity(selectedIndex == TestModule.allCases.count - 1 ? 0.4 : 1.0)
            .disabled(selectedIndex == TestModule.allCases.count - 1)
            .scaleEffect(selectedIndex == TestModule.allCases.count - 1 ? 0.9 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: selectedIndex)
        }
    }
    
    private var carousel: some View {
        let modules = TestModule.allCases
        
        return ZStack {
            ForEach(Array(modules.enumerated()), id: \.element) { index, module in
                Button(action: {
                    if selectedIndex == index {
                        print("Module card tapped: \(module.rawValue)")
                        
                        // Prevent multiple rapid taps
                        guard !appViewModel.isImmersiveSpaceShown else {
                            print("⚠️ Immersive space already shown, ignoring tap")
                            return
                        }
                        
                        appViewModel.currentModule = module
                        appViewModel.currentSession = currentSession
                        Task {
                            await openImmersiveSpace(id: "TestImmersiveSpace")
                            await MainActor.run {
                                appViewModel.isImmersiveSpaceShown = true
                            }
                        }
                    } else {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            selectedIndex = index
                        }
                    }
                }) {
                    ModuleCard(
                        title: module.rawValue,
                        icon: module.icon,
                        isCompleted: currentSession?.completedModules.contains(module.rawValue) ?? false,
                        isConcussion: testType == .concussion,
                        isSelected: selectedIndex == index,
                        cardWidth: cardWidth,
                        cardHeight: cardHeight
                    )
                }
                .buttonStyle(.plain)
                .frame(width: cardWidth, height: cardHeight)
                .scaleEffect(scale(for: index))
                .offset(x: xOffset(for: index), y: yOffset(for: index))
                .rotation3DEffect(
                    .degrees(rotation(for: index)),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.8
                )
                .zIndex(zIndex(for: index))
                .opacity(opacity(for: index))
            }
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation.width
                }
                .onEnded { value in
                    let threshold: CGFloat = 100
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        if value.translation.width < -threshold {
                            selectedIndex = min(selectedIndex + 1, modules.count - 1)
                        } else if value.translation.width > threshold {
                            selectedIndex = max(selectedIndex - 1, 0)
                        }
                        dragOffset = 0
                    }
                }
        )
        .frame(width: cardWidth + 80, height: cardHeight + 30)
    }
    
    // MARK: - Carousel Calculations
    
    private func scale(for index: Int) -> CGFloat {
        let diff = abs(selectedIndex - index)
        if selectedIndex == index {
            return 1.0
        } else if diff == 1 {
            return 0.85
        } else {
            return max(0.7 - (CGFloat(diff - 2) * 0.1), 0.5)
        }
    }
    
    private func xOffset(for index: Int) -> CGFloat {
        let diff = CGFloat(index - selectedIndex)
        let baseOffset = diff * 160
        return baseOffset + (dragOffset * 0.2)
    }
    
    private func yOffset(for index: Int) -> CGFloat {
        let diff = abs(selectedIndex - index)
        if selectedIndex == index {
            return 0
        } else {
            return CGFloat(diff) * 10
        }
    }
    
    private func rotation(for index: Int) -> Double {
        let diff = Double(index - selectedIndex)
        return diff * 25
    }
    
    private func zIndex(for index: Int) -> Double {
        return Double(TestModule.allCases.count - abs(selectedIndex - index))
    }
    
    private func opacity(for index: Int) -> Double {
        let diff = abs(selectedIndex - index)
        if selectedIndex == index {
            return 1.0
        } else {
            return max(0.6 - (Double(diff - 1) * 0.2), 0.2)
        }
    }
    
    private var resultsButton: some View {
        Button("View Results") {
            // Navigate to results view
        }
        .font(.title3.weight(.semibold))
        .foregroundColor(.white)
        .padding(.horizontal, 30)
        .padding(.vertical, 16)
        .background(
            LinearGradient(
                colors: [testType == .concussion ? Color.red : Color.blue, testType == .concussion ? Color.orange : Color.teal],
                startPoint: .leading,
                endPoint: .trailing
            ),
            in: RoundedRectangle(cornerRadius: 16)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
    
    private func createOrLoadSession() {
        guard let user = authService.currentUser else { return }
        
        if let existingSession = user.testSessions.first(where: { $0.sessionType == testType && !$0.isComplete }) {
            currentSession = existingSession
        } else {
            let newSession = TestSession(date: .now, sessionType: testType)
            user.testSessions.append(newSession)
            currentSession = newSession
            
            do {
                try modelContext.save()
            } catch {
                print("Failed to create session: \(error)")
            }
        }
    }
}

// MARK: - Module Card

struct ModuleCard: View {
    let title: String
    let icon: String
    let isCompleted: Bool
    let isConcussion: Bool
    let isSelected: Bool
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    
    var body: some View {
        VStack(spacing: 25) {
            // Icon circle with volumetric effects
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: isCompleted ? [Color.green.opacity(0.8), Color.mint.opacity(0.6)] : [
                                isConcussion ? Color.red.opacity(0.8) : Color.blue.opacity(0.8),
                                isConcussion ? Color.orange.opacity(0.6) : Color.teal.opacity(0.6)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: Color.black.opacity(0.2), radius: 8, x: 4, y: 4)
                    .shadow(color: Color.white.opacity(0.3), radius: 6, x: -2, y: -2)
                
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            
            // Title
            Text(title)
                .font(.title3.weight(.bold))
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
                .frame(maxWidth: 240)
            
            // Subtitle with dynamic text
            Text(isSelected ? "Tap to begin" : "Tap to select")
                .font(.caption.weight(.medium))
                .foregroundColor(.secondary)
                .opacity(0.9)
        }
        .frame(width: cardWidth, height: cardHeight)
        .background(
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.15), radius: 15, x: 8, y: 8)
                .shadow(color: Color.white.opacity(0.1), radius: 12, x: -6, y: -6)
                .overlay(
                    RoundedRectangle(cornerRadius: 25, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: isSelected ? [
                                    isConcussion ? Color.red.opacity(0.6) : Color.blue.opacity(0.6),
                                    isConcussion ? Color.orange.opacity(0.4) : Color.teal.opacity(0.4)
                                ] : [Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSelected)
    }
}

// MARK: - Previews

#Preview("Concussion", traits: .fixedLayout(width: 1200, height: 800)) {
    let container = try! ModelContainer(
        for: User.self, TestSession.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    
    return TestSelectionView(testType: .concussion)
        .environment(AuthService())
        .environment(AppViewModel())
        .environment(ViewRouter())
        .modelContainer(container)
}

#Preview("Baseline", traits: .fixedLayout(width: 1200, height: 800)) {
    let container = try! ModelContainer(
        for: User.self, TestSession.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    
    return TestSelectionView(testType: .baseline)
        .environment(AuthService())
        .environment(AppViewModel())
        .environment(ViewRouter())
        .modelContainer(container)
}