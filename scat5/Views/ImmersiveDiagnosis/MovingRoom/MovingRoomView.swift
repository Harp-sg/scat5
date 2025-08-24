import SwiftUI
import RealityKit
import RealityKitContent
import Combine
import ARKit

struct MovingRoomView: View {
    @Environment(ViewRouter.self) private var viewRouter
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openWindow) private var openWindow
    @Environment(\.modelContext) private var modelContext
    
    @State private var roomEntity: Entity?
    @State private var isMoving = false
    @State private var startTime: TimeInterval = 0
    @State private var timer: Timer?
    
    // Movement parameters
    @State private var amplitude: Float = 0.1  // 10cm
    @State private var frequency: Float = 0.3  // 0.3 Hz
    @State private var movementAxis: MovementAxis = .forwardBack
    
    // Head tracking for balance detection
    @State private var arkitSession = ARKitSession()
    @State private var worldTracking = WorldTrackingProvider()
    @State private var headTrackingTask: Task<Void, Never>?
    @State private var initialHeadPosition: SIMD3<Float>?
    @State private var currentHeadPosition: SIMD3<Float> = .zero
    @State private var maxSway: Float = 0
    @State private var swayHistory: [SwayPoint] = []
    @State private var isRecordingSway = false
    
    struct SwayPoint {
        let time: TimeInterval
        let displacement: SIMD3<Float>
        let magnitude: Float
    }
    
    enum MovementAxis {
        case forwardBack  // Z axis
        case leftRight    // X axis
        case both         // Circular motion
    }
    
    var body: some View {
        RealityView { content, attachments in
            // Create the room in world space (not anchored to head)
            let room = createRoom()
            roomEntity = room
            // Position room at world origin
            room.position = [0, 0, 0]
            content.add(room)
            
            // Add control panel anchored to head so it follows the user
            if let controlPanel = attachments.entity(for: "controlPanel") {
                let panelAnchor = AnchorEntity(.head)
                controlPanel.position = [0, -0.3, -1.0]  // 1 meter in front, slightly below eye level
                controlPanel.components.set(BillboardComponent())  // Always face the camera
                panelAnchor.addChild(controlPanel)
                content.add(panelAnchor)
                print("Control panel added to scene")
            }
            
            print("Room created and added to scene")
            
        } update: { content, attachments in
            // This update closure is called when @State changes
            // But we'll use a timer for continuous movement
        } attachments: {
            // Attachment for the control panel
            Attachment(id: "controlPanel") {
                VStack(spacing: 20) {
                    HStack {
                        Text("Moving Room Control")
                            .font(.largeTitle)
                            .bold()
                        
                        Spacer()
                        
                        // Exit button
                        Button(action: exitTest) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.red)
                        }
                        .background(.ultraThinMaterial)
                        .cornerRadius(25)
                    }
                    
                    // Status indicator
                    HStack {
                        Circle()
                            .fill(isMoving ? Color.green : Color.red)
                            .frame(width: 20, height: 20)
                        Text(isMoving ? "MOVING" : "STOPPED")
                            .font(.headline)
                    }
                    
                    // Movement axis selector
                    Picker("Movement Axis", selection: $movementAxis) {
                        Text("Forward/Back").tag(MovementAxis.forwardBack)
                        Text("Left/Right").tag(MovementAxis.leftRight)
                        Text("Circular").tag(MovementAxis.both)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 400)
                    .disabled(isMoving)
                    
                    // Amplitude control
                    VStack {
                        Text("Amplitude: \(String(format: "%.1f cm", amplitude * 100))")
                        Slider(value: $amplitude, in: 0.05...0.3)
                            .frame(width: 300)
                            .disabled(isMoving)
                    }
                    
                    // Frequency control
                    VStack {
                        Text("Frequency: \(String(format: "%.2f Hz", frequency))")
                        Slider(value: $frequency, in: 0.1...1.0)
                            .frame(width: 300)
                            .disabled(isMoving)
                    }
                    
                    // Start/Stop button
                    Button(action: toggleMovement) {
                        Text(isMoving ? "Stop Movement" : "Start Movement")
                            .font(.title2)
                            .padding()
                            .frame(width: 250)
                            .background(isMoving ? Color.red : Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    
                    // Balance/Sway Monitoring Section
                    Divider()
                        .frame(width: 400)
                    
                    VStack(spacing: 10) {
                        Text("Balance Monitoring")
                            .font(.headline)
                        
                        if isRecordingSway {
                            // Real-time sway display
                            HStack(spacing: 20) {
                                VStack {
                                    Text("Forward/Back")
                                        .font(.caption)
                                    Text(String(format: "%.1f cm", abs(currentHeadPosition.z - (initialHeadPosition?.z ?? 0)) * 100))
                                        .font(.title3)
                                        .foregroundColor(abs(currentHeadPosition.z - (initialHeadPosition?.z ?? 0)) > 0.05 ? .orange : .green)
                                }
                                
                                VStack {
                                    Text("Left/Right")
                                        .font(.caption)
                                    Text(String(format: "%.1f cm", abs(currentHeadPosition.x - (initialHeadPosition?.x ?? 0)) * 100))
                                        .font(.title3)
                                        .foregroundColor(abs(currentHeadPosition.x - (initialHeadPosition?.x ?? 0)) > 0.05 ? .orange : .green)
                                }
                                
                                VStack {
                                    Text("Max Sway")
                                        .font(.caption)
                                    Text(String(format: "%.1f cm", maxSway * 100))
                                        .font(.title3)
                                        .foregroundColor(maxSway > 0.1 ? .red : (maxSway > 0.05 ? .orange : .green))
                                }
                            }
                            
                            // Visual sway indicator
                            ZStack {
                                Circle()
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                                    .frame(width: 100, height: 100)
                                
                                Circle()
                                    .stroke(Color.orange.opacity(0.3), lineWidth: 2)
                                    .frame(width: 50, height: 50)
                                
                                // Current position dot
                                Circle()
                                    .fill(swayColor)
                                    .frame(width: 10, height: 10)
                                    .offset(
                                        x: CGFloat((currentHeadPosition.x - (initialHeadPosition?.x ?? 0)) * 500),
                                        y: CGFloat(-(currentHeadPosition.z - (initialHeadPosition?.z ?? 0)) * 500)
                                    )
                            }
                            .frame(width: 100, height: 100)
                            
                            if maxSway > 0.15 {
                                Text("⚠️ High sway detected - visual motion affecting balance")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        } else if !swayHistory.isEmpty {
                            // Show summary after stopping
                            VStack {
                                Text("Last Session Summary")
                                    .font(.caption)
                                Text("Max Sway: \(String(format: "%.1f cm", maxSway * 100))")
                                    .font(.title3)
                                Text(swayAssessment)
                                    .font(.caption)
                                    .foregroundColor(swayAssessmentColor)
                            }
                        }
                    }
                    
                    // Debug info
                    if isMoving {
                        Text("Look straight ahead to measure balance")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    
                    // Exit button at bottom
                    Button(action: exitTest) {
                        HStack {
                            Image(systemName: "arrow.left.circle")
                            Text("Exit Moving Room Test")
                        }
                        .font(.title3)
                        .padding()
                        .frame(width: 300)
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                    }
                }
                .padding(30)
                .background(.regularMaterial)
                .cornerRadius(20)
                .frame(width: 500, height: 600)
            }
        }
        .onAppear {
            print("RealityView appeared")
            startHeadTracking()
        }
        .onDisappear {
            stopMovement()
            stopHeadTracking()
        }
    }
    
    // Exit function to dismiss immersive space
    private func exitTest() {
        Task {
            // Stop any ongoing movement first
            stopMovement()
            
            // Dismiss the immersive space
            await dismissImmersiveSpace()
            
            // Navigate back to Interactive Diagnosis or main dashboard
            viewRouter.currentView = .interactiveDiagnosis
            
            // Open the main window if needed
            openWindow(id: "main")
        }
    }
    
    // Computed properties for sway assessment
    private var swayColor: Color {
        let displacement = simd_length(currentHeadPosition - (initialHeadPosition ?? .zero))
        if displacement > 0.15 { return .red }
        if displacement > 0.05 { return .orange }
        return .green
    }
    
    private var swayAssessment: String {
        if maxSway < 0.03 { return "Excellent balance - minimal visual influence" }
        if maxSway < 0.05 { return "Good balance - slight visual influence" }
        if maxSway < 0.10 { return "Moderate sway - visual motion affecting balance" }
        if maxSway < 0.15 { return "Significant sway - strong visual influence" }
        return "High sway - visual motion strongly affecting balance"
    }
    
    private var swayAssessmentColor: Color {
        if maxSway < 0.05 { return .green }
        if maxSway < 0.10 { return .orange }
        return .red
    }
    
    private func toggleMovement() {
        if isMoving {
            stopMovement()
        } else {
            startMovement()
        }
    }
    
    private func startMovement() {
        print("Starting movement")
        isMoving = true
        startTime = CACurrentMediaTime()
        
        // Reset sway tracking
        initialHeadPosition = currentHeadPosition
        maxSway = 0
        swayHistory.removeAll()
        isRecordingSway = true
        
        // Create a timer that updates 60 times per second
        timer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { _ in
            updateRoomPosition()
            recordSway()
        }
    }
    
    private func stopMovement() {
        print("Stopping movement")
        isMoving = false
        isRecordingSway = false
        timer?.invalidate()
        timer = nil
        
        // Reset room position with animation
        withAnimation(.easeInOut(duration: 0.5)) {
            roomEntity?.position = .zero
        }
        
        // Analyze sway data
        if !swayHistory.isEmpty {
            analyzeSwayPattern()
        }
    }
    
    private func recordSway() {
        guard let initial = initialHeadPosition else { return }
        
        let displacement = currentHeadPosition - initial
        let magnitude = simd_length(displacement)
        
        // Update max sway
        if magnitude > maxSway {
            maxSway = magnitude
        }
        
        // Record sway point
        let swayPoint = SwayPoint(
            time: CACurrentMediaTime() - startTime,
            displacement: displacement,
            magnitude: magnitude
        )
        swayHistory.append(swayPoint)
        
        // Keep only last 10 seconds of data (600 points at 60 Hz)
        if swayHistory.count > 600 {
            swayHistory.removeFirst()
        }
    }
    
    private func analyzeSwayPattern() {
        guard !swayHistory.isEmpty else { return }
        
        // Calculate RMS sway
        let totalSquaredMagnitude = swayHistory.reduce(Float(0)) { $0 + $1.magnitude * $1.magnitude }
        let rmsSway = sqrt(totalSquaredMagnitude / Float(swayHistory.count))
        
        print("Sway Analysis:")
        print("  Max Sway: \(String(format: "%.1f cm", maxSway * 100))")
        print("  RMS Sway: \(String(format: "%.1f cm", rmsSway * 100))")
        print("  Samples: \(swayHistory.count)")
        
        // Check if sway correlates with room movement
        if movementAxis == .forwardBack {
            let zSway = swayHistory.map { $0.displacement.z }
            let maxZ = zSway.max() ?? 0
            let minZ = zSway.min() ?? 0
            print("  Z-axis range: \(String(format: "%.1f to %.1f cm", minZ * 100, maxZ * 100))")
        }
    }
    
    // Head tracking functions
    private func startHeadTracking() {
        headTrackingTask = Task {
            do {
                // Request authorization and start session
                try await arkitSession.run([worldTracking])
                
                // Monitor anchor updates
                for await update in worldTracking.anchorUpdates {
                    guard let deviceAnchor = update.anchor as? DeviceAnchor else { continue }
                    
                    // Get head position from the transform
                    let transform = deviceAnchor.originFromAnchorTransform
                    let position = SIMD3<Float>(
                        transform.columns.3.x,
                        transform.columns.3.y,
                        transform.columns.3.z
                    )
                    
                    await MainActor.run {
                        currentHeadPosition = position
                        
                        // Set initial position on first update
                        if initialHeadPosition == nil && !isMoving {
                            initialHeadPosition = position
                        }
                    }
                }
            } catch {
                print("ARKit session error: \(error)")
            }
        }
    }
    
    private func stopHeadTracking() {
        headTrackingTask?.cancel()
        headTrackingTask = nil
    }
    
    private func updateRoomPosition() {
        guard isMoving, let room = roomEntity else { return }
        
        let currentTime = CACurrentMediaTime()
        let elapsed = Float(currentTime - startTime)
        
        // Calculate sinusoidal movement
        let phase = elapsed * frequency * 2 * .pi
        
        // Apply smooth ramping at start (first 2 seconds)
        let rampFactor: Float = min(1.0, elapsed / 2.0)
        let currentAmplitude = amplitude * rampFactor
        
        switch movementAxis {
        case .forwardBack:
            room.position = [0, 0, sin(phase) * currentAmplitude]
        case .leftRight:
            room.position = [sin(phase) * currentAmplitude, 0, 0]
        case .both:
            room.position = [
                sin(phase) * currentAmplitude,
                0,
                cos(phase) * currentAmplitude
            ]
        }
        
        // Debug print every 30 frames (0.5 seconds)
        if Int(elapsed * 60) % 30 == 0 {
            print("Room position: \(room.position), phase: \(phase)")
        }
    }
    
    private func createRoom() -> Entity {
        let room = Entity()
        room.name = "MovingRoom"
        
        let roomSize: Float = 4.0  // 4 meters
        let wallHeight: Float = 3.0  // 3 meters
        let wallThickness: Float = 0.1
        
        // Materials with better visual distinction
        let floorMaterial = SimpleMaterial(color: UIColor(red: 0.4, green: 0.3, blue: 0.2, alpha: 1.0), isMetallic: false)
        let wallMaterial = SimpleMaterial(color: UIColor(red: 0.9, green: 0.9, blue: 0.85, alpha: 1.0), isMetallic: false)
        let ceilingMaterial = SimpleMaterial(color: .white, isMetallic: false)
        
        // Floor
        let floor = ModelEntity(
            mesh: .generateBox(width: roomSize, height: wallThickness, depth: roomSize),
            materials: [floorMaterial]
        )
        floor.position.y = 0
        floor.name = "Floor"
        room.addChild(floor)
        
        // Ceiling
        let ceiling = ModelEntity(
            mesh: .generateBox(width: roomSize, height: wallThickness, depth: roomSize),
            materials: [ceilingMaterial]
        )
        ceiling.position.y = wallHeight
        ceiling.name = "Ceiling"
        room.addChild(ceiling)
        
        // Front wall (with window effect)
        let frontWall = createWallWithFeatures(
            width: roomSize,
            height: wallHeight,
            material: wallMaterial,
            hasWindow: true
        )
        frontWall.position.z = -roomSize/2
        frontWall.name = "FrontWall"
        room.addChild(frontWall)
        
        // Back wall
        let backWall = ModelEntity(
            mesh: .generateBox(width: roomSize, height: wallHeight, depth: wallThickness),
            materials: [wallMaterial]
        )
        backWall.position = [0, wallHeight/2, roomSize/2]
        backWall.name = "BackWall"
        room.addChild(backWall)
        
        // Left wall
        let leftWall = ModelEntity(
            mesh: .generateBox(width: wallThickness, height: wallHeight, depth: roomSize),
            materials: [wallMaterial]
        )
        leftWall.position = [-roomSize/2, wallHeight/2, 0]
        leftWall.name = "LeftWall"
        room.addChild(leftWall)
        
        // Right wall
        let rightWall = ModelEntity(
            mesh: .generateBox(width: wallThickness, height: wallHeight, depth: roomSize),
            materials: [wallMaterial]
        )
        rightWall.position = [roomSize/2, wallHeight/2, 0]
        rightWall.name = "RightWall"
        room.addChild(rightWall)
        
        // Add some visual features for motion perception
        addRoomFeatures(to: room, roomSize: roomSize)
        
        return room
    }
    
    private func createWallWithFeatures(width: Float, height: Float, material: SimpleMaterial, hasWindow: Bool) -> Entity {
        let wall = Entity()
        
        // Main wall
        let wallModel = ModelEntity(
            mesh: .generateBox(width: width, height: height, depth: 0.1),
            materials: [material]
        )
        wallModel.position.y = height/2
        wall.addChild(wallModel)
        
        if hasWindow {
            // Add window frames with better contrast
            let windowWidth: Float = width * 0.3
            let windowHeight: Float = height * 0.4
            
            // Create window "panes" with slight blue tint
            for i in 0..<2 {
                let xOffset = Float(i) * windowWidth - windowWidth/2
                
                let windowPane = ModelEntity(
                    mesh: .generateBox(width: windowWidth * 0.9, height: windowHeight, depth: 0.12),
                    materials: [SimpleMaterial(color: UIColor(red: 0.8, green: 0.9, blue: 1.0, alpha: 0.8), isMetallic: false)]
                )
                windowPane.position = [xOffset, height/2, 0.01]
                wall.addChild(windowPane)
                
                // Add window frame
                let frameMaterial = SimpleMaterial(color: .darkGray, isMetallic: false)
                let frameThickness: Float = 0.05
                
                // Horizontal frame pieces
                for y in [-windowHeight/2, windowHeight/2] {
                    let hFrame = ModelEntity(
                        mesh: .generateBox(width: windowWidth, height: frameThickness, depth: 0.15),
                        materials: [frameMaterial]
                    )
                    hFrame.position = [xOffset, height/2 + y, 0.02]
                    wall.addChild(hFrame)
                }
                
                // Vertical frame pieces
                for x in [-windowWidth/2, windowWidth/2] {
                    let vFrame = ModelEntity(
                        mesh: .generateBox(width: frameThickness, height: windowHeight, depth: 0.15),
                        materials: [frameMaterial]
                    )
                    vFrame.position = [xOffset + x, height/2, 0.02]
                    wall.addChild(vFrame)
                }
            }
        }
        
        return wall
    }
    
    private func addRoomFeatures(to room: Entity, roomSize: Float) {
        // Add vertical pillars in corners for better motion perception
        let pillarMaterial = SimpleMaterial(color: .systemBlue, isMetallic: true)
        let pillarSize: Float = 0.15
        let pillarHeight: Float = 2.5
        
        for x in [-1, 1] {
            for z in [-1, 1] {
                let pillar = ModelEntity(
                    mesh: .generateBox(width: pillarSize, height: pillarHeight, depth: pillarSize),
                    materials: [pillarMaterial]
                )
                pillar.position = [Float(x) * (roomSize/2 - 0.3), pillarHeight/2, Float(z) * (roomSize/2 - 0.3)]
                pillar.name = "Pillar_\(x)_\(z)"
                room.addChild(pillar)
            }
        }
        
        // Add a striped pattern on the floor for better motion perception
        let stripeMaterial1 = SimpleMaterial(color: .black, isMetallic: false)
        let stripeMaterial2 = SimpleMaterial(color: .white, isMetallic: false)
        let stripeWidth: Float = 0.2
        let stripeHeight: Float = 0.001  // Very thin, just above floor
        
        for i in stride(from: -roomSize/2, to: roomSize/2, by: stripeWidth * 2) {
            let stripe = ModelEntity(
                mesh: .generateBox(width: roomSize, height: stripeHeight, depth: stripeWidth),
                materials: [i.truncatingRemainder(dividingBy: stripeWidth * 4) == 0 ? stripeMaterial1 : stripeMaterial2]
            )
            stripe.position = [0, 0.11, i]
            room.addChild(stripe)
        }
        
        // Add a reference sphere that stays at eye level
        let sphere = ModelEntity(
            mesh: .generateSphere(radius: 0.15),
            materials: [SimpleMaterial(color: .red, isMetallic: true)]
        )
        sphere.position = [0, 1.6, -1.0]  // At eye level, in front
        sphere.name = "ReferenceSphere"
        room.addChild(sphere)
        
        // Add some "pictures" on the walls for reference
        let pictureMaterial = SimpleMaterial(color: .systemGreen, isMetallic: false)
        for (x, z, rot) in [(Float(0), Float(-roomSize/2 + 0.11), Float(0)),
                            (Float(-roomSize/2 + 0.11), Float(0), Float.pi/2),
                            (Float(roomSize/2 - 0.11), Float(0), Float(-Float.pi/2))] {
            let picture = ModelEntity(
                mesh: .generateBox(width: 0.8, height: 0.6, depth: 0.02),
                materials: [pictureMaterial]
            )
            picture.position = [x, 1.8, z]
            picture.orientation = simd_quatf(angle: rot, axis: [0, 1, 0])
            room.addChild(picture)
        }
    }
}