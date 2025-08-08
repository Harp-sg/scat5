import SwiftUI
import SwiftData

struct InteractiveDiagnosisView: View {
    @Environment(ViewRouter.self) private var viewRouter
    @State private var selectedIndex = 0
    @State private var dragOffset: CGFloat = 0
    
    private let diagnosisItems = [
        DiagnosisItem(title: "AI Symptom\nAnalyzer", icon: "brain.head.profile", description: "Advanced AI-powered symptom pattern recognition"),
        DiagnosisItem(title: "Voice Pattern\nAssessment", icon: "waveform.path", description: "Analyze speech patterns for cognitive indicators"),
        DiagnosisItem(title: "Eye Movement\nTracking", icon: "eye.fill", description: "Track saccades and visual processing speed"),
        DiagnosisItem(title: "Balance\nPrediction", icon: "figure.walk.motion", description: "Predict balance issues using motion sensors"),
        DiagnosisItem(title: "Risk Factor\nAnalysis", icon: "chart.pie.fill", description: "Comprehensive risk assessment modeling")
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
        return ZStack {
            ForEach(Array(diagnosisItems.enumerated()), id: \.element.id) { index, item in
                Button(action: {
                    if selectedIndex == index {
                        print("Diagnosis card tapped: \(item.title)")
                        // Handle tap - currently just print since it's coming soon
                    } else {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            selectedIndex = index
                        }
                    }
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
                            colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.3)],
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
            
            // Coming Soon Badge
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
                                    Color.gray.opacity(0.5),
                                    Color.gray.opacity(0.3)
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

#Preview("Interactive Diagnosis", traits: .fixedLayout(width: 1200, height: 800)) {
    InteractiveDiagnosisView()
        .environment(ViewRouter())
}