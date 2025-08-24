import SwiftUI
import SwiftData

struct InteractiveDiagnosisView: View, CarouselController {
    @Environment(ViewRouter.self) private var viewRouter
    @Environment(SpeechControlCoordinator.self) private var speechCoordinator
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.openWindow) private var openWindow
    @State private var selectedIndex = 0
    @State private var dragOffset: CGFloat = 0
    @State private var isImmersiveActive = false
    
    private let diagnosisItems = [
        DiagnosisItem(title: "Reaction Time\nAnalyzer", icon: "brain.head.profile", description: "Done through catching objects in the sky"),
        DiagnosisItem(title: "Falling Ball\nCatch", icon: "basketball.fill", description: "Catch balls falling from above - athletic test"),
        DiagnosisItem(title: "Walk-in-Place\nBalance", icon: "figure.stand.line.dotted.figure.stand", description: "March in place while staying on virtual plank"),
        DiagnosisItem(title: "Room-Scale\nBalance Walk", icon: "figure.walk", description: "Walk forward in your space on virtual plank"),
        DiagnosisItem(title: "Smooth Pursuit\nTest", icon: "eye.fill", description: "Track eye movement and visual processing speed"),
        DiagnosisItem(title: "Saccades\nTest", icon: "eye.trianglebadge.exclamationmark", description: "Measure rapid eye movement speed and accuracy"),
        DiagnosisItem(title: "Moving Room\n(Optic Flow)", icon: "viewfinder.circle", description: "Induce optic flow and measure postural sway"),
        DiagnosisItem(title: "Balance\nDiagnosis", icon: "figure.walk.motion", description: "Predict balance issues by walking (in place)"),
    ]
    
    private let cardWidth: CGFloat = 280
    private let cardHeight: CGFloat = 360
    
    var body: some View {
        VStack(spacing: 20) {
            // Header pane
            headerPane
            
            Spacer()
            
            // Main carousel content - centered
            carouselWithControls
            
            Spacer()
            
            // Info pane at bottom
            infoPane
        }
        .padding(.vertical, 20)
        .background(.clear)
        .onAppear {
            print("InteractiveDiagnosisView appeared - setting up speech control")
            speechCoordinator.currentViewContext = .interactiveDiagnosis
            speechCoordinator.carouselController = self
        }
        .onDisappear {
            print("InteractiveDiagnosisView disappeared - cleaning up speech control")
            speechCoordinator.carouselController = nil
        }
        .simultaneousGesture(
            DragGesture().onChanged { _ in
                // Mute speech commands during manual drag
                speechCoordinator.isUserInteracting = true
            }.onEnded { _ in
                speechCoordinator.isUserInteracting = false
            }
        )
    }
    
    // MARK: - Speech Control Integration
    func executeCommand(_ command: VoiceCommand) {
        print("InteractiveDiagnosisView executing command: \(command)")
        
        switch command {
        case .nextItem:
            print("Moving to next diagnosis item")
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                selectedIndex = min(selectedIndex + 1, diagnosisItems.count - 1)
            }
        case .previousItem:
            print("Moving to previous diagnosis item")
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                selectedIndex = max(selectedIndex - 1, 0)
            }
        case .selectItem:
            print("Selecting current diagnosis item")
            selectCurrentItem()
        case .selectItemByName(let name):
            print("Selecting diagnosis item by name: \(name)")
            if let index = diagnosisItems.firstIndex(where: { 
                $0.title.lowercased().contains(name.lowercased()) ||
                $0.title.replacingOccurrences(of: "\n", with: " ").lowercased().contains(name.lowercased())
            }) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    selectedIndex = index
                }
                // Auto-select after a brief delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    selectCurrentItem()
                }
            }
        default:
            print("Unhandled command in InteractiveDiagnosisView: \(command)")
            break
        }
    }
    
    private func selectCurrentItem() {
        let item = diagnosisItems[selectedIndex]
        print("Voice command selected diagnosis: \(item.title)")
        
        // Navigate to the appropriate immersive view based on the selected item
        Task { @MainActor in            
            switch selectedIndex {
            case 0: // Reaction Time Analyzer
                await viewRouter.navigateToImmersive(
                    .aiSymptomAnalyzer, 
                    openImmersiveSpace: { id in try await openImmersiveSpace(id: id) }, 
                    dismissImmersiveSpace: { await dismissImmersiveSpace() },
                    dismissMainWindow: { dismissWindow(id: "MainWindow") },
                    openMainWindow: { openWindow(id: "MainWindow") }
                )
            case 1: // Falling Ball Catch
                await viewRouter.navigateToImmersive(
                    .fallingBallCatch, 
                    openImmersiveSpace: { id in try await openImmersiveSpace(id: id) }, 
                    dismissImmersiveSpace: { await dismissImmersiveSpace() },
                    dismissMainWindow: { dismissWindow(id: "MainWindow") },
                    openMainWindow: { openWindow(id: "MainWindow") }
                )
            case 2: // Walk-in-Place Balance
                await viewRouter.navigateToImmersive(
                    .balanceStationary, 
                    openImmersiveSpace: { id in try await openImmersiveSpace(id: id) }, 
                    dismissImmersiveSpace: { await dismissImmersiveSpace() },
                    dismissMainWindow: { dismissWindow(id: "MainWindow") },
                    openMainWindow: { openWindow(id: "MainWindow") }
                )
            case 3: // Room-Scale Balance Walk
                await viewRouter.navigateToImmersive(
                    .balanceRoomScale, 
                    openImmersiveSpace: { id in try await openImmersiveSpace(id: id) }, 
                    dismissImmersiveSpace: { await dismissImmersiveSpace() },
                    dismissMainWindow: { dismissWindow(id: "MainWindow") },
                    openMainWindow: { openWindow(id: "MainWindow") }
                )
            case 4: // Smooth Pursuit Test
                await viewRouter.navigateToImmersive(
                    .smoothPursuit, 
                    openImmersiveSpace: { id in try await openImmersiveSpace(id: id) }, 
                    dismissImmersiveSpace: { await dismissImmersiveSpace() },
                    dismissMainWindow: { dismissWindow(id: "MainWindow") },
                    openMainWindow: { openWindow(id: "MainWindow") }
                )
            case 5: // Saccades Test
                await viewRouter.navigateToImmersive(
                    .saccadesTest, 
                    openImmersiveSpace: { id in try await openImmersiveSpace(id: id) }, 
                    dismissImmersiveSpace: { await dismissImmersiveSpace() },
                    dismissMainWindow: { dismissWindow(id: "MainWindow") },
                    openMainWindow: { openWindow(id: "MainWindow") }
                )
            case 6: // Moving Room (Optic Flow)
                await viewRouter.navigateToImmersive(
                    .movingRoomTest,
                    openImmersiveSpace: { id in try await openImmersiveSpace(id: id) },
                    dismissImmersiveSpace: { await dismissImmersiveSpace() },
                    dismissMainWindow: { dismissWindow(id: "MainWindow") },
                    openMainWindow: { openWindow(id: "MainWindow") }
                )
            case 7: // Balance Prediction (original)
                await viewRouter.navigateToImmersive(
                    .balancePrediction, 
                    openImmersiveSpace: { id in try await openImmersiveSpace(id: id) }, 
                    dismissImmersiveSpace: { await dismissImmersiveSpace() },
                    dismissMainWindow: { dismissWindow(id: "MainWindow") },
                    openMainWindow: { openWindow(id: "MainWindow") }
                )
            default:
                print("Unknown diagnosis item selected")
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
                Image(systemName: "wand.and.rays")
                    .font(.title2.weight(.medium))
                    .foregroundStyle(LinearGradient(
                        colors: [Color.gray.opacity(0.8), Color.gray.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                
                Text("Interactive Diagnosis")
                    .font(.title3.weight(.bold))
                    .foregroundColor(.primary)
                
                Text("Advanced AI-powered assessment tools")
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
    
    // MARK: - Info Pane
    
    private var infoPane: some View {
        VStack(alignment: .center, spacing: 12) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
                
                Text("Coming Soon")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("Q2 2024")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(LinearGradient(
                        colors: [Color.gray.opacity(0.8), Color.gray.opacity(0.6)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
            }
            
            Text("These advanced diagnostic tools are currently in development and will be available soon.")
                .font(.caption.weight(.medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
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
                    selectedIndex = min(selectedIndex + 1, diagnosisItems.count - 1)
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
            .opacity(selectedIndex == diagnosisItems.count - 1 ? 0.4 : 1.0)
            .disabled(selectedIndex == diagnosisItems.count - 1)
            .scaleEffect(selectedIndex == diagnosisItems.count - 1 ? 0.9 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: selectedIndex)
        }
    }
    
    private var carousel: some View {
        ZStack {
            ForEach(Array(diagnosisItems.enumerated()), id: \.element.id) { index, item in
                Button(action: {
                    handleCarouselButtonTap(index: index, item: item)
                }) {
                    DiagnosisCard(
                        item: item,
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
                            selectedIndex = min(selectedIndex + 1, diagnosisItems.count - 1)
                        } else if value.translation.width > threshold {
                            selectedIndex = max(selectedIndex - 1, 0)
                        }
                        dragOffset = 0
                    }
                }
        )
        .frame(width: cardWidth + 80, height: cardHeight + 30)
    }
    
    private func handleCarouselButtonTap(index: Int, item: DiagnosisItem) {
        if selectedIndex == index {
            print("Diagnosis card tapped: \(item.title)")
            
            // Navigate to the immersive view for this item
            Task { @MainActor in
                switch index {
                case 0: // Reaction Time Analyzer
                    await viewRouter.navigateToImmersive(
                        .aiSymptomAnalyzer, 
                        openImmersiveSpace: { id in try await openImmersiveSpace(id: id) }, 
                        dismissImmersiveSpace: { await dismissImmersiveSpace() },
                        dismissMainWindow: { dismissWindow(id: "MainWindow") },
                        openMainWindow: { openWindow(id: "MainWindow") }
                    )
                case 1: // Falling Ball Catch
                    await viewRouter.navigateToImmersive(
                        .fallingBallCatch, 
                        openImmersiveSpace: { id in try await openImmersiveSpace(id: id) }, 
                        dismissImmersiveSpace: { await dismissImmersiveSpace() },
                        dismissMainWindow: { dismissWindow(id: "MainWindow") },
                        openMainWindow: { openWindow(id: "MainWindow") }
                    )
                case 2: // Walk-in-Place Balance
                    await viewRouter.navigateToImmersive(
                        .balanceStationary, 
                        openImmersiveSpace: { id in try await openImmersiveSpace(id: id) }, 
                        dismissImmersiveSpace: { await dismissImmersiveSpace() },
                        dismissMainWindow: { dismissWindow(id: "MainWindow") },
                        openMainWindow: { openWindow(id: "MainWindow") }
                    )
                case 3: // Room-Scale Balance Walk
                    await viewRouter.navigateToImmersive(
                        .balanceRoomScale, 
                        openImmersiveSpace: { id in try await openImmersiveSpace(id: id) }, 
                        dismissImmersiveSpace: { await dismissImmersiveSpace() },
                        dismissMainWindow: { dismissWindow(id: "MainWindow") },
                        openMainWindow: { openWindow(id: "MainWindow") }
                    )
                case 4: // Smooth Pursuit Test
                    await viewRouter.navigateToImmersive(
                        .smoothPursuit, 
                        openImmersiveSpace: { id in try await openImmersiveSpace(id: id) }, 
                        dismissImmersiveSpace: { await dismissImmersiveSpace() },
                        dismissMainWindow: { dismissWindow(id: "MainWindow") },
                        openMainWindow: { openWindow(id: "MainWindow") }
                    )
                case 5: // Saccades Test
                    await viewRouter.navigateToImmersive(
                        .saccadesTest, 
                        openImmersiveSpace: { id in try await openImmersiveSpace(id: id) }, 
                        dismissImmersiveSpace: { await dismissImmersiveSpace() },
                        dismissMainWindow: { dismissWindow(id: "MainWindow") },
                        openMainWindow: { openWindow(id: "MainWindow") }
                    )
                case 6: // Moving Room (Optic Flow)
                    await viewRouter.navigateToImmersive(
                        .movingRoomTest,
                        openImmersiveSpace: { id in try await openImmersiveSpace(id: id) },
                        dismissImmersiveSpace: { await dismissImmersiveSpace() },
                        dismissMainWindow: { dismissWindow(id: "MainWindow") },
                        openMainWindow: { openWindow(id: "MainWindow") }
                    )
                case 7: // Balance Prediction (original)
                    await viewRouter.navigateToImmersive(
                        .balancePrediction, 
                        openImmersiveSpace: { id in try await openImmersiveSpace(id: id) }, 
                        dismissImmersiveSpace: { await dismissImmersiveSpace() },
                        dismissMainWindow: { dismissWindow(id: "MainWindow") },
                        openMainWindow: { openWindow(id: "MainWindow") }
                    )
                default:
                    print("Unknown diagnosis item selected")
                }
            }
        } else {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                selectedIndex = index
            }
        }
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
        return Double(diagnosisItems.count - abs(selectedIndex - index))
    }
    
    private func opacity(for index: Int) -> Double {
        let diff = abs(selectedIndex - index)
        if selectedIndex == index {
            return 1.0
        } else {
            return max(0.6 - (Double(diff - 1) * 0.2), 0.2)
        }
    }
}

// MARK: - Diagnosis Item Model

struct DiagnosisItem: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let icon: String
    let description: String
}

// MARK: - Diagnosis Card

struct DiagnosisCard: View {
    let item: DiagnosisItem
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
                            colors: isAvailable ? [Color.blue.opacity(0.8), Color.teal.opacity(0.6)] : [Color.gray.opacity(0.4), Color.gray.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: Color.black.opacity(0.2), radius: 8, x: 4, y: 4)
                    .shadow(color: Color.white.opacity(0.3), radius: 6, x: -2, y: -2)
                
                Image(systemName: item.icon)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.white)
            }
            
            // Title
            Text(item.title)
                .font(.title3.weight(.bold))
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
                .frame(maxWidth: 240)
            
            // Description
            Text(item.description)
                .font(.caption.weight(.medium))
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .opacity(0.9)
                .lineLimit(2)
                .padding(.horizontal, 8)
            
            // Status Badge
            if isAvailable {
                Text("AVAILABLE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        Color.green.opacity(0.8),
                        in: RoundedRectangle(cornerRadius: 8)
                    )
            } else {
                Text("COMING SOON")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        Color.gray.opacity(0.7),
                        in: RoundedRectangle(cornerRadius: 8)
                    )
            }
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
                                    isAvailable ? Color.blue.opacity(0.6) : Color.gray.opacity(0.5),
                                    isAvailable ? Color.teal.opacity(0.4) : Color.gray.opacity(0.3)
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
    
    // Helper to determine if this test is available
    private var isAvailable: Bool {
        // Items 0-6 are available (Reaction Time, both Balance tests, Smooth Pursuit, Saccades, Moving Room, Balance Prediction)
        return true
    }
}

// MARK: - Previews

#Preview("Interactive Diagnosis", traits: .fixedLayout(width: 1200, height: 800)) {
    InteractiveDiagnosisView()
        .environment(ViewRouter())
}