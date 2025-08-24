import SwiftUI
import RealityKit
import RealityKitContent
import ARKit
import Charts

struct RiskFactorAnalysisView: View {
    // Test phases
    @State private var currentPhase: TestPhase = .setup
    @State private var isTestActive = false
    @State private var phaseStartTime: TimeInterval = 0
    @State private var totalTestTime: TimeInterval = 0
    
    // Landmark management
    @State private var landmarks: [LandmarkEntity] = []
    @State private var visitedLandmarks: Set<Int> = []
    @State private var landmarkSequence: [Int] = []
    @State private var currentTargetIndex = 0
    @State private var rootEntity: Entity?
    
    // Navigation tracking
    @State private var userPath: [PathPoint] = []
    @State private var heatmapData: [[Float]] = []
    @State private var currentPosition: SIMD3<Float> = .zero
    @State private var previousPosition: SIMD3<Float>?
    @State private var totalDistance: Float = 0
    
    // Memory test data
    @State private var recallAttempts: [RecallAttempt] = []
    @State private var navigationErrors = 0
    @State private var correctSequence = 0
    @State private var showResults = false
    @State private var sessionResults: SessionResults?
    
    // ARKit tracking
    @State private var arkitSession = ARKitSession()
    @State private var worldTracking = WorldTrackingProvider()
    @State private var sceneReconstruction = SceneReconstructionProvider()
    @State private var trackingTask: Task<Void, Never>?
    
    // Test configuration
    @State private var difficulty: Difficulty = .medium
    @State private var navigationMode: NavigationMode = .physical
    @State private var showHeatmap = false
    @State private var showPath = true
    
    enum TestPhase: String {
        case setup = "Setup"
        case exploration = "Exploration"
        case learning = "Learning"
        case recall = "Recall"
        case navigation = "Navigation"
        case completed = "Completed"
        
        var instruction: String {
            switch self {
            case .setup:
                return "Landmarks will be placed around your space"
            case .exploration:
                return "Explore and observe all landmarks freely"
            case .learning:
                return "Visit landmarks in the shown sequence"
            case .recall:
                return "Recall the landmark sequence"
            case .navigation:
                return "Navigate to landmarks in order from memory"
            case .completed:
                return "Test completed"
            }
        }
        
        var timeLimit: TimeInterval {
            switch self {
            case .exploration: return 60
            case .learning: return 90
            case .recall: return 60
            case .navigation: return 120
            default: return 0
            }
        }
    }
    
    enum Difficulty: String, CaseIterable {
        case easy = "Easy"
        case medium = "Medium"
        case hard = "Hard"
        
        var landmarkCount: Int {
            switch self {
            case .easy: return 4
            case .medium: return 6
            case .hard: return 8
            }
        }
        
        var sequenceLength: Int {
            switch self {
            case .easy: return 3
            case .medium: return 5
            case .hard: return 7
            }
        }
        
        var showSequenceTime: TimeInterval {
            switch self {
            case .easy: return 3.0
            case .medium: return 2.0
            case .hard: return 1.5
            }
        }
    }
    
    enum NavigationMode: String, CaseIterable {
        case physical = "Physical Walking"
        case pointing = "Point & Teleport"
        case gaze = "Gaze Navigation"
    }
    
    class LandmarkEntity: Entity {
        var landmarkID: Int = 0
        var landmarkName: String = ""
        var landmarkIcon: String = ""
        var position3D: SIMD3<Float> = .zero
        var isLandmarkActive = false
        var isTarget = false
        var visitCount = 0
        var firstVisitTime: TimeInterval?
        var lastVisitTime: TimeInterval?
        var originalMaterials: [RealityKit.Material] = []
        
        func activate() {
            isLandmarkActive = true
            updateAppearance()
        }
        
        func setAsTarget(_ target: Bool) {
            isTarget = target
            updateAppearance()
        }
        
        private func updateAppearance() {
            // Update all child model entities
            for child in children {
                if let model = child as? ModelEntity {
                    var material = SimpleMaterial()
                    
                    if isTarget {
                        // Bright green for targets with enhanced visibility
                        material.color = .init(tint: .systemGreen)
                        material.metallic = 1.0
                        material.roughness = 0.0
                        
                        // Simple scale animation without complex repeat modes
                        let scaleUp = Transform(scale: .init(1.3, 1.3, 1.3), rotation: model.transform.rotation, translation: model.transform.translation)
                        model.move(to: scaleUp, relativeTo: model.parent, duration: 0.5)
                        
                        // Scale back down after a delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            let scaleDown = Transform(scale: .init(1.0, 1.0, 1.0), rotation: model.transform.rotation, translation: model.transform.translation)
                            model.move(to: scaleDown, relativeTo: model.parent, duration: 0.5)
                        }
                        
                    } else if isLandmarkActive {
                        // Bright blue for visited/active landmarks
                        material.color = .init(tint: .systemBlue)
                        material.metallic = 0.8
                        material.roughness = 0.2
                    } else {
                        // Restore original appearance
                        material.color = .init(tint: .gray)
                        material.metallic = 0.3
                        material.roughness = 0.7
                    }
                    
                    model.model?.materials = [material]
                }
            }
            
