import Foundation
import MultipeerConnectivity
import SwiftUI

/// Manager for handling MultipeerConnectivity to send SCAT5 diagnosis results to iPhone devices
class MultipeerManager: NSObject, ObservableObject {
    
    // MARK: - Properties
    private let serviceType = "scat5-diagnosis"
    private let myPeerId = MCPeerID(displayName: UIDevice.current.name)
    
    private var session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser
    private var browser: MCNearbyServiceBrowser
    
    // Published properties for SwiftUI binding
    @Published var isAdvertising = false
    @Published var isBrowsing = false
    @Published var connectedPeers: [MCPeerID] = []
    @Published var discoveredPeers: [MCPeerID] = []
    @Published var connectionState: MCSessionState = .notConnected
    @Published var lastError: String?
    @Published var lastTransmissionResult: TransmissionResult?
    
    // Transmission tracking
    @Published var isTransmitting = false
    @Published var transmissionProgress: Double = 0.0
    
    override init() {
        session = MCSession(peer: myPeerId, securityIdentity: nil, encryptionPreference: .required)
        advertiser = MCNearbyServiceAdvertiser(peer: myPeerId, discoveryInfo: nil, serviceType: serviceType)
        browser = MCNearbyServiceBrowser(peer: myPeerId, serviceType: serviceType)
        
        super.init()
        
        session.delegate = self
        advertiser.delegate = self
        browser.delegate = self
    }
    
    // MARK: - Public Methods
    
    /// Start advertising this device as available to receive connections
    func startAdvertising() {
        guard !isAdvertising else { return }
        advertiser.startAdvertisingPeer()
        isAdvertising = true
        print("🔄 Started advertising for SCAT5 diagnosis sharing")
    }
    
    /// Stop advertising
    func stopAdvertising() {
        guard isAdvertising else { return }
        advertiser.stopAdvertisingPeer()
        isAdvertising = false
        print("🛑 Stopped advertising")
    }
    
    /// Start browsing for nearby devices
    func startBrowsing() {
        guard !isBrowsing else { return }
        browser.startBrowsingForPeers()
        isBrowsing = true
        print("🔍 Started browsing for nearby devices")
    }
    
    /// Stop browsing for devices
    func stopBrowsing() {
        guard isBrowsing else { return }
        browser.stopBrowsingForPeers()
        isBrowsing = false
        discoveredPeers.removeAll()
        print("🛑 Stopped browsing")
    }
    
    /// Connect to a discovered peer
    func connectToPeer(_ peerID: MCPeerID) {
        guard discoveredPeers.contains(peerID) else {
            lastError = "Peer not found in discovered peers"
            return
        }
        
        print("🤝 Attempting to connect to \(peerID.displayName)")
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 30)
    }
    
    /// Disconnect from all peers
    func disconnect() {
        session.disconnect()
        connectedPeers.removeAll()
        connectionState = .notConnected
        print("🚪 Disconnected from all peers")
    }
    
    /// Send SCAT5 diagnosis data to all connected peers
    func sendDiagnosis(_ diagnosis: SCAT5DiagnosisTransfer) async -> TransmissionResult {
        guard !connectedPeers.isEmpty else {
            let result = TransmissionResult(success: false, message: "No connected peers", peersReached: 0)
            await MainActor.run { lastTransmissionResult = result }
            return result
        }
        
        do {
            await MainActor.run { 
                isTransmitting = true
                transmissionProgress = 0.0
            }
            
            let data = try diagnosis.encodeForTransmission()
            print("📤 Sending diagnosis data (\(data.count) bytes) to \(connectedPeers.count) peer(s)")
            
            // Update progress
            await MainActor.run { transmissionProgress = 0.5 }
            
            try session.send(data, toPeers: connectedPeers, with: .reliable)
            
            await MainActor.run { transmissionProgress = 1.0 }
            
            let result = TransmissionResult(
                success: true,
                message: "Successfully sent to \(connectedPeers.count) device(s)",
                peersReached: connectedPeers.count,
                dataSize: data.count
            )
            
            await MainActor.run { 
                isTransmitting = false
                lastTransmissionResult = result
            }
            
            print("✅ Successfully sent diagnosis to \(connectedPeers.count) peer(s)")
            return result
            
        } catch {
            let result = TransmissionResult(
                success: false,
                message: "Failed to send: \(error.localizedDescription)",
                peersReached: 0
            )
            
            await MainActor.run { 
                isTransmitting = false
                lastTransmissionResult = result
                lastError = error.localizedDescription
            }
            
            print("❌ Failed to send diagnosis: \(error)")
            return result
        }
    }
    
    /// Generate a shareable summary for other sharing methods
    func generateShareableContent(from diagnosis: SCAT5DiagnosisTransfer) -> ShareableContent {
        let summary = diagnosis.generateSummaryReport()
        let subject = "SCAT5 Assessment Results - \(diagnosis.patientInfo?.name ?? "Patient")"
        
        return ShareableContent(
            subject: subject,
            body: summary,
            diagnosis: diagnosis
        )
    }
}

