
````markdown
# speech-controlled-app.md

## Overview  
This guide shows you how to use Apple’s new **SpeechAnalyzer** API in visionOS 26 to build a fully speech-controlled app from top to bottom. You’ll learn how to configure permissions and models, capture microphone audio, feed it into a SpeechAnalyzer session, handle both “volatile” (rough) and “final” transcription results, map transcripts to commands, and integrate everything into a SwiftUI + Spatial UI visionOS app. :contentReference[oaicite:0]{index=0} :contentReference[oaicite:1]{index=1}

---

## 1. Prerequisites  
- **Xcode 15.2** (or later) with the **visionOS 26 SDK** installed. :contentReference[oaicite:2]{index=2}  
- A valid **Apple Developer** account and a device (or simulator) running visionOS 26. :contentReference[oaicite:3]{index=3}  
- Your project must include the **Speech** framework. :contentReference[oaicite:4]{index=4}  

---

## 2. Configure Permissions & Capabilities

1. **Info.plist**  
   ```xml
   <key>NSMicrophoneUsageDescription</key>
   <string>“This app requires microphone access for speech control.”</string>
   <key>NSSpeechRecognitionUsageDescription</key>
   <string>“Speech recognition is used to control the app via voice commands.”</string>
````

([Apple Developer][1])

2. **Entitlements**
   Ensure your target’s Signing & Capabilities includes **Speech Recognition**. ([DEV Community][2])

---

## 3. Ensuring the Speech Model Is Available

Before starting a session, confirm that the on-device model for your locale is installed or download it:

```swift
import Speech

func ensureModel(for locale: Locale) async throws {
    guard await SpeechAnalyzer.supportedLocales().contains(locale) else {
        throw NSError(domain: "SpeechApp", code: 1, userInfo: [NSLocalizedDescriptionKey: "Locale not supported"])
    }
    if let downloader = try await AssetInventory.assetInstallationRequest(supporting: [SpeechTranscriber.self]) {
        try await downloader.downloadAndInstall()
    }
}
```

([Apple Developer][3])

---

## 4. Capturing Microphone Audio

Use **AVAudioEngine** to capture live audio and feed it into an **AsyncSequence** of audio buffers:

```swift
import AVFoundation

class AudioSource: AsyncSequence {
    typealias Element = AVAudioPCMBuffer

    private let engine = AVAudioEngine()
    private let bus = 0

    func makeAsyncIterator() -> Iterator {
        return Iterator(engine: engine, bus: bus)
    }

    struct Iterator: AsyncIteratorProtocol {
        let engine: AVAudioEngine
        let bus: AVAudioNodeBus
        private let bufferSize: AVAudioFrameCount = 1024

        init(engine: AVAudioEngine, bus: AVAudioNodeBus) {
            self.engine = engine
            self.bus = bus
            let input = engine.inputNode
            let format = input.outputFormat(forBus: bus)
            input.installTap(onBus: bus, bufferSize: bufferSize, format: format) { _, _ in }
            try? engine.start()
        }

