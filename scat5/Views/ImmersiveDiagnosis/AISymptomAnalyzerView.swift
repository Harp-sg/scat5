import SwiftUI
import RealityKit
import RealityKitContent
import ARKit
import Combine

struct AISymptomAnalyzerView: View {
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
    @State private var activeBalls: [BallEntity] = []
    @State private var ballSpawnTimer: Timer?
    @State private var gameUpdateTimer: Timer?
    @State private var nextBallID = 0
    @State private var gameSpaceEntity: Entity?  // Store reference to game space
    
    // Hand tracking
    @State private var arkitSession = ARKitSession()
    @State private var handTracking = HandTrackingProvider()
    @State private var handTrackingTask: Task<Void, Never>?
    @State private var leftHandPosition: SIMD3<Float>?
    @State private var rightHandPosition: SIMD3<Float>?
    @State private var leftHandOpen = true  // Changed: default to true for easier catching
    @State private var rightHandOpen = true // Changed: default to true for easier catching
    @State private var handTrackingActive = false // Track if hand tracking is working
    
    // Performance metrics
    @State private var reactionTimes: [ReactionTimeData] = []
    @State private var catchPositions: [CatchPosition] = []
    @State private var showResults = false
    @State private var sessionResults: SessionResults?
    
    // Game configuration
    @State private var difficulty: Difficulty = .medium
    @State private var gameDuration: TimeInterval = 60
    @State private var elapsedTime: TimeInterval = 0
    
    // Audio feedback
    @State private var audioController = SpatialAudioController()
    
    enum Difficulty: String, CaseIterable {
        case easy = "Easy"
        case medium = "Medium"
        case hard = "Hard"
        case expert = "Expert"
        
        var ballSpeed: Float {
            switch self {
            case .easy: return 3.5     // Gentle introduction - ~1 second to react
            case .medium: return 5.5   // Moderate challenge - ~0.7 seconds to react
            case .hard: return 9.0     // Current fast setting - ~0.4 seconds to react
            case .expert: return 14.0  // Extreme challenge - ~0.25 seconds to react
            }
        }
        
        var spawnInterval: TimeInterval {
            switch self {
            case .easy: return 3.5     // Plenty of time between balls
            case .medium: return 2.5   // Moderate spacing
            case .hard: return 1.8     // Fast spawning
            case .expert: return 1.0   // Rapid fire
            }
        }
        
        var ballSizeRange: ClosedRange<Float> {
            switch self {
            case .easy: return 0.15...0.20    // Larger balls for easier catching
            case .medium: return 0.12...0.18  // Medium size
            case .hard: return 0.10...0.16    // Smaller targets
            case .expert: return 0.08...0.12  // Very small targets
            }
        }
        
        var description: String {
            switch self {
            case .easy: return "Slow balls, large targets, plenty of time"
            case .medium: return "Moderate speed, medium targets"
            case .hard: return "Fast balls, small targets, quick spawning"
            case .expert: return "Lightning fast, tiny targets, rapid fire"
            }
        }
    }
    
    class BallEntity: Entity {
        var ballID: Int = 0
        var velocity: SIMD3<Float> = .zero
        var size: Float = 0.15
        var color: UIColor = .systemBlue
        var spawnTime: TimeInterval = 0
        var ballType: BallType = .standard
        var points: Int = 10
        var isCaught = false
        
        enum BallType {
            case standard    // Blue - normal points
            case bonus      // Gold - double points
            case speed      // Red - fast moving
            case avoid      // Black - lose points if caught
        }
    }
    
    struct ReactionTimeData {
        let ballID: Int
        let reactionTime: TimeInterval
        let ballType: BallEntity.BallType
        let distance: Float
        let success: Bool
        let hand: HandSide
        
        enum HandSide {
            case left, right, both
        }
    }
    
    struct CatchPosition {
        let position: SIMD3<Float>
        let time: TimeInterval
        let accuracy: Float  // Distance from ball center
    }
    
    struct SessionResults {
        let duration: TimeInterval
        let totalScore: Int
        let ballsCaught: Int
        let ballsMissed: Int
        let averageReactionTime: TimeInterval
        let fastestReaction: TimeInterval
        let slowestReaction: TimeInterval
        let catchAccuracy: Float
        let dominantHand: ReactionTimeData.HandSide
        let difficulty: String
    }
    