// MARK: - MCSessionDelegate
extension MultipeerManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            self.connectionState = state
            
            switch state {
            case .connecting:
                print("🔄 Connecting to \(peerID.displayName)")
            case .connected:
                print("✅ Connected to \(peerID.displayName)")
                if !self.connectedPeers.contains(peerID) {
                    self.connectedPeers.append(peerID)
                }
            case .notConnected:
                print("🚪 Disconnected from \(peerID.displayName)")
                self.connectedPeers.removeAll { $0 == peerID }
            @unknown default:
                print("⚠️ Unknown connection state for \(peerID.displayName)")
            }
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        // This would be used if receiving data from iPhone devices
        print("📥 Received \(data.count) bytes from \(peerID.displayName)")
        
        // For now, we're only sending data, but this could be used for
        // bidirectional communication in the future
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        // Not used for this implementation
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        // Not used for this implementation
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        // Not used for this implementation
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate
extension MultipeerManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        print("📨 Received invitation from \(peerID.displayName)")
        // Auto-accept invitations for now (in production, you might want user confirmation)
        invitationHandler(true, session)
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        DispatchQueue.main.async {
            self.lastError = "Failed to start advertising: \(error.localizedDescription)"
            self.isAdvertising = false
        }
        print("❌ Failed to start advertising: \(error)")
    }
}

// MARK: - MCNearbyServiceBrowserDelegate
extension MultipeerManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        DispatchQueue.main.async {
            if !self.discoveredPeers.contains(peerID) {
                self.discoveredPeers.append(peerID)
                print("🔍 Discovered peer: \(peerID.displayName)")
            }
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async {
            self.discoveredPeers.removeAll { $0 == peerID }
            print("🚫 Lost peer: \(peerID.displayName)")
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        DispatchQueue.main.async {
            self.lastError = "Failed to start browsing: \(error.localizedDescription)"
            self.isBrowsing = false
        }
        print("❌ Failed to start browsing: \(error)")
    }
}

// MARK: - Supporting Types

struct TransmissionResult: Equatable {
    let success: Bool
    let message: String
    let peersReached: Int
    let dataSize: Int?
    let timestamp: Date
    
    init(success: Bool, message: String, peersReached: Int, dataSize: Int? = nil) {
        self.success = success
        self.message = message
        self.peersReached = peersReached
        self.dataSize = dataSize
        self.timestamp = Date()
    }
    
    static func == (lhs: TransmissionResult, rhs: TransmissionResult) -> Bool {
        return lhs.success == rhs.success &&
               lhs.message == rhs.message &&
               lhs.peersReached == rhs.peersReached &&
               lhs.dataSize == rhs.dataSize &&
               lhs.timestamp == rhs.timestamp
    }
}

struct ShareableContent {
    let subject: String
    let body: String
    let diagnosis: SCAT5DiagnosisTransfer
    
    var activityItems: [Any] {
        var items: [Any] = []
        
        // Add the subject and formatted report
        items.append(subject)
        items.append(body)
        
        // Create a temporary file for the detailed CSV report
        if let csvData = generateCSVReport().data(using: .utf8) {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("SCAT5_Assessment_\(diagnosis.sessionId.uuidString.prefix(8)).csv")
            
            do {
                try csvData.write(to: tempURL)
                items.append(tempURL)
            } catch {
                print("❌ Failed to create CSV file: \(error)")
            }
        }
        
        // Create a temporary file for the JSON data
        do {
            let jsonData = try diagnosis.encodeForTransmission()
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("SCAT5_Data_\(diagnosis.sessionId.uuidString.prefix(8)).json")
            
            try jsonData.write(to: tempURL)
            items.append(tempURL)
        } catch {
            print("❌ Failed to create JSON file: \(error)")
        }
        
        return items
    }
    
