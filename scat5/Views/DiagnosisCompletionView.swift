import SwiftUI
import SwiftData

struct DiagnosisCompletionView: View {
    let session: TestSession
    let onDismiss: () -> Void
    
    @State private var multipeerManager = MultipeerManager()
    @State private var showingShareSheet = false
    @State private var shareableContent: ShareableContent?
    @State private var diagnosisTransfer: SCAT5DiagnosisTransfer?
    @State private var showingDeviceList = false
    @State private var showingTransmissionResult = false
    @State private var showingDetailedResults = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Success Header
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.green)
                        
                        Text("Assessment Complete")
                            .font(.title.weight(.bold))
                        
                        Text("SCAT5 diagnosis has been completed successfully")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // Session Summary Card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.blue)
                            
                            VStack(alignment: .leading) {
                                Text(session.user?.fullName ?? session.athlete?.name ?? "Unknown Patient")
                                    .font(.headline)
                                Text(session.sessionType.rawValue)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                Text(session.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(session.date.formatted(date: .omitted, time: .shortened))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Divider()
                        
                        // Quick Results Summary
                        if let diagnosis = diagnosisTransfer {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                                ResultCard(
                                    title: "Symptoms",
                                    value: "\(diagnosis.symptomResults.totalScore)/132",
                                    color: diagnosis.symptomResults.totalScore > 15 ? .red : .green
                                )
                                
                                ResultCard(
                                    title: "Balance Errors",
                                    value: "\(diagnosis.balanceResults.totalErrorScore)",
                                    color: diagnosis.balanceResults.totalErrorScore > 10 ? .red : .green
                                )
                                
                                ResultCard(
                                    title: "Cognitive Score",
                                    value: "\(diagnosis.cognitiveResults.orientationResults.correctCount + diagnosis.cognitiveResults.immediateMemoryResults.totalScore + diagnosis.cognitiveResults.concentrationResults.totalScore)/25",
                                    color: .blue
                                )
                                
                                ResultCard(
                                    title: "Neurological",
                                    value: diagnosis.neurologicalResults.isNormal ? "Normal" : "Abnormal",
                                    color: diagnosis.neurologicalResults.isNormal ? .green : .red
                                )
                            }
                        }
                    }
                    .padding(20)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    
                    // Risk Assessment
                    if let diagnosis = diagnosisTransfer, let risk = diagnosis.riskAssessment {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                Text("Risk Assessment")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            
                            HStack {
                                Text("Risk Level:")
                                    .fontWeight(.medium)
                                Spacer()
                                Text(risk.riskLevel.rawValue)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(colorForRiskLevel(risk.riskLevel), in: Capsule())
                                    .foregroundStyle(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Recommendations:")
                                    .fontWeight(.medium)
                                
                                ForEach(risk.recommendations, id: \.self) { recommendation in
                                    HStack(alignment: .top) {
                                        Text("•")
                                            .fontWeight(.bold)
                                        Text(recommendation)
                                        Spacer()
                                    }
                                }
                            }
                        }
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
                    
                    // Sharing Options
                    VStack(spacing: 16) {
                        Text("Share Results")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(spacing: 12) {
                            // Send to iPhone via MultipeerConnectivity
                            Button {
                                showingDeviceList = true
                            } label: {
                                HStack {
                                    Image(systemName: "iphone")
                                        .font(.title2)
                                    
                                    VStack(alignment: .leading) {
                                        Text("Send to iPhone")
                                            .fontWeight(.semibold)
                                        Text("Share via wireless connection")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                                .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                            
                            // Export/Share via system share sheet
                            Button {
                                guard let diagnosis = diagnosisTransfer else {
                                    print("❌ No diagnosis data available for export")
                                    return
                                }
                                
                                print("📤 Generating shareable content for export...")
                                shareableContent = multipeerManager.generateShareableContent(from: diagnosis)
                                print("✅ Generated shareable content with \(shareableContent?.activityItems.count ?? 0) items")
                                showingShareSheet = true
                            } label: {
                                HStack {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.title2)
                                    
                                    VStack(alignment: .leading) {
                                        Text("Export Results")
                                            .fontWeight(.semibold)
                                        Text("Share via email, messages, etc.")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                                .background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                            .disabled(diagnosisTransfer == nil)
                            .opacity(diagnosisTransfer == nil ? 0.6 : 1.0)
                            
                            // View Detailed Results
                            Button {
                                showingDetailedResults = true
                            } label: {
                                HStack {
                                    Image(systemName: "doc.text.magnifyingglass")
                                        .font(.title2)
                                    
                                    VStack(alignment: .leading) {
                                        Text("View Details")
                                            .fontWeight(.semibold)
                                        Text("See complete test breakdown")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                                .background(.purple.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    
                    Spacer(minLength: 50)
                }
                .padding(.horizontal, 24)
            }
            .navigationTitle("Assessment Complete")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
        }
        .onAppear {
            print("📋 DiagnosisCompletionView appeared")
            diagnosisTransfer = SCAT5DiagnosisTransfer(from: session, skippedModules: session.skippedModules)
            print("✅ Created diagnosis transfer with \(diagnosisTransfer?.completedModules.count ?? 0) completed modules")
            if let diagnosis = diagnosisTransfer {
                print("📊 Diagnosis summary: \(diagnosis.symptomResults.totalScore) symptoms, \(diagnosis.balanceResults.totalErrorScore) balance errors")
            }
        }
        .sheet(isPresented: $showingDeviceList) {
            DeviceSelectionView(multipeerManager: multipeerManager, diagnosis: diagnosisTransfer)
        }
        .sheet(isPresented: $showingShareSheet) {
            if let content = shareableContent {
                ShareSheet(items: content.activityItems)
            }
        }
        .sheet(isPresented: $showingDetailedResults) {
            NavigationStack {
                TestResultsView(session: session)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingDetailedResults = false
                            }
                        }
                    }
            }
        }
        .alert("Transmission Result", isPresented: $showingTransmissionResult) {
            Button("OK") { }
        } message: {
            if let result = multipeerManager.lastTransmissionResult {
                Text(result.message)
            }
        }
        .onChange(of: multipeerManager.lastTransmissionResult) { result in
            if result != nil {
                showingTransmissionResult = true
            }
        }
    }
    
    private func colorForRiskLevel(_ level: RiskLevel) -> Color {
        switch level {
        case .normal: return .green
        case .low: return .yellow
        case .moderate: return .orange
        case .high: return .red
        }
    }
}

// MARK: - Supporting Views

struct ResultCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fontWeight(.medium)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct DeviceSelectionView: View {
    @ObservedObject var multipeerManager: MultipeerManager
    let diagnosis: SCAT5DiagnosisTransfer?
    @Environment(\.dismiss) private var dismiss
    @State private var isScanning = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if multipeerManager.isTransmitting {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        
                        Text("Sending diagnosis data...")
                            .font(.headline)
                        
                        ProgressView(value: multipeerManager.transmissionProgress)
                            .progressViewStyle(.linear)
                    }
                    .padding(40)
                    
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "iphone.radiowaves.left.and.right")
                            .font(.system(size: 64))
                            .foregroundStyle(.blue)
                        
                        Text("Select iPhone Device")
                            .font(.title2.weight(.semibold))
                        
                        Text("Choose a nearby iPhone to send the diagnosis results to")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // Connected Devices
                    if !multipeerManager.connectedPeers.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Connected Devices")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            ForEach(multipeerManager.connectedPeers, id: \.displayName) { peer in
                                Button {
                                    if let diagnosis = diagnosis {
                                        Task {
                                            await multipeerManager.sendDiagnosis(diagnosis)
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "iphone")
                                            .foregroundStyle(.green)
                                        
                                        Text(peer.displayName)
                                            .fontWeight(.medium)
                                        
                                        Spacer()
                                        
                                        Text("Send")
                                            .font(.caption)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 4)
                                            .background(.blue, in: Capsule())
                                            .foregroundStyle(.white)
                                    }
                                    .padding()
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // Discovered Devices
                    if !multipeerManager.discoveredPeers.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Available Devices")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            ForEach(multipeerManager.discoveredPeers, id: \.displayName) { peer in
                                Button {
                                    multipeerManager.connectToPeer(peer)
                                } label: {
                                    HStack {
                                        Image(systemName: "iphone")
                                            .foregroundStyle(.blue)
                                        
                                        Text(peer.displayName)
                                            .fontWeight(.medium)
                                        
                                        Spacer()
                                        
                                        Text("Connect")
                                            .font(.caption)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 4)
                                            .background(.gray.opacity(0.3), in: Capsule())
                                    }
                                    .padding()
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // No devices found
                    if multipeerManager.discoveredPeers.isEmpty && multipeerManager.connectedPeers.isEmpty && isScanning {
                        VStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.title)
                                .foregroundStyle(.gray)
                            
                            Text("Searching for devices...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            Text("Make sure the receiving iPhone has the SCAT5 app open and is ready to receive data")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(20)
                    }
                    
                    Spacer()
                    
                    // Scan Button
                    Button {
                        if isScanning {
                            multipeerManager.stopBrowsing()
                            multipeerManager.stopAdvertising()
                        } else {
                            multipeerManager.startBrowsing()
                            multipeerManager.startAdvertising()
                        }
                        isScanning.toggle()
                    } label: {
                        HStack {
                            Image(systemName: isScanning ? "stop.circle" : "magnifyingglass")
                            Text(isScanning ? "Stop Scanning" : "Scan for Devices")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isScanning ? .red : .blue, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                    }
                }
            }
            .padding(24)
            .navigationTitle("Send to iPhone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if isScanning {
                            multipeerManager.stopBrowsing()
                            multipeerManager.stopAdvertising()
                        }
                        dismiss()
                    }
                }
            }
        }
        .onDisappear {
            multipeerManager.stopBrowsing()
            multipeerManager.stopAdvertising()
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let activityViewController = UIActivityViewController(activityItems: items, applicationActivities: nil)
        
        // Configure for iPad/visionOS
        if let popover = activityViewController.popoverPresentationController {
            if let window = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap({ $0.windows })
                .first(where: { $0.isKeyWindow }) {
                    
                popover.sourceView = window
                // Use window bounds instead of UIScreen for visionOS compatibility
                let windowBounds = window.bounds
                popover.sourceRect = CGRect(
                    x: windowBounds.midX, 
                    y: windowBounds.midY, 
                    width: 0, 
                    height: 0
                )
                popover.permittedArrowDirections = []
            }
        }
        
        return activityViewController
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview("Diagnosis Completion") {
    do {
        let container = try ModelContainer(for: TestSession.self, SymptomResult.self, CognitiveResult.self)
        let sampleSession = TestSession(date: .now, sessionType: .concussion)
        sampleSession.isComplete = true
        
        return DiagnosisCompletionView(session: sampleSession) {
            print("Dismissed")
        }
        .modelContainer(container)
    } catch {
        return Text("Preview failed: \(error.localizedDescription)")
    }
}
