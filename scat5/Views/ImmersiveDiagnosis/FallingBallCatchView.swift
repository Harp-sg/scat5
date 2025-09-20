import SwiftUI
import RealityKit
import ARKit
import Combine

struct FallingBallCatchView: View {
    @Environment(ViewRouter.self) private var viewRouter
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openWindow) private var openWindow
    
    // Game state
    @State private var isGameActive = false
    @State private var isPaused = false
    @State private var gameStartTime: TimeInterval = 0
    @State private var currentLevel = 1
    @State private var score = 0
    @State private var streak = 0
    @State private var missedCount = 0
    
    // Ball management
    @State private var activeBalls: [FallingBallEntity] = []
    @State private var previewBalls: [FallingBallEntity] = []  // Balls visible before dropping
    @State private var ballSpawnTimer: Timer?
    @State private var gameUpdateTimer: Timer?
    @State private var nextBallID = 0
    @State private var gameSpaceEntity: Entity?
    @State private var ballHolders: [Entity] = []  // Visual holders for preview balls
    
    // Hand tracking
    @State private var arkitSession = ARKitSession()
    @State private var handTracking = HandTrackingProvider()
    @State private var handTrackingTask: Task<Void, Never>?
    @State private var leftHandPosition: SIMD3<Float>?
    @State private var rightHandPosition: SIMD3<Float>?
    @State private var handTrackingActive = false
    
    // Performance metrics
    @State private var reactionTimes: [FallReactionData] = []
    @State private var catchPositions: [CatchPosition] = []
    @State private var showResults = false
    @State private var sessionResults: FallSessionResults?
    
    // Game configuration
    @State private var difficulty: Difficulty = .medium
    @State private var gameDuration: TimeInterval = 60
    @State private var elapsedTime: TimeInterval = 0
    
    enum Difficulty: String, CaseIterable {
        case easy = "Easy"
        case medium = "Medium"
        case hard = "Hard"
        case expert = "Expert"
        
        var fallSpeed: Float {
            switch self {
            case .easy: return 1.2     // Much slower - 1.2 m/s downward
            case .medium: return 2.5   // 2.5 m/s downward  
            case .hard: return 4.0     // 4 m/s downward
            case .expert: return 6.0   // 6 m/s downward
            }
        }
        
        var spawnInterval: TimeInterval {
            switch self {
            case .easy: return 4.0     // Much longer intervals - 4 seconds
            case .medium: return 2.5
            case .hard: return 1.5
            case .expert: return 1.0
            }
        }
        
        var ballSizeRange: ClosedRange<Float> {
            switch self {
            case .easy: return 0.12...0.16    // Much larger balls for easier catching
            case .medium: return 0.08...0.12
            case .hard: return 0.06...0.10
            case .expert: return 0.04...0.08
            }
        }
        
        var spawnHeight: Float {
            switch self {
            case .easy: return 2.0     // Much lower spawn for more time
            case .medium: return 2.8   
            case .hard: return 3.5     
            case .expert: return 4.2   
            }
        }
        
        var previewTime: TimeInterval {
            switch self {
            case .easy: return 2.0     // 2 seconds to see ball before it drops
            case .medium: return 1.5   // 1.5 seconds preview
            case .hard: return 1.0     // 1 second preview
            case .expert: return 0.5   // 0.5 second preview
            }
        }
        
        var description: String {
            switch self {
            case .easy: return "Very slow, large balls, 2s preview, beginner friendly"
            case .medium: return "Moderate speed, medium balls, 1.5s preview"
            case .hard: return "Fast falling, small balls, 1s preview"
            case .expert: return "Elite speed, tiny balls, 0.5s preview"
            }
        }
    }
    
    class FallingBallEntity: Entity {
        var ballID: Int = 0
        var velocity: SIMD3<Float> = .zero
        var size: Float = 0.08
        var color: UIColor = .systemBlue
        var spawnTime: TimeInterval = 0
        var dropTime: TimeInterval = 0  // When it actually starts falling
        var ballType: BallType = .standard
        var points: Int = 10
        var isCaught = false
        var isPreview = true  // Whether it's in preview mode
        var fallDistance: Float = 0
        var holderPosition: SIMD3<Float> = .zero  // Position in holder
        
        enum BallType {
            case standard    // Blue - normal points
            case bonus      // Gold - double points
            case fast       // Red - fast falling
            case fragile    // Green - breaks if not caught gently
        }
    }
    
    struct FallReactionData {
        let ballID: Int
        let reactionTime: TimeInterval
        let ballType: FallingBallEntity.BallType
        let fallDistance: Float
        let catchHeight: Float
        let success: Bool
        let hand: HandSide
        let accuracy: Float // How close to ball center
        
        enum HandSide {
            case left, right, both
        }
    }
    
    struct CatchPosition {
        let position: SIMD3<Float>
        let time: TimeInterval
        let accuracy: Float
    }
    
    struct FallSessionResults {
        let duration: TimeInterval
        let totalScore: Int
        let ballsCaught: Int
        let ballsMissed: Int
        let averageReactionTime: TimeInterval
        let fastestReaction: TimeInterval
        let averageCatchHeight: Float
        let catchAccuracy: Float
        let dominantHand: FallReactionData.HandSide
        let difficulty: String
        let athleticPerformance: AthleteRating
    }
    
    enum AthleteRating: String {
        case elite = "Elite Athlete"
        case advanced = "Advanced"
        case intermediate = "Intermediate"
        case beginner = "Beginner"
        case needsWork = "Needs Improvement"
    }

    var body: some View {
        RealityView { content, attachments in
            // Create game space for falling balls
            let gameSpace = Entity()
            gameSpace.name = "FallingBallGameSpace"
            content.add(gameSpace)
            
            gameSpaceEntity = gameSpace
            
            // Add visual elements
            createCatchZones(in: gameSpace)
            createBallHolders(in: gameSpace)
            
            // Add control panel
            if let controlPanel = attachments.entity(for: "controlPanel") {
                let anchor = AnchorEntity(.head)
                controlPanel.position = [0, -0.5, -1.5]
                controlPanel.components.set(BillboardComponent())
                anchor.addChild(controlPanel)
                content.add(anchor)
            }
            
            // Add score display
            if let scorePanel = attachments.entity(for: "scorePanel") {
                let anchor = AnchorEntity(.head)
                scorePanel.position = [0, 0.6, -2.0]
                scorePanel.components.set(BillboardComponent())
                anchor.addChild(scorePanel)
                content.add(anchor)
            }
            
            // Add results panel
            if let resultsPanel = attachments.entity(for: "resultsPanel") {
                let anchor = AnchorEntity(.head)
                resultsPanel.position = [0, 0, -1.5]
                resultsPanel.components.set(BillboardComponent())
                anchor.addChild(resultsPanel)
                content.add(anchor)
            }
            
            // Add exit button
            if let exitButton = attachments.entity(for: "exitButton") {
                let anchor = AnchorEntity(.head)
                exitButton.position = [0.4, 0.4, -1.2]  // Moved closer from 0.8 to 0.4
                exitButton.components.set(BillboardComponent())
                anchor.addChild(exitButton)
                content.add(anchor)
            }
            
        } update: { content, attachments in
            // Update ball physics and collision detection
            if isGameActive && !isPaused {
                updateFallingBalls()
                checkHandCollisions()
            }
            
        } attachments: {
            // Control Panel
            Attachment(id: "controlPanel") {
                VStack(spacing: 15) {
                    Text("Falling Ball Catch")
                        .font(.title2)
                        .bold()
                    
                    // Hand tracking status
                    HStack {
                        Circle()
                            .fill((leftHandPosition != nil || rightHandPosition != nil) ? .green : .red)
                            .frame(width: 12, height: 12)
                        Text((leftHandPosition != nil || rightHandPosition != nil) ? "Hands Detected" : "No Hands Detected")
                            .font(.caption)
                            .foregroundColor((leftHandPosition != nil || rightHandPosition != nil) ? .green : .red)
                    }
                    
                    if !isGameActive {
                        VStack(spacing: 12) {
                            Text("Catch falling balls with your hands")
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                            
                            VStack(spacing: 8) {
                                Text("Difficulty")
                                    .font(.headline)
                                
                                // Replace finicky segmented picker with individual buttons
                                HStack(spacing: 16) {
                                    ForEach(Difficulty.allCases, id: \.self) { level in
                                        Button {
                                            difficulty = level
                                        } label: {
                                            Text(level.rawValue)
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(difficulty == level ? .white : .primary)
                                                .frame(width: 65, height: 40)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .fill(difficulty == level ? Color.orange : Color.gray.opacity(0.2))
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                
                                Text(difficulty.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            
                            VStack(spacing: 8) {
                                Text("Duration: \(Int(gameDuration)) seconds")
                                    .font(.system(size: 16, weight: .medium))
                                
                                HStack(spacing: 12) {
                                    Button("-10s") {
                                        gameDuration = max(30, gameDuration - 10)
                                    }
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(width: 50, height: 36)
                                    .background(Color.orange, in: RoundedRectangle(cornerRadius: 6))
                                    .buttonStyle(.plain)
                                    
                                    Text("\(Int(gameDuration))s")
                                        .font(.system(size: 18, weight: .bold))
                                        .frame(width: 60)
                                    
                                    Button("+10s") {
                                        gameDuration = min(120, gameDuration + 10)
                                    }
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(width: 50, height: 36)
                                    .background(Color.orange, in: RoundedRectangle(cornerRadius: 6))
                                    .buttonStyle(.plain)
                                }
                            }
                            
                            Text("Instructions:")
                                .font(.headline)
                            Text("• Watch the balls in holders above")
                                .font(.caption)
                            Text("• One will randomly drop - catch it with your hands!")
                                .font(.caption)
                            Text("• Blue = 10 pts, Gold = 20 pts, Red = Fast (15 pts)")
                                .font(.caption)
                            Text("• Green = Fragile - catch gently! (25 pts)")
                                .font(.caption)
                            Text("• Easy mode: Large balls, slow drops, long preview")
                                .font(.caption)
                                .foregroundColor(.green)
                                .fontWeight(.bold)
                        }
                        
                        Button(action: startGame) {
                            Label("Start Athletic Test", systemImage: "figure.basketball")
                                .font(.system(size: 18, weight: .semibold))
                                .frame(width: 220, height: 50)
                                .background(Color.orange, in: RoundedRectangle(cornerRadius: 12))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                    } else {
                        // During game controls
                        VStack(spacing: 10) {
                            Text(String(format: "Time: %.0f", gameDuration - elapsedTime))
                                .font(.title2)
                                .monospacedDigit()
                                .foregroundColor(elapsedTime > gameDuration - 10 ? .red : .primary)
                            
                            // Hand status with positions
                            VStack(spacing: 8) {
                                HStack(spacing: 20) {
                                    VStack {
                                        Image(systemName: "hand.raised.fill")
                                            .foregroundColor(leftHandPosition != nil ? .green : .gray)
                                        Text("Left")
                                            .font(.caption)
                                        if let pos = leftHandPosition {
                                            Text(String(format: "H: %.2f", pos.y))
                                                .font(.system(size: 8))
                                                .foregroundColor(.secondary)
                                        } else {
                                            Text("Not detected")
                                                .font(.system(size: 8))
                                                .foregroundColor(.red)
                                        }
                                    }
                                    
                                    VStack {
                                        Image(systemName: "hand.raised.fill")
                                            .foregroundColor(rightHandPosition != nil ? .green : .gray)
                                        Text("Right")
                                            .font(.caption)
                                        if let pos = rightHandPosition {
                                            Text(String(format: "H: %.2f", pos.y))
                                                .font(.system(size: 8))
                                                .foregroundColor(.secondary)
                                        } else {
                                            Text("Not detected")
                                                .font(.system(size: 8))
                                                .foregroundColor(.red)
                                        }
                                    }
                                }
                                
                                Text("Active Balls: \(activeBalls.count)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                if let lastReaction = reactionTimes.last {
                                    Text("Last: \(String(format: "%.3f", lastReaction.reactionTime))s")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            }
                            
                            HStack(spacing: 20) {
                                Button(action: { isPaused.toggle() }) {
                                    Image(systemName: isPaused ? "play.fill" : "pause.fill")
                                        .font(.system(size: 18))
                                        .frame(width: 70, height: 45)
                                        .background(Color.orange, in: RoundedRectangle(cornerRadius: 10))
                                        .foregroundColor(.white)
                                }
                                .buttonStyle(.plain)
                                
                                Button(action: stopGame) {
                                    Text("Stop")
                                        .font(.system(size: 16, weight: .medium))
                                        .frame(width: 70, height: 45)
                                        .background(Color.red, in: RoundedRectangle(cornerRadius: 10))
                                        .foregroundColor(.white)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding()
                .frame(width: 340)
                .background(.regularMaterial)
                .cornerRadius(16)
            }
            
            // Score Panel
            Attachment(id: "scorePanel") {
                if isGameActive {
                    VStack(spacing: 8) {
                        Text("\(score)")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.orange)
                        
                        HStack(spacing: 20) {
                            VStack {
                                Text("Streak")
                                    .font(.caption)
                                Text("\(streak)")
                                    .font(.title3)
                                    .bold()
                                    .foregroundColor(streak > 5 ? .orange : .primary)
                            }
                            
                            VStack {
                                Text("Caught")
                                    .font(.caption)
                                Text("\(reactionTimes.count)")
                                    .font(.title3)
                                    .bold()
                                    .foregroundColor(.green)
                            }
                            
                            VStack {
                                Text("Missed")
                                    .font(.caption)
                                Text("\(missedCount)")
                                    .font(.title3)
                                    .bold()
                                    .foregroundColor(.red)
                            }
                        }
                        
                        if streak >= 3 {
                            Text("🔥 \(comboMultiplier)x Combo!")
                                .font(.headline)
                                .foregroundColor(.orange)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                } else {
                    Color.clear.frame(width: 1, height: 1)
                }
            }
            
            // Results Panel
            Attachment(id: "resultsPanel") {
                if showResults, let results = sessionResults {
                    VStack(spacing: 16) {
                        Text("Athletic Performance Results")
                            .font(.title2)
                            .bold()
                        
                        // Athletic Rating
                        VStack(spacing: 8) {
                            Text(results.athleticPerformance.rawValue)
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(athleteColor(results.athleticPerformance))
                            
                            Text("Athletic Performance Level")
                                .font(.headline)
                                .foregroundColor(athleteColor(results.athleticPerformance))
                        }
                        .padding()
                        .background(athleteColor(results.athleticPerformance).opacity(0.1))
                        .cornerRadius(12)

                        Grid(alignment: .leading, horizontalSpacing: 20) {
                            GridRow {
                                Text("Final Score:")
                                Text("\(results.totalScore)")
                                    .foregroundColor(.orange)
                                    .fontWeight(.bold)
                            }
                            GridRow {
                                Text("Catch Rate:")
                                Text(String(format: "%.1f%%", 
                                          Float(results.ballsCaught) / Float(max(1, results.ballsCaught + results.ballsMissed)) * 100))
                                    .foregroundColor(results.ballsCaught > results.ballsMissed ? .green : .red)
                            }
                            GridRow {
                                Text("Avg Reaction:")
                                Text(String(format: "%.3f sec", results.averageReactionTime))
                                    .foregroundColor(reactionColor(results.averageReactionTime))
                            }
                            GridRow {
                                Text("Fastest Catch:")
                                Text(String(format: "%.3f sec", results.fastestReaction))
                                    .foregroundColor(.green)
                            }
                            GridRow {
                                Text("Avg Catch Height:")
                                Text(String(format: "%.2f m", results.averageCatchHeight))
                                    .foregroundColor(results.averageCatchHeight > 1.5 ? .green : .orange)
                            }
                            GridRow {
                                Text("Hand Accuracy:")
                                Text(String(format: "%.1f cm", results.catchAccuracy * 100))
                                    .foregroundColor(results.catchAccuracy < 0.08 ? .green : .orange)
                            }
                            GridRow {
                                Text("Dominant Hand:")
                                Text(results.dominantHand == .left ? "Left" :
                                     results.dominantHand == .right ? "Right" : "Both")
                            }
                        }
                        .font(.system(size: 14))

                        Text(getAthleteAssessment(results))
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)

                        Button("Complete Test") {
                            Task {
                                await viewRouter.closeImmersiveSpace(
                                    dismissImmersiveSpace: { await dismissImmersiveSpace() },
                                    openMainWindow: { openWindow(id: "MainWindow") }
                                )
                            }
                        }
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .padding()
                    .frame(width: 450)
                    .background(.regularMaterial)
                    .cornerRadius(20)
                } else {
                    Color.clear.frame(width: 1, height: 1)
                }
            }
            
            // Exit Button
            Attachment(id: "exitButton") {
                Button {
                    Task {
                        await viewRouter.closeImmersiveSpace(
                            dismissImmersiveSpace: { await dismissImmersiveSpace() },
                            openMainWindow: { openWindow(id: "MainWindow") }
                        )
                    }
                } label: {
                    Label("Exit", systemImage: "xmark.circle.fill")
                        .font(.title2)
                        .padding(12)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .onAppear {
            startHandTracking()
        }
        .onDisappear {
            stopHandTracking()
            stopGame()
        }
    }
    
    // MARK: - Game Control
    
    private func startGame() {
        isGameActive = true
        isPaused = false
        gameStartTime = CACurrentMediaTime()
        score = 0
        streak = 0
        missedCount = 0
        elapsedTime = 0
        reactionTimes.removeAll()
        catchPositions.removeAll()
        activeBalls.removeAll()
        
        startBallSpawning()
        
        gameUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0/90.0, repeats: true) { _ in
            if !isPaused {
                updateGame()
            }
        }
    }
    
    private func stopGame() {
        isGameActive = false
        ballSpawnTimer?.invalidate()
        gameUpdateTimer?.invalidate()
        
        calculateResults()
        showResults = true
        
        for ball in activeBalls {
            ball.removeFromParent()
        }
        activeBalls.removeAll()
    }
    
    private func updateGame() {
        let currentTime = CACurrentMediaTime()
        elapsedTime = currentTime - gameStartTime
        
        if elapsedTime >= gameDuration {
            stopGame()
            return
        }
    }
    
    // MARK: - Ball Management
    
    private func startBallSpawning() {
        // First, create preview balls in holders
        createPreviewBalls()
        
        ballSpawnTimer = Timer.scheduledTimer(withTimeInterval: difficulty.spawnInterval, repeats: true) { _ in
            if !isPaused && isGameActive {
                dropRandomBall()
            }
        }
    }
    
    private func createPreviewBalls() {
        guard let gameSpace = gameSpaceEntity else { return }
        
        // Clear existing preview balls
        for ball in previewBalls {
            ball.removeFromParent()
        }
        previewBalls.removeAll()
        
        // Create fewer preview balls in a smaller setup
        let numBalls = Int.random(in: 3...5)  // Reduced from 4-6
        let positions = getBallHolderPositions(count: numBalls)
        
        for (index, position) in positions.enumerated() {
            let ball = createFallingBall()
            ball.isPreview = true
            ball.holderPosition = position
            ball.position = position
            ball.velocity = .zero  // Not falling yet
            
            // Add gentle floating animation for preview
            addPreviewAnimation(to: ball)
            
            gameSpace.addChild(ball)
            previewBalls.append(ball)
            
            print("🔮 Created preview ball \(ball.ballID) at position \(position)")
        }
    }
    
    private func dropRandomBall() {
        guard !previewBalls.isEmpty else { 
            createPreviewBalls()  // Recreate if none left
            return 
        }
        
        // Pick a random preview ball to drop
        let randomIndex = Int.random(in: 0..<previewBalls.count)
        let ballToDrop = previewBalls[randomIndex]
        
        // Remove from preview array and add to active
        previewBalls.remove(at: randomIndex)
        activeBalls.append(ballToDrop)
        
        // Start the drop after preview time
        ballToDrop.isPreview = false
        ballToDrop.dropTime = CACurrentMediaTime()
        ballToDrop.velocity = [0, -difficulty.fallSpeed, 0]
        
        // Add drop animation/effect
        addDropEffect(to: ballToDrop)
        
        print("💥 Dropped ball \(ballToDrop.ballID) from preview!")
        
        // Refill preview balls if getting low
        if previewBalls.count < 2 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.createPreviewBalls()
            }
        }
    }
    
    private func getBallHolderPositions(count: Int) -> [SIMD3<Float>] {
        var positions: [SIMD3<Float>] = []
        let height: Float = 1.6  // Eye level height
        
        // Arrange in a small arc directly in front of the player
        let radius: Float = 0.6  // Much closer - right in front
        let totalAngle: Float = Float.pi * 0.3  // 54 degrees - narrow arc in front
        let angleStep = count > 1 ? totalAngle / Float(count - 1) : 0
        let startAngle = -totalAngle / 2  // Center the arc
        
        for i in 0..<count {
            let angle = startAngle + angleStep * Float(i)
            let x = sin(angle) * radius
            let z = -cos(angle) * radius - 0.8  // Negative Z puts it in front of player
            positions.append([x, height, z])
        }
        
        return positions
    }
    
    private func addPreviewAnimation(to ball: FallingBallEntity) {
        // Gentle bobbing animation for preview balls
        let bobAnimation = FromToByAnimation<Transform>(
            name: "preview_bob",
            from: .init(translation: ball.position),
            to: .init(translation: ball.position + [0, 0.05, 0]),
            duration: 2.0,
            timing: .easeInOut,
            isAdditive: false
        )
        
        if let animationResource = try? AnimationResource.generate(with: bobAnimation) {
            ball.playAnimation(animationResource.repeat())
        }
    }
    
    private func addDropEffect(to ball: FallingBallEntity) {
        // Visual effect when ball starts dropping
        let glowMaterial = SimpleMaterial(color: ball.color.withAlphaComponent(0.6), isMetallic: false)
        let effectSphere = ModelEntity(
            mesh: .generateSphere(radius: ball.size * 1.5),
            materials: [glowMaterial]
        )
        
        ball.addChild(effectSphere)
        
        // Remove effect after short time
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            effectSphere.removeFromParent()
        }
    }
    
    private func createFallingBall() -> FallingBallEntity {
        let ball = FallingBallEntity()
        ball.ballID = nextBallID
        nextBallID += 1
        ball.spawnTime = CACurrentMediaTime()
        
        // Determine ball type
        let typeRoll = Float.random(in: 0...1)
        if typeRoll < 0.05 {  // 5% fragile balls
            ball.ballType = .fragile
            ball.color = .systemGreen
            ball.points = 25
        } else if typeRoll < 0.15 {  // 10% fast balls
            ball.ballType = .fast
            ball.color = .systemRed
            ball.points = 15
        } else if typeRoll < 0.25 {  // 10% bonus balls
            ball.ballType = .bonus
            ball.color = .systemYellow
            ball.points = 20
        } else {  // 75% standard balls
            ball.ballType = .standard
            ball.color = .systemBlue
            ball.points = 10
        }
        
        ball.size = Float.random(in: difficulty.ballSizeRange)
        
        // Create visual
        let mesh = MeshResource.generateSphere(radius: ball.size)
        var material = SimpleMaterial()
        material.color = .init(tint: ball.color)
        
        if ball.ballType == .bonus {
            material.metallic = 0.8
            material.roughness = 0.2
        } else if ball.ballType == .fragile {
            material.roughness = 0.1
            material.metallic = 0.1
        }
        
        let modelEntity = ModelEntity(mesh: mesh, materials: [material])
        ball.addChild(modelEntity)
        
        // Add glow for special balls
        if ball.ballType != .standard {
            addGlowEffect(to: ball)
        }
        
        return ball
    }
    
    private func addGlowEffect(to ball: FallingBallEntity) {
        let glowMesh = MeshResource.generateSphere(radius: ball.size * 1.3)
        var glowMaterial = SimpleMaterial()
        glowMaterial.color = .init(tint: ball.color.withAlphaComponent(0.3))
        glowMaterial.metallic = 0
        
        let glowEntity = ModelEntity(mesh: glowMesh, materials: [glowMaterial])
        ball.addChild(glowEntity)
    }
    
    private func updateFallingBalls() {
        let deltaTime: Float = 1.0/90.0
        var ballsToRemove: [FallingBallEntity] = []
        
        // Only update balls that are actually falling (not preview)
        for ball in activeBalls where !ball.isCaught && !ball.isPreview {
            // Update position
            ball.position = ball.position + (ball.velocity * deltaTime)
            ball.fallDistance += abs(ball.velocity.y * deltaTime)
            
            // Apply very light gravity for more realistic fall (much gentler than before)
            ball.velocity.y -= 2.0 * deltaTime  // Much lighter gravity
            
            // Remove if hit ground or went too far
            if ball.position.y < 0.3 || abs(ball.position.x) > 4 || abs(ball.position.z) > 4 {
                ballsToRemove.append(ball)
                if ball.position.y < 0.3 {
                    missedCount += 1
                    streak = 0
                    print("❌ Ball \(ball.ballID) hit ground")
                }
            }
            
            // Add gentle rotation
            let rotation = simd_quatf(angle: Float(elapsedTime) * 1.5, axis: [1, 0.5, 0])
            if let modelChild = ball.children.first {
                modelChild.orientation = rotation
            }
        }
        
        for ball in ballsToRemove {
            ball.removeFromParent()
            activeBalls.removeAll { $0.ballID == ball.ballID }
        }
    }
    
    // MARK: - Collision Detection
    
    private func checkHandCollisions() {
        let currentTime = CACurrentMediaTime()
        let catchRadius: Float = {
            switch difficulty {
            case .easy: return 0.20     // Even more forgiving collision
            case .medium: return 0.18
            case .hard: return 0.15
            case .expert: return 0.12
            }
        }()
        
        // Debug: Print hand positions periodically
        if Int(currentTime) % 2 == 0 && Int(currentTime * 10) % 10 == 0 {  // Every 2 seconds
            if let leftPos = leftHandPosition {
                print("🤲 LEFT hand at: \(leftPos)")
            }
            if let rightPos = rightHandPosition {
                print("🤲 RIGHT hand at: \(rightPos)")
            }
            print("📊 Active falling balls: \(activeBalls.filter { !$0.isPreview && !$0.isCaught }.count)")
        }
        
        // Only check collisions with falling balls (not preview)
        for ball in activeBalls where !ball.isCaught && !ball.isPreview {
            var ballCaught = false
            
            // Check left hand
            if let leftPos = leftHandPosition {
                let distance = simd_distance(ball.position, leftPos)
                if distance < catchRadius {
                    print("🎯 LEFT HAND caught ball \(ball.ballID)! Distance: \(String(format: "%.3f", distance))m")
                    print("   Ball pos: \(ball.position), Hand pos: \(leftPos)")
                    catchBall(ball, withHand: .left, at: leftPos, time: currentTime)
                    ballCaught = true
                }
            }
            
            // Check right hand
            if !ballCaught, let rightPos = rightHandPosition {
                let distance = simd_distance(ball.position, rightPos)
                if distance < catchRadius {
                    print("🎯 RIGHT HAND caught ball \(ball.ballID)! Distance: \(String(format: "%.3f", distance))m")
                    print("   Ball pos: \(ball.position), Hand pos: \(rightPos)")
                    catchBall(ball, withHand: .right, at: rightPos, time: currentTime)
                }
            }
        }
    }
    
    private func catchBall(_ ball: FallingBallEntity, withHand hand: FallReactionData.HandSide, at position: SIMD3<Float>, time: TimeInterval) {
        guard !ball.isCaught else { return }
        ball.isCaught = true
        
        // Calculate reaction time from when ball started dropping (not from spawn)
        let reactionTime = time - ball.dropTime
        let catchHeight = ball.position.y
        let accuracy = simd_distance(ball.position, position)
        
        // Height bonus - but more generous for easy mode
        let heightMultiplier: Float = {
            switch difficulty {
            case .easy: return 5      // 5 points per meter for easy
            case .medium: return 8
            case .hard: return 12
            case .expert: return 15
            }
        }()
        let heightBonus = max(0, Int((catchHeight - 1.0) * heightMultiplier))
        
        let reactionData = FallReactionData(
            ballID: ball.ballID,
            reactionTime: reactionTime,
            ballType: ball.ballType,
            fallDistance: ball.fallDistance,
            catchHeight: catchHeight,
            success: true,
            hand: hand,
            accuracy: accuracy
        )
        reactionTimes.append(reactionData)
        
        let catchPos = CatchPosition(
            position: position,
            time: time,
            accuracy: accuracy
        )
        catchPositions.append(catchPos)
        
        // Calculate points with bonuses
        let basePoints = ball.points * comboMultiplier
        let totalPoints = basePoints + heightBonus
        score += totalPoints
        streak += 1
        
        print("✅ Ball caught! Points: \(totalPoints) (base: \(basePoints), height bonus: \(heightBonus))")
        
        // Remove ball with delay
        Task {
            try? await Task.sleep(nanoseconds: 200_000_000)  // Slightly longer delay to see success
            await MainActor.run {
                ball.removeFromParent()
                activeBalls.removeAll { $0.ballID == ball.ballID }
            }
        }
    }
    
    private var comboMultiplier: Int {
        if streak >= 10 { return 3 }
        if streak >= 5 { return 2 }
        return 1
    }
    
    // MARK: - Hand Tracking
    
    private func startHandTracking() {
        print("🖐️ Starting hand tracking for falling ball test...")
        handTrackingTask = Task {
            do {
                let authorizationResult = await arkitSession.requestAuthorization(for: [.handTracking])
                
                guard authorizationResult[.handTracking] == .allowed else {
                    print("❌ Hand tracking not authorized")
                    await MainActor.run { handTrackingActive = false }
                    return
                }
                
                try await arkitSession.run([handTracking])
                
                await MainActor.run {
                    handTrackingActive = true
                    print("✅ Hand tracking active for falling balls")
                }
                
                for await update in handTracking.anchorUpdates {
                    guard let handAnchor = update.anchor as? HandAnchor else { continue }
                    
                    await MainActor.run {
                        processHandUpdate(handAnchor)
                    }
                }
            } catch {
                print("❌ Hand tracking error: \(error)")
                await MainActor.run { handTrackingActive = false }
            }
        }
    }
    
    private func processHandUpdate(_ anchor: HandAnchor) {
        guard let skeleton = anchor.handSkeleton else { 
            // Clear hand position if no skeleton
            if anchor.chirality == .left {
                leftHandPosition = nil
            } else {
                rightHandPosition = nil
            }
            return 
        }
        
        // Use palm position for catching - more accurate than metacarpal
        let palmJoint = skeleton.joint(.middleFingerMetacarpal)
        guard palmJoint.isTracked else {
            // Clear position if joint not tracked
            if anchor.chirality == .left {
                leftHandPosition = nil
            } else {
                rightHandPosition = nil
            }
            return
        }
        
        let palmTransform = anchor.originFromAnchorTransform * palmJoint.anchorFromJointTransform
        let palmPosition = SIMD3<Float>(
            palmTransform.columns.3.x,
            palmTransform.columns.3.y,
            palmTransform.columns.3.z
        )
        
        if anchor.chirality == .left {
            leftHandPosition = palmPosition
        } else {
            rightHandPosition = palmPosition
        }
    }
    
    private func stopHandTracking() {
        print("🛑 Stopping hand tracking...")
        handTrackingTask?.cancel()
        handTrackingTask = nil
        handTrackingActive = false
    }
    
    // MARK: - Results and Assessment
    
    private func calculateResults() {
        let validReactions = reactionTimes.filter { $0.success }
        let avgReaction = validReactions.isEmpty ? 0 :
            validReactions.map { $0.reactionTime }.reduce(0, +) / Double(validReactions.count)
        
        let fastest = validReactions.map { $0.reactionTime }.min() ?? 0
        let avgHeight = validReactions.isEmpty ? 0 :
            validReactions.map { $0.catchHeight }.reduce(0, +) / Float(validReactions.count)
        
        let avgAccuracy = catchPositions.isEmpty ? 0 :
            catchPositions.map { $0.accuracy }.reduce(0, +) / Float(catchPositions.count)
        
        // Determine dominant hand
        let leftCatches = validReactions.filter { $0.hand == .left }.count
        let rightCatches = validReactions.filter { $0.hand == .right }.count
        let dominantHand: FallReactionData.HandSide =
            leftCatches > rightCatches ? .left :
            rightCatches > leftCatches ? .right : .both
        
        // Calculate athletic performance rating
        let athleticRating = calculateAthleteRating(
            avgReaction: avgReaction,
            catchRate: Float(validReactions.count) / Float(max(1, validReactions.count + missedCount)),
            avgHeight: avgHeight,
            accuracy: avgAccuracy
        )
        
        sessionResults = FallSessionResults(
            duration: elapsedTime,
            totalScore: score,
            ballsCaught: validReactions.count,
            ballsMissed: missedCount,
            averageReactionTime: avgReaction,
            fastestReaction: fastest,
            averageCatchHeight: avgHeight,
            catchAccuracy: avgAccuracy,
            dominantHand: dominantHand,
            difficulty: difficulty.rawValue,
            athleticPerformance: athleticRating
        )
    }
    
    private func calculateAthleteRating(avgReaction: Double, catchRate: Float, avgHeight: Float, accuracy: Float) -> AthleteRating {
        var score = 0
        
        // Reaction time scoring (40% weight)
        if avgReaction < 0.3 { score += 40 }
        else if avgReaction < 0.4 { score += 35 }
        else if avgReaction < 0.5 { score += 30 }
        else if avgReaction < 0.7 { score += 20 }
        else { score += 10 }
        
        // Catch rate scoring (30% weight)
        if catchRate > 0.9 { score += 30 }
        else if catchRate > 0.8 { score += 25 }
        else if catchRate > 0.7 { score += 20 }
        else if catchRate > 0.5 { score += 15 }
        else { score += 5 }
        
        // Height scoring (20% weight) - higher catches show better anticipation
        if avgHeight > 2.0 { score += 20 }
        else if avgHeight > 1.7 { score += 15 }
        else if avgHeight > 1.4 { score += 10 }
        else { score += 5 }
        
        // Accuracy scoring (10% weight)
        if accuracy < 0.05 { score += 10 }
        else if accuracy < 0.10 { score += 8 }
        else if accuracy < 0.15 { score += 5 }
        else { score += 2 }
        
        // Determine rating
        if score >= 90 { return .elite }
        if score >= 75 { return .advanced }
        if score >= 60 { return .intermediate }
        if score >= 40 { return .beginner }
        return .needsWork
    }
    
    // MARK: - Helper Functions
    
    private func createCatchZones(in root: Entity) {
        // Create minimal visual catch zone - just a ground reference
        let zoneMaterial = SimpleMaterial(color: UIColor.orange.withAlphaComponent(0.05), isMetallic: false)
        
        // Small ground catch zone directly in front
        let groundZone = ModelEntity(
            mesh: .generatePlane(width: 1.5, depth: 1.5),  // Much smaller
            materials: [zoneMaterial]
        )
        groundZone.position = [0, 0.3, -0.8]  // In front of player
        groundZone.orientation = simd_quatf(angle: -.pi/2, axis: [1, 0, 0])
        root.addChild(groundZone)
    }
    
    private func createBallHolders(in root: Entity) {
        // Simplified - just create holder positions without visual elements
        let numHolders = 5  // Reduce number for smaller setup
        let positions = getBallHolderPositions(count: numHolders)
        
        // Store positions but don't create visual holders
        ballHolders.removeAll()
        
        print("🏀 Created \(numHolders) ball holder positions in front arc")
    }
    
    private func athleteColor(_ rating: AthleteRating) -> Color {
        switch rating {
        case .elite: return .purple
        case .advanced: return .green
        case .intermediate: return .blue
        case .beginner: return .orange
        case .needsWork: return .red
        }
    }
    
    private func reactionColor(_ time: TimeInterval) -> Color {
        if time < 0.3 { return .green }
        if time < 0.5 { return .yellow }
        if time < 0.7 { return .orange }
        return .red
    }
    
    private func getAthleteAssessment(_ results: FallSessionResults) -> String {
        var assessment = ""
        
        switch results.athleticPerformance {
        case .elite:
            assessment = "Outstanding athletic performance! Your reaction time, catch rate, and anticipation skills are at elite athlete level. Excellent hand-eye coordination and spatial awareness."
        case .advanced:
            assessment = "Strong athletic performance. Good reaction times and catch accuracy. Your anticipation skills show advanced training. Consider working on consistency for elite level."
        case .intermediate:
            assessment = "Solid athletic foundation. Reaction times and coordination are developing well. Focus on anticipating ball trajectory and catching higher for better performance."
        case .beginner:
            assessment = "Good starting performance. Your hand-eye coordination has room for improvement. Practice tracking objects and reacting quickly to improve athletic performance."
        case .needsWork:
            assessment = "Consider focused training on reaction time and hand-eye coordination. Regular practice with falling object exercises can significantly improve athletic performance."
        }
        
        // Add specific feedback
        if results.averageReactionTime > 0.7 {
            assessment += " Work on reaction speed training."
        }
        if results.averageCatchHeight < 1.5 {
            assessment += " Practice catching balls higher - shows better anticipation."
        }
        if Float(results.ballsCaught) / Float(max(1, results.ballsCaught + results.ballsMissed)) < 0.7 {
            assessment += " Focus on tracking and positioning drills."
        }
        
        return assessment
    }
}