    private func generateCSVReport() -> String {
        var csv = "Field,Value\n"
        
        // Basic info
        csv += "Patient Name,\"\(diagnosis.patientInfo?.name ?? "Unknown")\"\n"
        csv += "Assessment Date,\"\(diagnosis.sessionDate.formatted(date: .abbreviated, time: .shortened))\"\n"
        csv += "Session Type,\"\(diagnosis.sessionType.rawValue)\"\n"
        csv += "Complete,\(diagnosis.isComplete)\n"
        csv += "Progress Percentage,\(Int(diagnosis.progressPercentage * 100))%\n"
        
        if !diagnosis.skippedModules.isEmpty {
            csv += "Skipped Modules,\"\(diagnosis.skippedModules.joined(separator: ", "))\"\n"
        }
        
        // Symptom results
        csv += "\nSYMPTOM EVALUATION\n"
        csv += "Total Score,\(diagnosis.symptomResults.totalScore)\n"
        csv += "Number of Symptoms,\(diagnosis.symptomResults.numberOfSymptoms)\n"
        csv += "Worse with Physical Activity,\(diagnosis.symptomResults.worsensWithPhysicalActivity)\n"
        csv += "Worse with Mental Activity,\(diagnosis.symptomResults.worsensWithMentalActivity)\n"
        csv += "Percent of Normal,\(diagnosis.symptomResults.percentOfNormal)%\n"
        csv += "Was Skipped,\(diagnosis.symptomResults.wasSkipped)\n"
        
        // Cognitive results
        csv += "\nCOGNITIVE ASSESSMENT\n"
        csv += "Orientation Score,\(diagnosis.cognitiveResults.orientationResults.correctCount)/\(diagnosis.cognitiveResults.orientationResults.questionCount)\n"
        csv += "Orientation Skipped,\(diagnosis.cognitiveResults.orientationResults.wasSkipped)\n"
        csv += "Immediate Memory Score,\(diagnosis.cognitiveResults.immediateMemoryResults.totalScore)/15\n"
        csv += "Immediate Memory Skipped,\(diagnosis.cognitiveResults.immediateMemoryResults.wasSkipped)\n"
        csv += "Concentration Score,\(diagnosis.cognitiveResults.concentrationResults.totalScore)/5\n"
        csv += "Concentration Skipped,\(diagnosis.cognitiveResults.concentrationResults.wasSkipped)\n"
        csv += "Delayed Recall Score,\(diagnosis.cognitiveResults.delayedRecallResults.score)/5\n"
        csv += "Delayed Recall Skipped,\(diagnosis.cognitiveResults.delayedRecallResults.wasSkipped)\n"
        
        // Neurological results
        csv += "\nNEUROLOGICAL EXAMINATION\n"
        csv += "Overall Normal,\(diagnosis.neurologicalResults.isNormal)\n"
        csv += "Neck Pain,\(diagnosis.neurologicalResults.neckPain)\n"
        csv += "Double Vision,\(diagnosis.neurologicalResults.doubleVision)\n"
        csv += "Finger-Nose Normal,\(diagnosis.neurologicalResults.fingerNoseNormal)\n"
        csv += "Tandem Gait Normal,\(diagnosis.neurologicalResults.tandemGaitNormal)\n"
        csv += "Was Skipped,\(diagnosis.neurologicalResults.wasSkipped)\n"
        
        // Balance results
        csv += "\nBALANCE ASSESSMENT\n"
        csv += "Total Errors,\(diagnosis.balanceResults.totalErrorScore)\n"
        csv += "Double Leg Errors,\(diagnosis.balanceResults.errorsByStance[0])\n"
        csv += "Single Leg Errors,\(diagnosis.balanceResults.errorsByStance[1])\n"
        csv += "Tandem Errors,\(diagnosis.balanceResults.errorsByStance[2])\n"
        csv += "Was Skipped,\(diagnosis.balanceResults.wasSkipped)\n"
        
        // Risk assessment
        if let risk = diagnosis.riskAssessment {
            csv += "\nRISK ASSESSMENT\n"
            csv += "Risk Level,\"\(risk.riskLevel.rawValue)\"\n"
            csv += "Has Baseline,\(risk.hasBaseline)\n"
            
            if let symptomZ = risk.symptomSeverityZScore {
                csv += "Symptom Z-Score,\(String(format: "%.3f", symptomZ))\n"
            }
            if let memoryZ = risk.immediateMemoryZScore {
                csv += "Memory Z-Score,\(String(format: "%.3f", memoryZ))\n"
            }
            if let orientationZ = risk.orientationZScore {
                csv += "Orientation Z-Score,\(String(format: "%.3f", orientationZ))\n"
            }
            if let concentrationZ = risk.concentrationZScore {
                csv += "Concentration Z-Score,\(String(format: "%.3f", concentrationZ))\n"
            }
            if let recallZ = risk.delayedRecallZScore {
                csv += "Delayed Recall Z-Score,\(String(format: "%.3f", recallZ))\n"
            }
            
            csv += "\nRECOMMENDATIONS\n"
            for (index, recommendation) in risk.recommendations.enumerated() {
                csv += "Recommendation \(index + 1),\"\(recommendation)\"\n"
            }
        }
        
        return csv
    }
}