            // Update text background color
            for child in children {
                if child.position.y > 0.5 { // Text background
                    if let model = child as? ModelEntity {
                        var bgMaterial = SimpleMaterial()
                        if isTarget {
                            bgMaterial.color = .init(tint: .systemGreen)
                            bgMaterial.metallic = 0.8
                        } else if isLandmarkActive {
                            bgMaterial.color = .init(tint: .systemBlue)
                            bgMaterial.metallic = 0.5
                        } else {
                            bgMaterial.color = .init(tint: .white)
                            bgMaterial.metallic = 0.0
                        }
                        model.model?.materials = [bgMaterial]
                    }
                }
            }
        }
    }
    
    struct PathPoint {
        let position: SIMD3<Float>
        let timestamp: TimeInterval
        let phase: TestPhase
    }
    
    struct RecallAttempt {
        let landmarkID: Int
        let correct: Bool
        let responseTime: TimeInterval
        let attemptNumber: Int
    }
    
    struct SessionResults {
        let totalTime: TimeInterval
        let explorationEfficiency: Float  // Path optimality
        let memoryAccuracy: Float  // Recall success rate
        let navigationAccuracy: Float  // Navigation error rate
        let spatialCoverage: Float  // Area explored
        let sequenceScore: Int
        let totalDistance: Float
        let averageResponseTime: TimeInterval
        let heatmapData: [[Float]]
        let difficulty: String
    }
    
    var body: some View {
        RealityView { content, attachments in
            // Create root for landmarks
            let root = Entity()
            root.name = "LandmarkRoot"
            rootEntity = root
            content.add(root)
            
            // Setup room boundaries visualization
            setupRoomBoundaries(in: root)
            
            // Add control panel
            if let controlPanel = attachments.entity(for: "controlPanel") {
                let anchor = AnchorEntity(.head)
                controlPanel.position = [0, -0.3, -1.5]
                controlPanel.components.set(BillboardComponent())
                anchor.addChild(controlPanel)
                content.add(anchor)
            }
            
            // Add phase display
            if let phasePanel = attachments.entity(for: "phasePanel") {
                let anchor = AnchorEntity(.head)
                phasePanel.position = [0, 0.4, -2.0]
                phasePanel.components.set(BillboardComponent())
                anchor.addChild(phasePanel)
                content.add(anchor)
            }
            
            // Add minimap
            if let minimap = attachments.entity(for: "minimap") {
                let anchor = AnchorEntity(.head)
                minimap.position = [0.7, 0.2, -1.2]
                minimap.components.set(BillboardComponent())
                anchor.addChild(minimap)
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
            
        } update: { content, attachments in
            // Update landmarks and path visualization
            if isTestActive {
                updateVisualization()
            }
            
        } attachments: {
            // Control Panel
            Attachment(id: "controlPanel") {
                VStack(spacing: 15) {
                    Text("Spatial Memory Test")
                        .font(.title2)
                        .bold()
                    
                    if currentPhase == .setup {
                        // Pre-test configuration
                        VStack(spacing: 12) {
                            Text("Difficulty")
                                .font(.headline)
                            Picker("", selection: $difficulty) {
                                ForEach(Difficulty.allCases, id: \.self) { level in
                                    Text(level.rawValue).tag(level)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            
                            Text("Navigation Mode")
                                .font(.headline)
                            Picker("", selection: $navigationMode) {
                                ForEach(NavigationMode.allCases, id: \.self) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Test includes:")
                                    .font(.caption)
                                Text("• \(difficulty.landmarkCount) landmarks")
                                Text("• \(difficulty.sequenceLength) item sequence")
                                Text("• 4 phases: Explore, Learn, Recall, Navigate")
                            }
                            .font(.caption)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                            
                            Button(action: startTest) {
                                Label("Start Test", systemImage: "play.fill")
                                    .frame(width: 200)
                                    .padding()
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                        }
                    } else if isTestActive {
                        // During test
                        VStack(spacing: 10) {
                            // Timer for current phase
                            if currentPhase.timeLimit > 0 {
                                let elapsed = CACurrentMediaTime() - phaseStartTime
                                let remaining = max(0, currentPhase.timeLimit - elapsed)
                                
                                ZStack {
                                    Circle()
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 6)
                                        .frame(width: 60, height: 60)
                                    
                                    Circle()
                                        .trim(from: 0, to: CGFloat(1 - remaining / currentPhase.timeLimit))
                                        .stroke(Color.blue, lineWidth: 6)
                                        .frame(width: 60, height: 60)
                                        .rotationEffect(.degrees(-90))
                                    
                                    Text(String(format: "%.0f", remaining))
                                        .font(.title3)
                                        .monospacedDigit()
                                }
                            }
                            
                            // Phase-specific controls
                            phaseControls
                            
                            HStack(spacing: 15) {
                                Button("Skip Phase") {
                                    nextPhase()
                                }
                                .padding(8)
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                                
                                Button("End Test") {
                                    endTest()
                                }
                                .padding(8)
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                        }
                    }
                }
                .padding()
                .frame(width: 320)
                .background(.regularMaterial)
                .cornerRadius(15)
            }
            
            // Phase Display Panel
            Attachment(id: "phasePanel") {
                if isTestActive {
                    VStack(spacing: 8) {
                        Text(currentPhase.rawValue)
                            .font(.title2)
                            .bold()
                        
                        Text(currentPhase.instruction)
                            .font(.body)
                            .multilineTextAlignment(.center)
                        
                        if currentPhase == .learning || currentPhase == .navigation {
                            // Show sequence progress
                            HStack(spacing: 8) {
                                ForEach(0..<landmarkSequence.count, id: \.self) { index in
                                    Circle()
                                        .fill(index < currentTargetIndex ? Color.green :
                                              index == currentTargetIndex ? Color.blue : Color.gray)
                                        .frame(width: 12, height: 12)
                                }
                            }
                        }
                        
                        if currentPhase == .navigation {
                            Text("Target: \(getCurrentTargetName())")
                                .font(.headline)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                } else {
                    EmptyView()
                }
            }
            
            // Minimap
            Attachment(id: "minimap") {
                if isTestActive && showPath {
                    VStack {
                        Text("Map")
                            .font(.caption)
                            .bold()
                        
                        ZStack {
                            // Background
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black.opacity(0.8))
                                .frame(width: 150, height: 150)
                            
                            // Room bounds
                            Rectangle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                .frame(width: 140, height: 140)
                            
                            // Landmarks on minimap
                            ForEach(landmarks, id: \.landmarkID) { landmark in
                                Circle()
                                    .fill(landmark.isTarget ? Color.green :
                                          landmark.isLandmarkActive ? Color.blue : Color.gray)
                                    .frame(width: 8, height: 8)
                                    .position(minimapPosition(for: landmark.position3D))
                            }
                            
                            // User position
                            Image(systemName: "location.fill")
                                .foregroundColor(.yellow)
                                .font(.system(size: 12))
                                .position(minimapPosition(for: currentPosition))
                            
                            // Path trail (last 20 points)
                            if userPath.count > 1 {
                                Path { path in
                                    let recentPath = Array(userPath.suffix(20))
                                    guard let first = recentPath.first else { return }
                                    
                                    path.move(to: minimapPosition(for: first.position))
                                    for point in recentPath.dropFirst() {
                                        path.addLine(to: minimapPosition(for: point.position))
                                    }
                                }
                                .stroke(Color.yellow.opacity(0.5), lineWidth: 1)
                            }
                        }
                        .frame(width: 150, height: 150)
                        
                        // Stats
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Distance: \(String(format: "%.1f m", totalDistance))")
                            Text("Visited: \(visitedLandmarks.count)/\(landmarks.count)")
                            if currentPhase == .navigation {
                                Text("Correct: \(correctSequence)/\(landmarkSequence.count)")
                            }
                        }
                        .font(.caption2)
                    }
                    .padding()
                    .background(.regularMaterial)
                    .cornerRadius(12)
                } else {
                    EmptyView()
                }
            }
            
            // Results Panel
            Attachment(id: "resultsPanel") {
                if showResults, let results = sessionResults {
                    VStack(spacing: 15) {
                        Text("Test Results")
                            .font(.title)
                            .bold()
                        
                        // Performance metrics
                        VStack(spacing: 12) {
                            // Memory performance
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Memory Performance")
                                    .font(.headline)
                                
                                ProgressView(value: results.memoryAccuracy)
                                    .tint(results.memoryAccuracy > 0.7 ? .green : .orange)
                                Text("Accuracy: \(Int(results.memoryAccuracy * 100))%")
                                    .font(.caption)
                                
                                Text("Sequence Score: \(results.sequenceScore)/\(difficulty.sequenceLength)")
                                    .font(.caption)
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            
                            // Navigation performance
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Navigation Performance")
                                    .font(.headline)
                                
                                Grid(alignment: .leading) {
                                    GridRow {
                                        Text("Total Distance:")
                                        Text(String(format: "%.1f meters", results.totalDistance))
                                    }
                                    GridRow {
                                        Text("Efficiency:")
                                        Text(String(format: "%.0f%%", results.explorationEfficiency * 100))
                                            .foregroundColor(efficiencyColor(results.explorationEfficiency))
                                    }
                                    GridRow {
                                        Text("Coverage:")
                                        Text(String(format: "%.0f%%", results.spatialCoverage * 100))
                                    }
                                    GridRow {
                                        Text("Avg Response:")
                                        Text(String(format: "%.1f sec", results.averageResponseTime))
                                    }
                                }
                                .font(.caption)
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            
                            // Heatmap visualization
                            if showHeatmap {
                                VStack {
                                    Text("Movement Heatmap")
                                        .font(.headline)
                                    
                                    // Simple heatmap visualization
                                    HeatmapView(data: results.heatmapData)
                                        .frame(width: 200, height: 200)
                                }
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                        
                        // Clinical assessment
                        Text(getClinicalAssessment(results))
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        
                        HStack(spacing: 20) {
                            Button("Export Data") {
                                exportResults(results)
                            }
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            
                            Button("Close") {
                                resetTest()
                                showResults = false
                            }
                            .padding()
                            .background(Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                    .padding()
                    .frame(width: 500)
                    .background(.regularMaterial)
                    .cornerRadius(20)
                } else {
                    EmptyView()
                }
            }
        }
        .onAppear {
            startTracking()
        }
        .onDisappear {
            stopTracking()
        }
    }
    
    // MARK: - Test Control
    
    private func startTest() {
        isTestActive = true
        currentPhase = .setup
        totalTestTime = 0
        userPath.removeAll()
        visitedLandmarks.removeAll()
        recallAttempts.removeAll()
        
        // Place landmarks
        placeLandmarks()
        
        // Generate random sequence
        generateLandmarkSequence()
        
        // Start exploration phase
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            currentPhase = .exploration
            phaseStartTime = CACurrentMediaTime()
            startPhaseTimer()
        }
    }
    
    private func nextPhase() {
        switch currentPhase {
        case .exploration:
            currentPhase = .learning
            showLearningSequence()
        case .learning:
            currentPhase = .recall
        case .recall:
            currentPhase = .navigation
            currentTargetIndex = 0
            highlightCurrentTarget()
        case .navigation:
            currentPhase = .completed
            endTest()
        default:
            break
        }
        
        phaseStartTime = CACurrentMediaTime()
        startPhaseTimer()
    }
    
    private func endTest() {
        isTestActive = false
        calculateResults()
        showResults = true
    }
    
    private func resetTest() {
        currentPhase = .setup
        landmarks.removeAll()
        landmarkSequence.removeAll()
        userPath.removeAll()
        visitedLandmarks.removeAll()
        currentTargetIndex = 0
        totalDistance = 0
        navigationErrors = 0
        correctSequence = 0
    }
    
    // MARK: - Landmark Management
    
    private func placeLandmarks() {
        guard let root = rootEntity else { return }
        
        // Clear existing landmarks
        for landmark in landmarks {
            landmark.removeFromParent()
        }
        landmarks.removeAll()
        
        let landmarkData = [
            ("House", "house.fill", UIColor.systemBlue),
            ("Tree", "tree.fill", UIColor.systemGreen),
            ("Car", "car.fill", UIColor.systemRed),
            ("Star", "star.fill", UIColor.systemYellow),
            ("Heart", "heart.fill", UIColor.systemPink),
            ("Flag", "flag.fill", UIColor.systemOrange),
            ("Bell", "bell.fill", UIColor.systemPurple),
            ("Book", "book.fill", UIColor.systemBrown)
        ]
        
        // Place landmarks in a circular pattern around the user
        let count = difficulty.landmarkCount
        for i in 0..<count {
            let angle = Float(i) * (2 * .pi / Float(count))
            let radius: Float = 2.5  // 2.5 meters from center
            
            let landmark = LandmarkEntity()
            landmark.landmarkID = i
            landmark.landmarkName = landmarkData[i].0
            landmark.landmarkIcon = landmarkData[i].1
            
            // Position around the user
            landmark.position = [
                sin(angle) * radius,
                1.0,  // 1 meter height
                cos(angle) * radius
            ]
            landmark.position3D = landmark.position
            
            // Create distinctive visual representation based on landmark type
            createLandmarkModel(for: landmark, data: landmarkData[i])
            
            // Add floating label with large, readable text
            addLandmarkLabel(to: landmark, text: landmarkData[i].0, color: landmarkData[i].2)
            
            // Add to scene
            root.addChild(landmark)
            landmarks.append(landmark)
        }
    }
    
    private func createLandmarkModel(for landmark: LandmarkEntity, data: (String, String, UIColor)) {
        let (name, _, color) = data
        
        var mesh: MeshResource
        var material = SimpleMaterial()
        material.color = .init(tint: color)
        material.metallic = 0.3
        material.roughness = 0.7
        
        // Create distinctive shapes for each landmark type
        switch name {
        case "House":
            // Create a house-like structure
            let base = MeshResource.generateBox(width: 0.4, height: 0.3, depth: 0.4)
            let roof = MeshResource.generateBox(width: 0.5, height: 0.2, depth: 0.5)
            
            let baseModel = ModelEntity(mesh: base, materials: [material])
            let roofModel = ModelEntity(mesh: roof, materials: [material])
            roofModel.position.y = 0.25
            
            landmark.addChild(baseModel)
            landmark.addChild(roofModel)
            
        case "Tree":
            // Create a tree-like structure
            let trunk = MeshResource.generateCylinder(height: 0.4, radius: 0.05)
            let trunkMaterial = SimpleMaterial(color: .brown, isMetallic: false)
            let trunkModel = ModelEntity(mesh: trunk, materials: [trunkMaterial])
            
            let leaves = MeshResource.generateSphere(radius: 0.2)
            let leavesModel = ModelEntity(mesh: leaves, materials: [material])
            leavesModel.position.y = 0.3
            
            landmark.addChild(trunkModel)
            landmark.addChild(leavesModel)
            
        case "Car":
            // Create a car-like structure
            let body = MeshResource.generateBox(width: 0.6, height: 0.2, depth: 0.3, cornerRadius: 0.05)
            let bodyModel = ModelEntity(mesh: body, materials: [material])
            
            // Add wheels
            let wheelMesh = MeshResource.generateCylinder(height: 0.05, radius: 0.08)
            let wheelMaterial = SimpleMaterial(color: .black, isMetallic: false)
            
            let positions: [SIMD3<Float>] = [
                [-0.2, -0.12, 0.12], [0.2, -0.12, 0.12],
                [-0.2, -0.12, -0.12], [0.2, -0.12, -0.12]
            ]
            
            for pos in positions {
                let wheel = ModelEntity(mesh: wheelMesh, materials: [wheelMaterial])
                wheel.position = pos
                wheel.transform.rotation = simd_quatf(angle: .pi/2, axis: [0, 0, 1])
                landmark.addChild(wheel)
            }
            
            landmark.addChild(bodyModel)
            
        case "Star":
            // Create a star-like structure using multiple triangular prisms
            mesh = MeshResource.generateBox(width: 0.4, height: 0.1, depth: 0.4)
            let starModel = ModelEntity(mesh: mesh, materials: [material])
            
            // Add star points
            for i in 0..<5 {
                let angle = Float(i) * (2 * .pi / 5)
                let pointMesh = MeshResource.generateBox(width: 0.1, height: 0.3, depth: 0.1)
                let point = ModelEntity(mesh: pointMesh, materials: [material])
                point.position = [sin(angle) * 0.2, 0.15, cos(angle) * 0.2]
                landmark.addChild(point)
            }
            
            landmark.addChild(starModel)
            
        case "Heart":
            // Create a heart-like structure using spheres
            let sphere1 = MeshResource.generateSphere(radius: 0.15)
            let sphere2 = MeshResource.generateSphere(radius: 0.15)
            let triangle = MeshResource.generateBox(width: 0.2, height: 0.15, depth: 0.1)
            
            let heart1 = ModelEntity(mesh: sphere1, materials: [material])
            let heart2 = ModelEntity(mesh: sphere2, materials: [material])
            let heartBottom = ModelEntity(mesh: triangle, materials: [material])
            
            heart1.position = [-0.1, 0.1, 0]
            heart2.position = [0.1, 0.1, 0]
            heartBottom.position = [0, -0.1, 0]
            
            landmark.addChild(heart1)
            landmark.addChild(heart2)
            landmark.addChild(heartBottom)
            
        case "Flag":
            // Create a flag-like structure
            let pole = MeshResource.generateCylinder(height: 0.6, radius: 0.02)
            let poleMaterial = SimpleMaterial(color: .brown, isMetallic: false)
            let poleModel = ModelEntity(mesh: pole, materials: [poleMaterial])
            
            let flag = MeshResource.generateBox(width: 0.3, height: 0.2, depth: 0.02)
            let flagModel = ModelEntity(mesh: flag, materials: [material])
            flagModel.position = [0.15, 0.2, 0]
            
            landmark.addChild(poleModel)
            landmark.addChild(flagModel)
            
        case "Bell":
            // Create a bell-like structure
            let bellBody = MeshResource.generateSphere(radius: 0.15)
            let bellTop = MeshResource.generateCylinder(height: 0.1, radius: 0.03)
            
            let bodyModel = ModelEntity(mesh: bellBody, materials: [material])
            let topModel = ModelEntity(mesh: bellTop, materials: [material])
            topModel.position.y = 0.2
            
            landmark.addChild(bodyModel)
            landmark.addChild(topModel)
            
        case "Book":
            // Create a book-like structure
            let book = MeshResource.generateBox(width: 0.3, height: 0.4, depth: 0.05)
            let bookModel = ModelEntity(mesh: book, materials: [material])
            bookModel.transform.rotation = simd_quatf(angle: .pi/6, axis: [1, 0, 0])
            
            landmark.addChild(bookModel)
            
        default:
            // Fallback to basic shape
            mesh = MeshResource.generateBox(width: 0.3, height: 0.5, depth: 0.3, cornerRadius: 0.05)
            let model = ModelEntity(mesh: mesh, materials: [material])
            landmark.addChild(model)
        }
    }
    
    private func addLandmarkLabel(to landmark: LandmarkEntity, text: String, color: UIColor) {
        // Create a large, readable text label
        let labelHeight: Float = 0.15
        let labelWidth = Float(text.count) * 0.08
        
        // Create background for text
        let backgroundMesh = MeshResource.generateBox(width: labelWidth + 0.1, height: labelHeight + 0.05, depth: 0.02, cornerRadius: 0.02)
        var backgroundMaterial = SimpleMaterial()
        backgroundMaterial.color = .init(tint: .white)
        backgroundMaterial.metallic = 0.0
        backgroundMaterial.roughness = 1.0
        
        let background = ModelEntity(mesh: backgroundMesh, materials: [backgroundMaterial])
        background.position = [0, 0.6, 0]
        
        // Create text mesh (simplified approach - in practice you'd use TextMeshResource)
        let textMesh = MeshResource.generateBox(width: labelWidth, height: labelHeight, depth: 0.01)
        var textMaterial = SimpleMaterial()
        textMaterial.color = .init(tint: color)
        textMaterial.metallic = 0.8
        
        let textModel = ModelEntity(mesh: textMesh, materials: [textMaterial])
        textModel.position = [0, 0.6, 0.015]
        
        // Add billboard behavior to always face the user
        background.components.set(BillboardComponent())
        textModel.components.set(BillboardComponent())
        
        landmark.addChild(background)
        landmark.addChild(textModel)
        
        // Add a floating name tag above
        let nameTag = Entity()
        nameTag.position = [0, 0.8, 0]
        nameTag.components.set(BillboardComponent())
        landmark.addChild(nameTag)
    }
    
    private func generateLandmarkSequence() {
        let availableIDs = Array(0..<difficulty.landmarkCount)
        landmarkSequence = Array(availableIDs.shuffled().prefix(difficulty.sequenceLength))
    }
    
    private func showLearningSequence() {
        // Animate landmarks in sequence
        for (index, landmarkID) in landmarkSequence.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * difficulty.showSequenceTime) {
                highlightLandmark(id: landmarkID)
                
                // Remove highlight after display time
                DispatchQueue.main.asyncAfter(deadline: .now() + difficulty.showSequenceTime * 0.8) {
                    unhighlightLandmark(id: landmarkID)
                }
            }
        }
    }
    
    private func highlightLandmark(id: Int) {
        guard id < landmarks.count else { return }
        landmarks[id].setAsTarget(true)
    }
    
    private func unhighlightLandmark(id: Int) {
        guard id < landmarks.count else { return }
        landmarks[id].setAsTarget(false)
    }
    
    private func highlightCurrentTarget() {
        guard currentTargetIndex < landmarkSequence.count else { return }
        let targetID = landmarkSequence[currentTargetIndex]
        
        // Clear all highlights
        for landmark in landmarks {
            landmark.setAsTarget(false)
        }
        
        // Highlight current target
        landmarks[targetID].setAsTarget(true)
    }
    
    // MARK: - Navigation & Tracking
    
    private func checkLandmarkProximity() {
        guard isTestActive else { return }
        
        for landmark in landmarks {
            let distance = simd_distance(currentPosition, landmark.position3D)
            
            if distance < 0.5 {  // Within 50cm
                if !visitedLandmarks.contains(landmark.landmarkID) {
                    visitedLandmarks.insert(landmark.landmarkID)
                    landmark.visitCount += 1
                    landmark.firstVisitTime = CACurrentMediaTime()
                    
                    if currentPhase == .navigation {
                        checkNavigationTarget(landmark)
                    }
                }
                
                landmark.lastVisitTime = CACurrentMediaTime()
            }
        }
    }
    
    private func checkNavigationTarget(_ landmark: LandmarkEntity) {
        guard currentTargetIndex < landmarkSequence.count else { return }
        
        let targetID = landmarkSequence[currentTargetIndex]
        
        if landmark.landmarkID == targetID {
            // Correct landmark!
            correctSequence += 1
            currentTargetIndex += 1
            
            if currentTargetIndex < landmarkSequence.count {
                highlightCurrentTarget()
            } else {
                // Completed sequence
                nextPhase()
            }
        } else {
            // Wrong landmark
            navigationErrors += 1
        }
    }
    
    private func updateVisualization() {
        // Update path
        if let prevPos = previousPosition {
            let distance = simd_distance(currentPosition, prevPos)
            if distance > 0.1 {  // Moved at least 10cm
                totalDistance += distance
                userPath.append(PathPoint(
                    position: currentPosition,
                    timestamp: CACurrentMediaTime(),
                    phase: currentPhase
                ))
                previousPosition = currentPosition
                
                // Update heatmap
                updateHeatmap(at: currentPosition)
            }
        } else {
            previousPosition = currentPosition
        }
        
        // Check landmark proximity
        checkLandmarkProximity()
    }
    
    private func updateHeatmap(at position: SIMD3<Float>) {
        // Simple grid-based heatmap (10x10)
        let gridSize = 10
        let roomSize: Float = 5.0  // 5x5 meter room
        
        // Convert position to grid coordinates
        let x = Int((position.x + roomSize/2) / roomSize * Float(gridSize))
        let z = Int((position.z + roomSize/2) / roomSize * Float(gridSize))
        
        // Ensure grid is initialized
        if heatmapData.isEmpty {
            heatmapData = Array(repeating: Array(repeating: 0, count: gridSize), count: gridSize)
        }
        
        // Increment visit count
        if x >= 0 && x < gridSize && z >= 0 && z < gridSize {
            heatmapData[z][x] += 1
        }
    }
    
    // MARK: - Phase Controls
    
    @ViewBuilder
    private var phaseControls: some View {
        switch currentPhase {
        case .exploration:
            VStack {
                Text("Explore all landmarks")
                    .font(.caption)
                Text("Visited: \(visitedLandmarks.count)/\(landmarks.count)")
                    .font(.headline)
            }
            
        case .learning:
            VStack {
                Text("Remember this sequence:")
                    .font(.caption)
                HStack {
                    ForEach(landmarkSequence, id: \.self) { id in
                        if id < landmarks.count {
                            Text(landmarks[id].landmarkName)
                                .font(.caption)
                                .padding(4)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                }
            }
            
        case .recall:
            VStack {
                Text("Select landmarks in order:")
                    .font(.caption)
                
                // Landmark buttons
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))]) {
                    ForEach(landmarks, id: \.landmarkID) { landmark in
                        Button(landmark.landmarkName) {
                            recordRecallAttempt(landmark.landmarkID)
                        }
                        .font(.caption)
                        .padding(6)
                        .background(recallAttempts.contains { $0.landmarkID == landmark.landmarkID } ?
                                   Color.green.opacity(0.3) : Color.blue.opacity(0.2))
                        .cornerRadius(6)
                    }
                }
            }
            
        case .navigation:
            VStack {
                Text("Navigate to targets")
                    .font(.caption)
                Text("Progress: \(correctSequence)/\(landmarkSequence.count)")
                    .font(.headline)
                if navigationErrors > 0 {
                    Text("Errors: \(navigationErrors)")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
        default:
            EmptyView()
        }
    }
    
    // MARK: - Helper Functions
    
    private func startPhaseTimer() {
        guard currentPhase.timeLimit > 0 else { return }
        
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            let elapsed = CACurrentMediaTime() - phaseStartTime
            
            if elapsed >= currentPhase.timeLimit {
                timer.invalidate()
                nextPhase()
            }
        }
    }
    
    private func recordRecallAttempt(_ landmarkID: Int) {
        let attempt = RecallAttempt(
            landmarkID: landmarkID,
            correct: landmarkSequence[recallAttempts.count] == landmarkID,
            responseTime: CACurrentMediaTime() - phaseStartTime,
            attemptNumber: recallAttempts.count
        )
        recallAttempts.append(attempt)
        
        if recallAttempts.count >= landmarkSequence.count {
            nextPhase()
        }
    }
    
    private func getCurrentTargetName() -> String {
        guard currentTargetIndex < landmarkSequence.count else { return "Complete" }
        let targetID = landmarkSequence[currentTargetIndex]
        return landmarks[targetID].landmarkName
    }
    
    private func minimapPosition(for worldPos: SIMD3<Float>) -> CGPoint {
        // Convert world position to minimap coordinates (150x150 view)
        let roomSize: Float = 5.0
        let mapSize: CGFloat = 140
        
        let x = CGFloat((worldPos.x + roomSize/2) / roomSize) * mapSize + 5
        let z = CGFloat((worldPos.z + roomSize/2) / roomSize) * mapSize + 5
        
        return CGPoint(x: x, y: z)
    }
    
    private func setupRoomBoundaries(in root: Entity) {
        // Create floor grid for spatial reference
        let gridSize: Float = 5.0
        let gridLines = 10
        let lineThickness: Float = 0.01
        
        let lineMaterial = SimpleMaterial(color: UIColor.white.withAlphaComponent(0.2), isMetallic: false)
        
        // Create grid lines
        for i in 0...gridLines {
            let offset = (Float(i) / Float(gridLines) - 0.5) * gridSize
            
            // X-direction lines
            let xLine = ModelEntity(
                mesh: .generateBox(width: gridSize, height: lineThickness, depth: lineThickness),
                materials: [lineMaterial]
            )
            xLine.position = [0, 0, offset]
            root.addChild(xLine)
            
            // Z-direction lines
            let zLine = ModelEntity(
                mesh: .generateBox(width: lineThickness, height: lineThickness, depth: gridSize),
                materials: [lineMaterial]
            )
            zLine.position = [offset, 0, 0]
            root.addChild(zLine)
        }
        
        // Add corner markers
        let cornerMaterial = SimpleMaterial(color: .systemBlue.withAlphaComponent(0.5), isMetallic: false)
        for x in [-1, 1] {
            for z in [-1, 1] {
                let corner = ModelEntity(
                    mesh: .generateBox(width: 0.1, height: 0.3, depth: 0.1),
                    materials: [cornerMaterial]
                )
                corner.position = [Float(x) * gridSize/2, 0.15, Float(z) * gridSize/2]
                root.addChild(corner)
            }
        }
    }
    
    // MARK: - Tracking
    
    private func startTracking() {
        trackingTask = Task {
            do {
                // Start ARKit session with world tracking and scene reconstruction
                try await arkitSession.run([worldTracking, sceneReconstruction])
                
                for await update in worldTracking.anchorUpdates {
                    guard let deviceAnchor = update.anchor as? DeviceAnchor else { continue }
                    
                    let transform = deviceAnchor.originFromAnchorTransform
                    let position = SIMD3<Float>(
                        transform.columns.3.x,
                        transform.columns.3.y,
                        transform.columns.3.z
                    )
                    
                    await MainActor.run {
                        currentPosition = position
                    }
                }
            } catch {
                print("Tracking error: \(error)")
            }
        }
    }
    
    private func stopTracking() {
        trackingTask?.cancel()
        trackingTask = nil
    }
    
    // MARK: - Results Calculation
    
    private func calculateResults() {
        totalTestTime = CACurrentMediaTime() - (phaseStartTime - currentPhase.timeLimit)
        
        // Calculate memory accuracy
        let correctRecalls = recallAttempts.filter { $0.correct }.count
        let memoryAccuracy = Float(correctRecalls) / Float(max(1, landmarkSequence.count))
        
        // Calculate navigation accuracy
        let navigationAccuracy = Float(correctSequence) / Float(max(1, landmarkSequence.count))
        
        // Calculate exploration efficiency (visited landmarks / total movement)
        let optimalDistance = Float(landmarks.count) * 2.0  // Rough estimate
        let explorationEfficiency = min(1.0, optimalDistance / max(1, totalDistance))
        
        // Calculate spatial coverage
        let visitedCells = heatmapData.flatMap { $0 }.filter { $0 > 0 }.count
        let totalCells = heatmapData.count * (heatmapData.first?.count ?? 0)
        let spatialCoverage = Float(visitedCells) / Float(max(1, totalCells))
        
        // Average response time
        let avgResponseTime = recallAttempts.isEmpty ? 0 :
            recallAttempts.map { $0.responseTime }.reduce(0, +) / Double(recallAttempts.count)
        
        sessionResults = SessionResults(
            totalTime: totalTestTime,
            explorationEfficiency: explorationEfficiency,
            memoryAccuracy: memoryAccuracy,
            navigationAccuracy: navigationAccuracy,
            spatialCoverage: spatialCoverage,
            sequenceScore: correctSequence,
            totalDistance: totalDistance,
            averageResponseTime: avgResponseTime,
            heatmapData: heatmapData,
            difficulty: difficulty.rawValue
        )
    }
    
    private func efficiencyColor(_ efficiency: Float) -> Color {
        if efficiency > 0.8 { return .green }
        if efficiency > 0.6 { return .yellow }
        return .red
    }
    
    private func getClinicalAssessment(_ results: SessionResults) -> String {
        var assessment = ""
        
        // Memory assessment
        if results.memoryAccuracy >= 0.8 {
            assessment += "Excellent spatial memory performance. "
        } else if results.memoryAccuracy >= 0.6 {
            assessment += "Good spatial memory with minor recall difficulties. "
        } else {
            assessment += "Significant spatial memory challenges observed. "
        }
        
        // Navigation assessment
        if results.navigationAccuracy >= 0.8 && results.explorationEfficiency >= 0.7 {
            assessment += "Strong spatial navigation and path planning abilities. "
        } else if results.navigationAccuracy >= 0.6 {
            assessment += "Adequate navigation with some inefficiencies. "
        } else {
            assessment += "Navigation difficulties suggest executive function or spatial processing issues. "
        }
        
        // Coverage assessment
        if results.spatialCoverage < 0.4 {
            assessment += "Limited spatial exploration may indicate anxiety or motor planning issues."
        }
        
        // Clinical recommendations
        if results.memoryAccuracy < 0.5 || results.navigationAccuracy < 0.5 {
            assessment += "\n\nRecommend comprehensive neuropsychological evaluation focusing on: "
            assessment += "visuospatial processing, executive function, and memory consolidation. "
            assessment += "Consider screening for mild cognitive impairment (MCI) or early dementia."
        }
        
        return assessment
    }
    
    private func exportResults(_ results: SessionResults) {
        // In production, implement CSV/JSON export
        print("Exporting results...")
        print("Memory Accuracy: \(results.memoryAccuracy)")
        print("Navigation Accuracy: \(results.navigationAccuracy)")
        print("Exploration Efficiency: \(results.explorationEfficiency)")
        print("Total Distance: \(results.totalDistance)")
        print("Spatial Coverage: \(results.spatialCoverage)")
    }
}

// MARK: - Supporting Views

struct HeatmapView: View {
    let data: [[Float]]
    
    var body: some View {
        GeometryReader { geometry in
            let rows = data.count
            let cols = data.first?.count ?? 0
            let cellWidth = geometry.size.width / CGFloat(cols)
            let cellHeight = geometry.size.height / CGFloat(rows)
            
            ForEach(0..<rows, id: \.self) { row in
                ForEach(0..<cols, id: \.self) { col in
                    Rectangle()
                        .fill(heatmapColor(value: data[row][col]))
                        .frame(width: cellWidth, height: cellHeight)
                        .position(
                            x: CGFloat(col) * cellWidth + cellWidth/2,
                            y: CGFloat(row) * cellHeight + cellHeight/2
                        )
                }
            }
        }
    }
    
    private func heatmapColor(value: Float) -> Color {
        let normalized = min(1.0, value / 10.0)  // Normalize to 0-1
        
        if normalized < 0.2 {
            return Color.blue.opacity(Double(normalized * 5))
        } else if normalized < 0.5 {
            return Color.green.opacity(Double(normalized * 2))
        } else if normalized < 0.8 {
            return Color.yellow.opacity(Double(normalized))
        } else {
            return Color.red.opacity(Double(normalized))
        }
    }
}