    class SpatialAudioController {
        func playSpawnSound(at position: SIMD3<Float>) {
            // In production, implement spatial audio
            print("Ball spawned at \(position)")
        }
        
        func playCatchSound() {
            // Play success sound
        }
        
        func playMissSound() {
            // Play miss sound
        }
    }
    
    var body: some View {
        RealityView { content, attachments in
            // Create game space
            let gameSpace = Entity()
            gameSpace.name = "GameSpace"
            content.add(gameSpace)
            
            // Store reference for later use
            gameSpaceEntity = gameSpace
            
            // Add spawn zone indicators (transparent boundaries)
            createSpawnZones(in: gameSpace)
            
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
                scorePanel.position = [0, 0.5, -2.0]
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
            
            // Add exit button - repositioned closer to center
            if let exitButton = attachments.entity(for: "exitButton") {
                let anchor = AnchorEntity(.head)
                exitButton.position = [0.4, 0.4, -1.2]  // Moved closer from 0.8 to 0.4
                exitButton.components.set(BillboardComponent())
                anchor.addChild(exitButton)
                content.add(anchor)
            }
            
        } update: { content, attachments in
            // DO NOT modify @State variables here - just update visual representation
            // Physics and collision detection moved to game loop timer
            
        } attachments: {
            // Control Panel
            Attachment(id: "controlPanel") {
                VStack(spacing: 15) {
                    Text("Catch the Ball")
                        .font(.title2)
                        .bold()
                    
                    // Hand tracking status indicator
                    HStack {
                        Circle()
                            .fill(handTrackingActive ? .green : .red)
                            .frame(width: 12, height: 12)
                        Text(handTrackingActive ? "Hand Tracking Active" : "Hand Tracking Inactive")
                            .font(.caption)
                            .foregroundColor(handTrackingActive ? .green : .red)
                    }
                    
                    if !isGameActive {
                        // Pre-game settings
                        VStack(spacing: 10) {
                            Text("Difficulty")
                                .font(.headline)
                            
                            // Replace finicky segmented picker with individual buttons
                            VStack(spacing: 12) {
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
                                                        .fill(difficulty == level ? Color.blue : Color.gray.opacity(0.2))
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                
                                // Show difficulty description
                                Text(difficulty.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
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
                            Text("• Move your hands to catch balls flying toward you")
                                .font(.caption)
                            Text("• Blue = 10 pts, Gold = 20 pts, Red = Fast bonus, Black = Avoid")
                                .font(.caption)
                            Text("• Higher difficulty = faster balls & smaller targets")
                                .font(.caption)
                            Text("• Tests reaction time and hand-eye coordination")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .fontWeight(.bold)
                            Text("• Hand tracking works automatically!")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        
                        Button(action: startGame) {
                            Label("Start Game", systemImage: "play.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .frame(width: 200, height: 50)
                                .background(Color.green, in: RoundedRectangle(cornerRadius: 12))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                        
                    } else {
                        // During game controls
                        VStack(spacing: 10) {
                            // Timer
                            Text(String(format: "Time: %.0f", gameDuration - elapsedTime))
                                .font(.title2)
                                .monospacedDigit()
                                .foregroundColor(elapsedTime > gameDuration - 10 ? .orange : .primary)
                            
                            // Hand status indicators - cleaner version
                            VStack(spacing: 8) {
                                HStack(spacing: 20) {
                                    VStack {
                                        Image(systemName: "hand.raised.fill")
                                            .foregroundColor(leftHandPosition != nil ? .green : .gray)
                                        Text("Left")
                                            .font(.caption)
                                    }
                                    
                                    VStack {
                                        Image(systemName: "hand.raised.fill")
                                            .foregroundColor(rightHandPosition != nil ? .green : .gray)
                                        Text("Right")
                                            .font(.caption)
                                    }
                                }
                                
                                // Show last reaction time if available
                                if let lastReaction = reactionTimes.last {
                                    Text("Last: \(String(format: "%.3f", lastReaction.reactionTime))s")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                                
                                Text("Balls: \(activeBalls.count)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
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
                .frame(width: 350)
                .background(.regularMaterial)
                .cornerRadius(15)
            }
            
            // Score Panel (always visible during game)
            Attachment(id: "scorePanel") {
                if isGameActive {
                    VStack(spacing: 8) {
                        Text("\(score)")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.blue)
                        
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
                                Text("\(score / 10)")  // Rough estimate
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
                        
                        // Combo indicator
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
                    EmptyView()
                }
            }
            
            // Results Panel
            Attachment(id: "resultsPanel") {
                if showResults, let results = sessionResults {
                    VStack(spacing: 15) {
                        Text("Game Results")
                            .font(.title)
                            .bold()
                        
                        Text("Final Score: \(results.totalScore)")
                            .font(.title2)
                            .foregroundColor(.blue)
                        
                        // Performance metrics
                        VStack(alignment: .leading, spacing: 10) {
                            Grid(alignment: .leading, horizontalSpacing: 30) {
                                GridRow {
                                    Text("Duration:")
                                    Text(String(format: "%.0f seconds", results.duration))
                                }
                                GridRow {
                                    Text("Balls Caught:")
                                    Text("\(results.ballsCaught)")
                                        .foregroundColor(.green)
                                }
                                GridRow {
                                    Text("Balls Missed:")
                                    Text("\(results.ballsMissed)")
                                        .foregroundColor(.red)
                                }
                                GridRow {
                                    Text("Catch Rate:")
                                    Text(String(format: "%.1f%%",
                                              Float(results.ballsCaught) / Float(max(1, results.ballsCaught + results.ballsMissed)) * 100))
                                }
                                GridRow {
                                    Text("Avg Reaction:")
                                    Text(String(format: "%.2f sec", results.averageReactionTime))
                                }
                                GridRow {
                                    Text("Fastest:")
                                    Text(String(format: "%.2f sec", results.fastestReaction))
                                        .foregroundColor(.green)
                                }
                                GridRow {
                                    Text("Accuracy:")
                                    Text(String(format: "%.1f cm", results.catchAccuracy * 100))
                                }
                                GridRow {
                                    Text("Dominant Hand:")
                                    Text(results.dominantHand == .left ? "Left" :
                                         results.dominantHand == .right ? "Right" : "Both")
                                }
                            }
                            .font(.system(size: 14))
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                        
                        // Performance assessment
                        Text(getPerformanceAssessment(results))
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        
                        HStack(spacing: 20) {
                            Button("Play Again") {
                                resetGame()
                                showResults = false
                            }
                            .font(.system(size: 16, weight: .medium))
                            .frame(width: 120, height: 45)
                            .background(Color.green, in: RoundedRectangle(cornerRadius: 10))
                            .foregroundColor(.white)
                            .buttonStyle(.plain)
                            
                            Button("Close") {
                                showResults = false
                            }
                            .font(.system(size: 16, weight: .medium))
                            .frame(width: 120, height: 45)
                            .background(Color.gray, in: RoundedRectangle(cornerRadius: 10))
                            .foregroundColor(.white)
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                    .frame(width: 450)
                    .background(.regularMaterial)
                    .cornerRadius(20)
                } else {
                    EmptyView()
                }
            }
            
            // Exit Button - Always visible
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
        
        // Start spawning balls
        startBallSpawning()
        
        // Start game update loop - increased frequency for better collision detection
        gameUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0/90.0, repeats: true) { _ in
            if !isPaused {
                updateGame()
                updateBallPhysics()
                checkHandCollisions()
            }
        }
    }
    
    private func stopGame() {
        isGameActive = false
        ballSpawnTimer?.invalidate()
        gameUpdateTimer?.invalidate()
        
        // Calculate final results
        calculateResults()
        showResults = true
        
        // Clean up remaining balls
        for ball in activeBalls {
            ball.removeFromParent()
        }
        activeBalls.removeAll()
    }
    
    private func resetGame() {
        score = 0
        streak = 0
        missedCount = 0
        currentLevel = 1
        activeBalls.removeAll()
        reactionTimes.removeAll()
        catchPositions.removeAll()
        sessionResults = nil
    }
    
    private func updateGame() {
        let currentTime = CACurrentMediaTime()
        elapsedTime = currentTime - gameStartTime
        
        // Check game duration
        if elapsedTime >= gameDuration {
            stopGame()
            return
        }
        
        // Update difficulty based on performance
        updateDifficulty()
        
        // Minimal debug output - only every 10 seconds
        if Int(elapsedTime) % 10 == 0 {
            print("📊 Game status: \(activeBalls.count) balls, \(reactionTimes.count) caught, \(missedCount) missed")
        }
    }
    
    private func updateDifficulty() {
        // Increase difficulty every 20 seconds or based on performance
        let levelUpInterval: TimeInterval = 20
        let newLevel = Int(elapsedTime / levelUpInterval) + 1
        
        if newLevel > currentLevel && streak >= 5 {
            currentLevel = newLevel
            // Could adjust spawn rate or ball speed here
        }
    }
    
    // MARK: - Ball Management
    
    private func startBallSpawning() {
        // Spawn first ball immediately
        spawnBall()
        
        // Then continue with regular interval
        ballSpawnTimer = Timer.scheduledTimer(withTimeInterval: difficulty.spawnInterval, repeats: true) { _ in
            if !isPaused && isGameActive {
                spawnBall()
            }
        }
    }
    
    private func spawnBall() {
        guard let gameSpace = gameSpaceEntity else {
            print("❌ ERROR: No game space entity found!")
            return
        }
        
        let ball = createBall()
        
        // Adjust spawn parameters based on difficulty
        let angleRange: Float = difficulty == .easy ? Float.pi/6 : Float.pi/4  // Easier has narrower angle
        let angle = Float.random(in: -angleRange...angleRange)
        let height = Float.random(in: 1.3...1.8)
        
        // Distance varies by difficulty for appropriate reaction time
        let distance: Float = {
            switch difficulty {
            case .easy: return 4.5     // Farther away for more reaction time
            case .medium: return 4.0   // Standard distance
            case .hard: return 3.5     // Closer for faster arrival
            case .expert: return 3.0   // Very close for extreme challenge
            }
        }()
        
        // Position in front of player
        ball.position = [
            sin(angle) * distance,
            height,
            -distance
        ]
        
        // Target area varies by difficulty
        let targetRange: Float = {
            switch difficulty {
            case .easy: return 0.4     // Larger target area
            case .medium: return 0.3   // Medium target area
            case .hard: return 0.3     // Standard target area
            case .expert: return 0.2   // Smaller target area
            }
        }()
        
        let targetX = Float.random(in: -targetRange...targetRange)
        let targetY = Float.random(in: 1.4...1.7)
        let targetZ: Float = 0.1
        let target = SIMD3<Float>(targetX, targetY, targetZ)
        
        // Calculate direction vector
        let direction = normalize(target - ball.position)
        
        // Apply speed with modifiers
        var speed = difficulty.ballSpeed
        if ball.ballType == .speed {
            let speedMultiplier: Float = {
                switch difficulty {
                case .easy: return 1.3     // 30% faster
                case .medium: return 1.5   // 50% faster
                case .hard: return 1.7     // 70% faster
                case .expert: return 2.0   // 100% faster (double speed!)
                }
            }()
            speed *= speedMultiplier
        }
        ball.velocity = direction * speed
        
        // Add to scene
        gameSpace.addChild(ball)
        activeBalls.append(ball)
        
        let reactionTime = distance / speed
        print("🏀 Ball \(ball.ballID) - Speed: \(String(format: "%.1f", speed)) m/s, ~\(String(format: "%.2f", reactionTime))s to react")
        
        // Play spawn sound
        audioController.playSpawnSound(at: ball.position)
    }
    
    private func createBall() -> BallEntity {
        let ball = BallEntity()
        ball.ballID = nextBallID
        nextBallID += 1
        ball.spawnTime = CACurrentMediaTime()
        
        // Determine ball type based on probability
        let typeRoll = Float.random(in: 0...1)
        if typeRoll < 0.1 {  // 10% avoid balls
            ball.ballType = .avoid
            ball.color = .black
            ball.points = -10
        } else if typeRoll < 0.2 {  // 10% speed balls
            ball.ballType = .speed
            ball.color = .red
            ball.points = 15
        } else if typeRoll < 0.35 {  // 15% bonus balls
            ball.ballType = .bonus
            ball.color = .systemYellow
            ball.points = 20
        } else {  // 65% standard balls
            ball.ballType = .standard
            ball.color = .systemBlue
            ball.points = 10
        }
        
        // Random size within difficulty range
        ball.size = Float.random(in: difficulty.ballSizeRange)
        
        // Create visual representation
        let mesh = MeshResource.generateSphere(radius: ball.size)
        var material = SimpleMaterial()
        material.color = .init(tint: ball.color)
        
        if ball.ballType == .bonus {
            material.metallic = 0.8
            material.roughness = 0.2
        }
        
        let modelEntity = ModelEntity(mesh: mesh, materials: [material])
        ball.addChild(modelEntity)
        
        // Add glow effect for special balls
        if ball.ballType == .bonus || ball.ballType == .speed {
            addGlowEffect(to: ball)
        }
        
        // Apply speed modifier for speed balls
        if ball.ballType == .speed {
            // Speed modifier will be applied when setting velocity
        }
        
        return ball
    }
    
    private func addGlowEffect(to ball: BallEntity) {
        // Create outer glow sphere
        let glowMesh = MeshResource.generateSphere(radius: ball.size * 1.2)
        var glowMaterial = SimpleMaterial()
        glowMaterial.color = .init(tint: ball.color.withAlphaComponent(0.3))
        glowMaterial.metallic = 0
        
        let glowEntity = ModelEntity(mesh: glowMesh, materials: [glowMaterial])
        ball.addChild(glowEntity)
    }
    
    private func updateBallPhysics() {
        guard isGameActive && !isPaused else { return }
        
        let deltaTime: Float = 1.0/90.0  // 90 FPS for smooth physics
        var ballsToRemove: [BallEntity] = []
        
        for ball in activeBalls where !ball.isCaught {
            // Update position based on velocity
            ball.position = ball.position + (ball.velocity * deltaTime)
            
            // Light gravity to keep natural trajectory
            ball.velocity.y -= 0.3 * deltaTime
            
            // Check if ball passed the player or went out of bounds
            if ball.position.z > 0.8 {  // Passed behind player
                ballsToRemove.append(ball)
                missedCount += 1
                streak = 0
                audioController.playMissSound()
                print("❌ Ball \(ball.ballID) missed - passed player")
            } else if ball.position.y < 0.8 {  // Too low (below waist)
                ballsToRemove.append(ball)
                missedCount += 1
                streak = 0
                print("❌ Ball \(ball.ballID) fell too low")
            } else if abs(ball.position.x) > 4 {  // Too far sideways
                ballsToRemove.append(ball)
                print("❌ Ball \(ball.ballID) out of bounds laterally")
            }
            
            // Add rotation for visual effect
            let rotation = simd_quatf(angle: Float(elapsedTime) * 3, axis: [0, 1, 0])
            if let modelChild = ball.children.first {
                modelChild.orientation = rotation
            }
        }
        
        // Remove out of bounds balls
        for ball in ballsToRemove {
            ball.removeFromParent()
            activeBalls.removeAll { $0.ballID == ball.ballID }
        }
    }
    
    // MARK: - Collision Detection
    
    private func checkHandCollisions() {
        guard isGameActive && !isPaused else { return }
        
        let currentTime = CACurrentMediaTime()
        
        // Collision radius varies by difficulty
        let catchRadius: Float = {
            switch difficulty {
            case .easy: return 0.15     // 15cm - more forgiving
            case .medium: return 0.13   // 13cm - moderate
            case .hard: return 0.11     // 11cm - precise
            case .expert: return 0.09   // 9cm - very precise
            }
        }()
        
        for ball in activeBalls where !ball.isCaught {
            var ballCaught = false
            
            // Check left hand collision
            if let leftPos = leftHandPosition {
                let distance = simd_distance(ball.position, leftPos)
                if distance < catchRadius {
                    print("🎯 LEFT HAND catch! Distance: \(String(format: "%.3f", distance))m")
                    catchBall(ball, withHand: .left, at: leftPos, time: currentTime)
                    ballCaught = true
                }
            }
            
            // Check right hand collision
            if !ballCaught, let rightPos = rightHandPosition {
                let distance = simd_distance(ball.position, rightPos)
                if distance < catchRadius {
                    print("🎯 RIGHT HAND catch! Distance: \(String(format: "%.3f", distance))m")
                    catchBall(ball, withHand: .right, at: rightPos, time: currentTime)
                }
            }
        }
    }
    
    private func catchBall(_ ball: BallEntity, withHand hand: ReactionTimeData.HandSide, at position: SIMD3<Float>, time: TimeInterval) {
        guard !ball.isCaught else { return } // Prevent double-catching
        ball.isCaught = true
        
        // Calculate reaction time
        let reactionTime = time - ball.spawnTime
        
        // Record catch data
        let reactionData = ReactionTimeData(
            ballID: ball.ballID,
            reactionTime: reactionTime,
            ballType: ball.ballType,
            distance: simd_distance(ball.position, position),
            success: true,
            hand: hand
        )
        reactionTimes.append(reactionData)
        
        let catchPos = CatchPosition(
            position: position,
            time: time,
            accuracy: simd_distance(ball.position, position)
        )
        catchPositions.append(catchPos)
        
        // Update score with combo multiplier
        let points = ball.points * comboMultiplier
        score += points
        
        if ball.ballType != .avoid {
            streak += 1
        } else {
            streak = 0  // Reset streak for avoid balls
        }
        
        // Visual feedback
        showCatchEffect(at: ball.position, points: points)
        
        // Audio feedback
        audioController.playCatchSound()
        
        print("✅ Ball \(ball.ballID) caught! Points: \(points), Reaction: \(String(format: "%.2f", reactionTime))s")
        
        // Remove ball with a small delay to show catch effect
        Task {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second delay
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
    
    private func showCatchEffect(at position: SIMD3<Float>, points: Int) {
        // In production, create particle effect or animation
        print("Caught! +\(points) points")
    }
    
    // MARK: - Hand Tracking
    
    private func startHandTracking() {
        print("🖐️ Starting hand tracking...")
        handTrackingTask = Task {
            do {
                // Request hand tracking authorization
                let authorizationResult = try await arkitSession.requestAuthorization(for: [.handTracking])
                
                guard authorizationResult[.handTracking] == .allowed else {
                    print("❌ Hand tracking not authorized")
                    await MainActor.run {
                        handTrackingActive = false
                    }
                    return
                }
                
                print("✅ Hand tracking authorized, starting session...")
                try await arkitSession.run([handTracking])
                
                await MainActor.run {
                    handTrackingActive = true
                    print("✅ Hand tracking session started successfully")
                }
                
                for await update in handTracking.anchorUpdates {
                    guard let handAnchor = update.anchor as? HandAnchor else { continue }
                    
                    await MainActor.run {
                        processHandUpdate(handAnchor)
                    }
                }
            } catch {
                print("❌ Hand tracking error: \(error)")
                await MainActor.run {
                    handTrackingActive = false
                }
            }
        }
    }
    
    private func processHandUpdate(_ anchor: HandAnchor) {
        // Get multiple hand joints for better collision detection
        guard let skeleton = anchor.handSkeleton else { return }
        
        // Get palm center (middle finger base) - joint() returns non-optional
        let palmJoint = skeleton.joint(.middleFingerMetacarpal)
        let palmTransform = anchor.originFromAnchorTransform * palmJoint.anchorFromJointTransform
        let palmPosition = SIMD3<Float>(
            palmTransform.columns.3.x,
            palmTransform.columns.3.y,
            palmTransform.columns.3.z
        )
        
        if anchor.chirality == .left {
            leftHandPosition = palmPosition
            leftHandOpen = true
        } else {
            rightHandPosition = palmPosition
            rightHandOpen = true
        }
        
        // Reduced debug output - only every 5 seconds
        if Int(CACurrentMediaTime()) % 5 == 0 {
            print("🖐️ \(anchor.chirality == .left ? "Left" : "Right") hand: \(palmPosition)")
        }
    }
    
    private func isHandOpen(_ skeleton: HandSkeleton?) -> Bool {
        // Simplified version - just return true since collision detection
        // will handle the actual catching logic
        return true
    }
    
    private func stopHandTracking() {
        print("🛑 Stopping hand tracking...")
        handTrackingTask?.cancel()
        handTrackingTask = nil
        handTrackingActive = false
    }
    
    // MARK: - Helper Functions
    
    private func createSpawnZones(in parent: Entity) {
        // Create subtle visual indicators for spawn zones at eye level
        let zoneMaterial = SimpleMaterial(color: UIColor.cyan.withAlphaComponent(0.1), isMetallic: false)
        
        // Create spawn zone indicators at proper height
        for angle in stride(from: -Float.pi/6, through: Float.pi/6, by: Float.pi/12) {
            let marker = ModelEntity(
                mesh: .generateSphere(radius: 0.05),
                materials: [zoneMaterial]
            )
            marker.position = [
                sin(angle) * 4,  // 4 meters away
                1.6,             // Eye level
                -4               // In front
            ]
            parent.addChild(marker)
        }
        
        // Add a reference plane at eye level (optional, for debugging)
        let referencePlane = ModelEntity(
            mesh: .generatePlane(width: 2, depth: 0.01),
            materials: [SimpleMaterial(color: UIColor.green.withAlphaComponent(0.05), isMetallic: false)]
        )
        referencePlane.position = [0, 1.6, -2]  // Eye level, 2m in front
        referencePlane.orientation = simd_quatf(angle: .pi/2, axis: [1, 0, 0])  // Make it vertical
        parent.addChild(referencePlane)
    }
    
    private func findGameSpace() -> Entity? {
        // In production, properly track the game space entity
        return activeBalls.first?.parent
    }
    
    private func calculateResults() {
        let totalBalls = reactionTimes.count + missedCount
        let catchRate = Float(reactionTimes.count) / Float(max(1, totalBalls))
        
        let avgReaction = reactionTimes.isEmpty ? 0 :
            reactionTimes.map { $0.reactionTime }.reduce(0, +) / Double(reactionTimes.count)
        
        let fastest = reactionTimes.map { $0.reactionTime }.min() ?? 0
        let slowest = reactionTimes.map { $0.reactionTime }.max() ?? 0
        
        let avgAccuracy = catchPositions.isEmpty ? 0 :
            catchPositions.map { $0.accuracy }.reduce(0, +) / Float(catchPositions.count)
        
        // Determine dominant hand
        let leftCatches = reactionTimes.filter { $0.hand == .left }.count
        let rightCatches = reactionTimes.filter { $0.hand == .right }.count
        let dominantHand: ReactionTimeData.HandSide =
            leftCatches > rightCatches ? .left :
            rightCatches > leftCatches ? .right : .both
        
        sessionResults = SessionResults(
            duration: elapsedTime,
            totalScore: score,
            ballsCaught: reactionTimes.count,
            ballsMissed: missedCount,
            averageReactionTime: avgReaction,
            fastestReaction: fastest,
            slowestReaction: slowest,
            catchAccuracy: avgAccuracy,
            dominantHand: dominantHand,
            difficulty: difficulty.rawValue
        )
    }
    
    private func getPerformanceAssessment(_ results: SessionResults) -> String {
        var assessment = ""
        
        // Reaction time assessment
        if results.averageReactionTime < 0.5 {
            assessment += "Excellent reaction time! "
        } else if results.averageReactionTime < 0.7 {
            assessment += "Good reaction time. "
        } else if results.averageReactionTime < 1.0 {
            assessment += "Average reaction time. "
        } else {
            assessment += "Reaction time could be improved. "
        }
        
        // Accuracy assessment
        let catchRate = Float(results.ballsCaught) / Float(max(1, results.ballsCaught + results.ballsMissed)) * 100
        if catchRate > 80 {
            assessment += "Outstanding catch accuracy! "
        } else if catchRate > 60 {
            assessment += "Good hand-eye coordination. "
        } else {
            assessment += "Practice may improve coordination. "
        }
        
        // Hand dominance observation
        switch results.dominantHand {
        case .left:
            assessment += "Left hand dominant (\(Int(catchRate))% success rate). "
        case .right:
            assessment += "Right hand dominant (\(Int(catchRate))% success rate). "
        case .both:
            assessment += "Balanced bilateral coordination. "
        }
        
        // Spatial accuracy
        if results.catchAccuracy < 0.05 {
            assessment += "Excellent spatial accuracy."
        } else if results.catchAccuracy < 0.10 {
            assessment += "Good spatial judgment."
        } else {
            assessment += "Spatial accuracy can be refined with practice."
        }
        
        // Clinical relevance
        if results.averageReactionTime > 1.0 || catchRate < 50 {
            assessment += "\n\nConsider evaluating: visual processing speed, depth perception, and motor planning. "
            assessment += "These metrics may indicate visual-motor integration challenges."
        }
        
        return assessment
    }
}