        mutating func next() async -> AVAudioPCMBuffer? {
            // Await the next buffer from a Continuation (implementation omitted for brevity)
            return await withCheckedContinuation { /* … */ }
        }
    }
}
```

([Apple Developer][4])

---

## 5. Creating & Running a SpeechAnalyzer Session

1. **Import & Setup**

   ```swift
   import Speech

   let analyzer = SpeechAnalyzer()
   let transcriber = SpeechTranscriber(locale: .autoupdatingCurrent)
   analyzer.addModule(transcriber)
   ```

2. **Feed Audio & Read Results**

   ```swift
   let audioSource = AudioSource()
   Task {
     // Launch result-reading task
     Task.detached {
       for await result in try! analyzer.results {
         switch result {
         case .volatile(let interim):
           handleInterimResult(interim.bestTranscription.formattedString)
         case .final(let final):
           handleFinalResult(final.bestTranscription.formattedString)
         }
       }
     }

     // Feed audio buffers
     for await buffer in audioSource {
       try? await analyzer.analyze(buffer)
     }

     // Signal end of audio
     try? await analyzer.finish()
   }
   ```

   * **Note**: `analyzer.results` is an `AsyncSequence` yielding both `.volatile` and `.final` results. ([DEV Community][2]) ([Apple Developer][4])

---

## 6. Handling Transcription Results

* **Volatile Results**

  * Fast, rough guesses; update UI immediately.
  * Replaceable as more context arrives. ([DEV Community][2])

* **Final Results**

  * Stable, highly accurate; use these to trigger commands and persistent actions. ([DEV Community][2])

---

## 7. Mapping Transcripts to Commands

```swift
func handleFinalResult(_ text: String) {
  let command = text.lowercased()
  if command.contains("open menu") {
    openMenu()
  } else if command.contains("next") {
    goToNextItem()
  } else if command.contains("select") {
    selectItem()
  }
  // Add more mappings as needed…
}
```

Use simple string matching, or integrate **NLTagger** / **NLP** for more robust intent parsing. ([MacRumors][5])

---

## 8. Integrating with visionOS Spatial UI

* Use **SwiftUI** to bind spoken commands to view states.
* Present visual feedback (e.g. a floating “Listening…” indicator) in 3D space using `RealityView`.
* Combine gaze + speech: highlight the gazed-at item, then speak “select” to activate it. ([MacStories][6])

---

## 9. Error Handling & Edge Cases

* Handle **localeNotSupported** by prompting the user to choose another language. ([Apple Developer][3])
* Monitor `analyzer.errorStream` for real-time errors.
* Fallback to a simple **SFSpeechRecognizer** if the on-device model fails. ([DEV Community][2])

---

## 10. Performance Tips

* Keep buffer sizes between **512–1024 frames** for low latency.
* Disable **volatile** results if you only need final transcripts, reducing CPU usage.
* Pre-download speech models during onboarding to avoid runtime delays. ([MacRumors][5])

---

## References

1. SpeechAnalyzer API — Apple Developer Documentation ([Apple Developer][4])
2. Speech Framework Overview — Apple Developer Documentation ([Apple Developer][1])
3. WWDC 2025: Bring advanced speech-to-text capabilities to your app ([Apple Developer][7])
4. SpeechAnalyzer design deep-dive — WWDC sample code discussion ([Apple Developer][4])
5. Next-gen Speech-to-Text using SpeechAnalyzer (DEV Community) ([DEV Community][2])
6. SpeechAnalyzer and SpeechTranscriber on-device speed tests (MacStories) ([MacStories][6])
7. localeNotSupported fix — Apple Developer Forums ([Apple Developer][3])
8. Advanced speech transcription performance tips (MacRumors) ([MacRumors][5])
9. AsyncSequence fundamentals for streaming data (WWDC21) ([Apple Developer][4])
10. Vision Pro spatial UI patterns — Apple Developer Videos ([Apple Developer][7])

```
::contentReference[oaicite:28]{index=28}
```

[1]: https://developer.apple.com/documentation/speech?utm_source=chatgpt.com "Speech | Apple Developer Documentation"
[2]: https://dev.to/arshtechpro/wwdc-2025-the-next-evolution-of-speech-to-text-using-speechanalyzer-6lo?utm_source=chatgpt.com "The Next Evolution of Speech-to-Text using SpeechAnalyzer"
[3]: https://developer.apple.com/forums/thread/790108?utm_source=chatgpt.com "SpeechAnalyzer speech to text wwdc sample app"
[4]: https://developer.apple.com/documentation/speech/speechanalyzer?utm_source=chatgpt.com "SpeechAnalyzer | Apple Developer Documentation"
[5]: https://www.macrumors.com/2025/06/18/apple-transcription-api-faster-than-whisper/?utm_source=chatgpt.com "Apple's New Transcription APIs Blow Past Whisper ..."
[6]: https://www.macstories.net/stories/hands-on-how-apples-new-speech-apis-outpace-whisper-for-lightning-fast-transcription/?utm_source=chatgpt.com "Hands-On: How Apple's New Speech APIs Outpace ..."
[7]: https://developer.apple.com/videos/play/wwdc2025/277/?utm_source=chatgpt.com "Bring advanced speech-to-text to your app with ..."
