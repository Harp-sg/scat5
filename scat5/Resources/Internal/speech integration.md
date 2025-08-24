Voice Interaction Developer Guide (visionOS 26)
Overview
The SCAT5 Vision Pro app will incorporate simple, context-aware voice commands to streamline user interaction. We will leverage Apple’s new on-device speech recognition framework (introduced in visionOS 26) – specifically the SpeechAnalyzer class and its SpeechTranscriber module – to parse short spoken commands and dictations. This approach avoids any continuous “Hey Siri” wake word or complex NLP: instead, users utter concise phrases like “Start test,” “Next,” “Five,” or “Repeat” to trigger actions. All speech processing runs locally for speed and privacy, aligning with medical-grade requirements. The voice UI is module-scoped: we listen for commands only within a given SCAT5 sub-test’s volumetric window, not for global app navigation. Key goals: Keep voice interaction minimal and robust. Users should speak only brief, expected words or numbers – the app logic will interpret these without needing lengthy sentences. At all times, traditional input via taps or gaze remains available as a fallback.
Architecture & Components
Speech framework: visionOS 26 introduces SpeechAnalyzer and related classes for real-time transcription. We will create a dedicated VoiceController (or integrate into the ModuleContext) to manage all speech input. This controller will configure:
SpeechAnalyzer – orchestrates the speech analysis session.
SpeechTranscriber – a module added to the analyzer to perform speech-to-text transcription.
(Optionally, other modules like a voice activity detector if needed – though Apple’s SpeechTranscriber will handle end-of-speech detection under the hood.)
Microphone capture: Voice input uses the Vision Pro’s array mics via AVAudioEngine. We configure AVAudioSession to .playAndRecord (for mixed audio) or .record mode with the .measurement mode to optimize for speech accuracy (disabling noise processing). For example:
swift
Copy
Edit
try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers])
try audioSession.setActive(true)
This ensures the mic input isn’t filtered in a way that could affect recognition. We then attach an audio tap on the input node to pull audio buffers continuously. Each buffer is converted if necessary to match the analyzer’s preferred format (e.g. 16 kHz mono) using an AVAudioConverter. SpeechAnalyzer setup: We initialize a SpeechTranscriber with the current locale (e.g. English "en-US"), and specify options to favor speed and partial results. For our use-case, we enable fast finalization and partial transcripts:
swift
Copy
Edit
transcriber = SpeechTranscriber(locale: Locale.current,
                                transcriptionOptions: [],
                                reportingOptions: [.volatileResults, .fastResults],
                                attributeOptions: [])
analyzer = SpeechAnalyzer(modules: [transcriber!])
let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber!])
Here, .volatileResults delivers interim transcriptions and .fastResults accelerates final result stability (reducing latency). We then prepare the audio pipeline:
Determine the analyzer’s required audio format (often 16kHz) and convert microphone PCM buffers to this format.
Use an AsyncStream<AnalyzerInput> to feed audio to the analyzer. We call try await analyzer.start(inputSequence: stream) to begin processing. As buffers arrive from the audio tap, we yield them into the stream (via inputBuilder.yield(AnalyzerInput(buffer: pcmBuffer))).
Permission: On app launch (or first use), request AVAudioSession record permission and speech recognition authorization (SFSpeechRecognizer.requestAuthorization). SpeechAnalyzer uses the same permission as legacy SFSpeech, so ensure it’s authorized before starting. Result handling: The SpeechTranscriber provides an async sequence of TranscriptionResult objects. We iterate over transcriber.results to receive transcripts and metadata in real time. Each result contains the recognized text and a flag isFinal indicating whether it’s an interim or final transcription for that segment. In our architecture, we will interpret transcripts on the fly:
Command Mode: For voice commands, we’ll typically treat the first final result as the command utterance and act on it, then stop listening.
Dictation Mode: For longer input (free recall of words, notes dictation), we accumulate results (or tokens) until a time limit or explicit termination (e.g. user says “Done”).
After processing, we call analyzer.finish() or finalizeAndFinish() to gracefully end the session. This flushes any remaining partial audio through the model and stops the loop.
Command Parsing Strategy
We implement command recognition by matching transcribed text against a predefined set of phrases for the current context. There is no semantic NLP—just literal (or slightly fuzzy) matching to known commands. For instance, in a testing module, acceptable inputs might be “start”, “stop”, “next”, “back”, “repeat”, or digits “0”–“10”. The VoiceController will maintain a list of valid commands for the active module state and listen for those. When a transcription result arrives, we normalize it (e.g. lowercase and trim whitespace/punctuation) and check if it corresponds to any command. For reliability, we may allow slight variants or synonyms (e.g. “begin” as alias for “start”, numeral “5” or word “five”). If the text contains a known command word, we trigger the corresponding action. For example:
swift
Copy
Edit
for try await result in transcriber.results {
    let spoken = result.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if !result.isFinal { continue } // only act on finalized command
    if spoken == "next" || spoken == "next stance" {
        nextButtonAction()  // programmatically invoke the Next action
    } else if spoken == "repeat" {
        repeatInstructions()
    } else if let num = parseNumber(spoken), expectedType == .number {
        handleNumberInput(num)
    }
    break // exit after one command recognized
}
In this pseudo-code, parseNumber() would interpret number words (“five”) or digits (“5”) into an Int. We determine the command type expected (expectedType) based on context (e.g. awaiting a number vs a navigation command). Once a valid command is identified, we execute its handler and break out of the loop, ending that listening session. The UI is updated on the main thread to reflect the command (e.g. advancing to next screen) just as if the user tapped a button. To minimize latency for commands, we take advantage of fast on-device processing. The new SpeechAnalyzer model is extremely fast (often 2× faster than cloud models), so response should feel immediate. We further reduce delay by:
Using .fastResults to finalize short utterances quickly (less context waiting).
Stopping the analyzer as soon as a command is recognized (no need to continue listening to silence).
Optionally monitoring audio input volume: if no speech is detected ~1 second after a prompt, we can auto-timeout to avoid unnecessary waiting. Apple’s API doesn’t provide a built-in VAD module in this class, but we can observe the audio buffer’s amplitude to infer silence. For example, track buffer.averagePowerLevel; if below a threshold for N frames, consider the utterance done and call inputBuilder.finish() to force finalization.
Pre-warming the speech engine: on module start, instantiate SpeechTranscriber and call SpeechTranscriber.supportedLocales/installedLocales to ensure the language model is present. If not, download it in advance via AssetInventory.assetInstallationRequest
developer.apple.com
. This avoids any first-use delay mid-test.
Each command spoken will receive immediate visual feedback in the UI: for instance, if the user says “Next”, the app can highlight the “Next” button or play a subtle confirmation sound, so they know the command was heard. This builds trust in the voice interface.
Dictation & Free-Form Speech
Some SCAT5 modules require the user to speak longer content (e.g. reciting a list of words or a sentence). In these cases, the voice system switches to dictation mode:
We start a transcription session with a longer timeout (e.g. up to 30 seconds of audio) and allow multiple results.
The user may indicate when they’re finished speaking by saying a specific word (like “Done” or “Complete”), or simply by pausing. We listen for the “Done” keyword as a signal to stop. If detected, we stop the capture immediately (excluding the word "Done" from the stored transcript). If no explicit “Done” is heard, the session will end when the time limit is reached or after a few seconds of silence.
As partial results come in, we can optionally provide real-time feedback (for example, display the words as they are recognized in a temporary overlay). However, final results are used to officially record responses to avoid mistakes from volatile partial text.
The VoiceController will collect either the final transcript string or split it into tokens (words). For example, during Immediate Memory Recall, if the user speaks “apple… ball… cat…” and then says “Done”, the final recognized words array might be ["apple", "ball", "cat"]. We then compare each against the target list. In Notes dictation (Results Summary), the final multi-sentence text is inserted into the notes field. When implementing dictation, we reuse the same SpeechTranscriber but possibly adjust options: we might disable .fastResults if we prefer accuracy for longer speech, and rely on .volatileResults for a live preview. The architecture otherwise remains the same. The snippet below outlines handling a free-form response:
swift
Copy
Edit
// Start listening for up to 30s or until "Done" is spoken
try await analyzer.start(inputSequence: stream)
var transcript = ""
for try await result in transcriber.results {
    let text = result.text
    if result.isFinal {
        if text.lowercased().contains("done") {
            // Stop at "Done": trim it out
            transcript += text.replacingOccurrences(of: "done", with: "")
            break
        } else {
            transcript += text + " "
        }
    } else {
        // (Optional) show partial text in UI: e.g., overlay result.text
    }
}
// Clean up and process transcript...
In practice, the model will often break the input into segments (pauses create multiple result events). We accumulate them into one complete transcript. If the context expects discrete items (words, digits), we can also split on spaces after the fact. For example, let words = transcript.split(separator: " ") gives an array of recalled words. We then score or handle them as needed.
Integration in SwiftUI Views
We will integrate voice logic such that it fits naturally with the SwiftUI MVVM design of the app. Each module’s view or view-model will coordinate with the VoiceController:
Central VoiceController: We can maintain a singleton or environment object for the voice system. It manages the single SpeechAnalyzer session at any time. Alternatively, each module could create its own instance on demand. A singleton has the advantage of reusing the analyzer across modules (avoiding re-init costs), but you must reset commands between modules.
ViewModel callbacks: For example, the ModuleContext can expose methods like startListeningForCommand(commands: [String], callback: (String)->Void) or startDictation(duration: TimeInterval, callback: (String)->Void). The module’s SwiftUI view can call these when a voice input is needed. The callback from the VoiceController will arrive on a background thread (the results sequence runs asynchronously), so ensure to dispatch UI updates to the main thread.
Placing logic: The actual audio processing should happen outside the SwiftUI view (to avoid blocking UI and to handle lifecycle). We can, for instance, start the microphone capture in onAppear of a view or when a user taps a mic icon. The results handling can then call into the module’s ViewModel to update state. For example:
swift
Copy
Edit
struct SymptomView: View {
    @StateObject var viewModel: SymptomViewModel = ...
    @EnvironmentObject var voice: VoiceController

    var body: some View {
        // ... UI for symptoms ...
        .onAppear {
            // Start listening for symptom voice commands when view appears
            voice.startCommandMode(commands: viewModel.voiceCommands) { command in
                DispatchQueue.main.async {
                    viewModel.handleVoiceCommand(command)
                }
            }
        }
        .onDisappear {
            voice.stopListening()
        }
    }
}
In this pseudo-code, viewModel.voiceCommands might be an array like ["headache", "pressure in head", "yes", "no", "next"] depending on context. The handleVoiceCommand will interpret the string (e.g. if it's a number word, apply it as a rating). We stop listening when leaving the view to avoid capturing irrelevant speech. Concurrency considerations: We run the speech recognition in an async Task (as shown earlier) – this will likely live in the VoiceController. Because VisionOS can handle multiple tasks, ensure we cancel any existing recognition Task when a module ends to free the mic. Use inputBuilder.finish() and analyzer.finalizeAndFinish() to terminate cleanly, or simply cancel the Task loop. Each module below will detail where voice capture is initiated (e.g. on a button tap or automatically at certain steps) and how the recognized text is fed back into the SwiftUI state.
Fallbacks and Error Handling
Despite using a cutting-edge model, voice recognition isn’t 100% reliable. We design all voice features with graceful fallback:
Manual Alternative: Every voice-operable action can also be done via gaze or tap. For instance, if a voice command “Next” isn’t recognized, the user can still pinch the “Next” button. If dictating recall words fails (mic timeout or gibberish), the app will automatically present the on-screen keyboard for manual typing (as per the design specs). We detect failures via timeouts or unrecognized input. For example, in Immediate Memory, if no speech is detected within ~5 seconds of tapping mic, we might prompt “No voice input detected – please tap to type.” Similarly, if the speech result yields no known words (confidence very low), we fall back to typing UI.
Confidence and confirmation: The new API doesn’t explicitly return a confidence score per result, but we can infer confidence by how well the result matches expected patterns. For instance, in Symptom Checker, if the user says “Headache four” but the recognizer outputs “head ache for” (which doesn’t cleanly map to a number), we should be cautious. In such cases, the app can ask for confirmation: “Did you mean Headache 4?”. Because our command set is limited, an exact string match failing often implies a recognition error. We’ll handle a few common ambiguity cases (e.g. the word “to” vs “two”) by context: if a number was expected and we got a homophone, we map it to the number. The Orientation module, for example, highlights ambiguous answers for user confirmation.
Stability: If the user speaks too long or off-script (e.g. giving an explanation instead of a one-word answer), our logic will likely not find a command. We then ignore the input (no action taken) and could gently remind them of the expected format. The system’s design (short prompts, explicit expected answers) should minimize this scenario. For notes dictation, where free speech is allowed, we don’t need strict matching – we take whatever is transcribed and show it for editing.
Resource management: Only one module’s voice session runs at a time. We ensure to stop the SpeechAnalyzer when leaving a module to free the microphone for other uses (or system). This also avoids bleed-over of commands (e.g. saying “Next” in one module should not accidentally trigger something in another if one didn’t fully stop). The VoiceController will track an isListening state and prevent overlapping sessions.
By following these strategies, the voice control system remains non-intrusive: it enhances usability when it works, and when it doesn’t, the user can seamlessly revert to the familiar manual controls without frustration. The on-device speech model’s speed and accuracy provide a solid foundation for this lightweight voice UI.
Orientation Module – Voice Interaction
Module context: Orientation sub-test (standard SAC Orientation questions and optional Maddocks questions). The user (athlete) is presented with questions like “What month is it?” on separate cards, with multiple-choice or text input UI for answers. Voice input can streamline answering these questions hands-free.
Voice Commands in Orientation
Answer Selection: The athlete or clinician can speak the answer instead of using gaze selection. For example:
Saying “July” when the Month question is shown will select "July" from the month grid.
Saying “Seven” (or “7th” or “7”) for the Date question will highlight that date.
Saying “Thursday” for Day of week, “2025” for Year, or a time like “2:30 PM” for the Time question will fill those answers.
Card Navigation: The administrator can say “Next” to advance to the next question card, or “Back” to go to the previous one, instead of using gaze/pinch on the Next/Back buttons.
Repeat Question (optional): If the user didn’t catch the question, they could say “Repeat” to replay or reread the question. (This is optional; by default the question text is always visible, and Vision Pro’s design might not include audio for questions. Implement only if an audio prompt is provided.)
These voice commands are only active while the Orientation module card is in view. For instance, the “Next” command in Orientation will not be listened for once the module is complete or if another module is active.
Implementation Details
Starting voice capture: When an Orientation question card appears, start listening for a spoken answer. Since each question expects a short specific answer, we can start a fresh SpeechAnalyzer session for each card:
Set the expected vocabulary based on the question type:
For Month: the 12 month names.
Date: numbers 1–31 (as words “one”...“thirty-one” and digits).
Day: the 7 day names.
Year: likely a four-digit number (we can accept any number ~1900–2100).
Time: a time expression (which could be many forms).
We don’t have an official grammar constraint API, but we can post-filter transcripts. We run the transcriber and check if any of the expected answers appear.
Parsing logic: Upon final transcription:
Month/Day: We check if the recognized text (e.g. "july") matches one of the options. A direct string match (case-insensitive) works for months/days. If found, we programmatically select that button. For example:
swift
Copy
Edit
if question.id == .month, let idx = months.firstIndex(where: { spoken.contains($0.lowercased()) }) {
    selectMonth(months[idx])
}
This allows phrases like "Month: July" – since spoken.contains("july") would still find the month.
Date (number): We attempt to extract a number. We can use a NumberFormatter or our own mapping for number words. For instance, map "one"→1, "two"→2, ... "thirty"→30. Also strip ordinal suffixes ("7th" -> 7). If a valid 1–31 is obtained, select that date. If the user says a date outside 1–31 (unlikely), ignore it or ask again.
Year: The speech engine may output the year in digits (“2025”) or words (“two thousand twenty five”). We can try Int(text) to parse digits, and if that fails, use a number-word mapping for the year (or simply trust the transcriber – it often outputs years as numbers). Once parsed, fill the year text field. We also apply the validation: if the year is not within a reasonable range (e.g. 2015–2025 for current date), we might ignore or prompt confirm.
Time: Times are trickier to parse. We can look for patterns like “2:30” or “2 30” or “two thirty”. A simple approach is to leverage DateFormatter with formats or use regex to find numbers in the text. For example, if the result contains “2” and “30” and either “PM” or the hour > 12, we infer PM. Given the tolerance of ±1 hour, exact parsing is not critical; we mainly need to record what they said and check correctness. We could also accept any spoken time and let the OrientationModule.isCorrect(response) handle whether it’s within an hour. In practice, capturing the time as a string (e.g. “2:30 PM”) into the answer is sufficient; scoring logic can parse it.
Example – Month question: The user gazes at the “Month” card. The app calls voiceController.listenForAnswer(expected: monthsList). If the user says “Month July” or just “July”, the transcriber might output "month july" or "july". Our logic finds "july" in the expected list and selects that. The UI will then immediately auto-advance to the next question (since auto-advance is enabled on selection). Next/Back navigation: We continuously listen for “next” or “back” as well. One approach is to include these in the expected phrases at all times during this module. The voice controller for Orientation can accept “next”/“back” in parallel with answer words. If a “next” is recognized while an answer is still pending, we should only act on it if an answer was actually provided or if we allow skipping. Typically, we only go Next after an answer is selected (the UI auto-advances anyway). Therefore, the voice “Next” is mainly useful if auto-advance is turned off or for the clinician to skip a question (e.g. skipping Maddocks questions if not needed). We implement it such that a recognized “next” triggers the same code as tapping the Next button (advancing to the next question card immediately). “Back” similarly calls the Back navigation. Edge Cases & Confirmations:
If speech recognition yields a result that doesn’t clearly match an option, we do not auto-select. For example, if the user mumbles something and it transcribes to “jelly” (no month “jelly”), the app will simply do nothing, allowing the user to try again or use gaze. After a couple of seconds of no valid voice input, we can show a subtle hint like “Please say the answer or select it.”.
If a result is ambiguous (e.g. “March” vs “Mark” – though month names are distinct, or “to” vs “two”), our logic might not find a match and thus won’t act. The orientation spec specifically notes to confirm in case of ambiguity. In practice, the limited set of answers reduces this risk. If it does happen (say speech heard “four” for day and wrote “for”), we could detect that “for” is not a day but sounds like “four”, and ask “Did you mean Thursday (the fourth day)?”. This adds complexity, so the simpler route is: no match = no action.
Maddocks questions: These are optional, like venue or score of game. They aren’t multiple-choice; they rely on free response (and the clinician judging correctness). We can still use voice to capture the response. For example, if asked “What venue are we at?”, the athlete might say “Madison Square Garden.” The app can transcribe this and display it (perhaps for the clinician to mark correct or not). This is more of a dictation scenario. We can enable the mic and simply show the spoken answer in a text field on the card, which the clinician can then verify. Since Maddocks answers are open-ended, an automatic correctness check is not trivial – but at least voice can fill in the text so the clinician doesn’t have to type it.
SwiftUI Integration
Each Orientation question view can have a small microphone icon next to the question or answer field, indicating voice is available. However, to streamline, we might start listening immediately when the card appears (no icon tap needed) as a “speak now” prompt, since that’s a natural time to answer. We must ensure the app isn’t also picking up the clinician asking the question. If the question is presented only in text (no audio), then the user’s first speech should be their answer, which is fine. If the question were read aloud by TTS, we should not listen during playback (to avoid transcribing the TTS voice). In our case, questions are likely not spoken by TTS, so we can safely listen as soon as the card appears. We stop the listening as soon as an answer is accepted or when the user navigates away. This means if the user manually selects an answer, we cancel the voice task for that question to avoid it interfering in the background. Code example: When showing a question card, the view model might do:
swift
Copy
Edit
voiceController.startListening(expectedPhrases: currentQuestion.expectedAnswers + ["next","back"]) { spokenText in
    if currentQuestion.matchAnswer(spokenText) {
        self.recordAnswer(spokenText)
    } else if spokenText == "next" {
        self.goToNextQuestion()
    }
}
The matchAnswer function would implement the logic described (checking lists or parsing numbers). Note that for voice UI, we likely treat the spoken answer string as the response value directly (e.g. record “July” as if the user tapped July). The OrientationModule.recordAnswer(questionIndex:, response:) will then mark correctness. Using this voice integration, an athlete can potentially complete the orientation test without any controller input: they see the question in AR and speak the answers one by one, which can be more convenient if they’re disoriented or if a clinician is administrating verbally. All the while, manual selection is still available if voice fails or if the user prefers it.
Fallbacks
If after a few seconds the user doesn’t respond via voice, the system should not get stuck. The UI already has the prompt “Please respond to continue.” after 30s of no selection. We will likely rely on that. The clinician can then either repeat the question verbally to the athlete or manually nudge the selection.
If voice hearing is impaired (noisy environment), the clinician can disable voice and just use gaze/pinch. In app settings, we could include a toggle “Voice Input” to turn off listening if needed.
For the Time question, since voice input is complex, the clinician might opt to tap the answer. Our voice capture will do its best to transcribe, but if it produces something like “2 30” without AM/PM, the app might interpret it in context (if current time is 14:30, “2:30” could be understood as 2:30 PM). Edge logic can be applied, or the clinician can simply correct it manually. We will not over-engineer time parsing beyond simple patterns, to keep things maintainable.
Immediate Memory Module – Voice Interaction
The Immediate Memory module involves presenting a list of words and having the user recall them over three trials. We add voice support to allow the user to initiate the trials and speak the recalled words instead of using purely gaze/tap input.
Voice Commands in Immediate Memory
Start/Begin Trial: The administrator can say “Begin” (or “Start test”) to commence the word presentation of Trial 1. This is equivalent to pressing a “Start” button if one is present. (If the module auto-starts without user action, this command may not be needed. Include it if you want the clinician to control timing via voice.)
Recall by Voice: After words are presented and it’s time to recall, the user can say the words out loud. They should speak each remembered word, pausing briefly between words. They conclude their attempt by saying “Done” (or “Complete”) to indicate they’ve recalled all they could.
Next Trial: At the end of Trial 1 or 2, the clinician can say “Next” to proceed to the next trial immediately, bypassing any countdown. (By SCAT5 protocol a 2-second pause is standard, but if needed, voice “Next” could skip or confirm moving on.)
Repeat List: Not allowed during the test. We do not support a “repeat words” command during trials because SCAT5 does not permit repeating the word list outside the fixed trials. (If a trial had to be aborted due to interruption, the clinician would manually restart it.)
Interaction Flow with Voice
Trial initiation: When the Immediate Memory module is loaded and ready, it may display a prompt “Ready to begin Trial 1” with a Start button. At this point, voice recognition for the command “Begin” can be active. If the clinician says “Begin”, the app will start Trial 1 as if the button was pressed. We then disable voice listening during the word presentation (to avoid picking up the spoken words or other noise as input). Recall phase: As soon as the last word is presented and the recall prompt appears (microphone icon and “Please say the words you remember”), we enable speech capture for up to ~30 seconds:
The user taps the mic icon when they’re ready (or we could auto-start listening a second after presentation ends to capture immediate responses). Let’s assume explicit tap for clarity: The user gazes at the mic icon and pinches, which triggers our VoiceController to begin transcription in dictation mode.
The user starts speaking the list of words. We use the SpeechTranscriber to capture their speech. As they speak, we deliver real-time feedback:
If a recognized word matches one of the target words and hasn’t been said already, we fill one of the blank slots green and play a chime.
If a word is not on the list or is a duplicate, we flash a slot red with an error tone. (We might choose to do this feedback only for the final result to avoid reacting to mis-hearings of half-words, but since the spec calls for immediate feedback, we implement it on each recognized word confidently.)
The voice session continues until the user says “Done” or the 30-second timer elapses. When we detect the word “done” (or “I’m done”), we stop listening immediately. The word “done” is not part of any SCAT list, so we safely treat it as a terminator. (We will exclude “done” from the list of recall words before scoring.)
Upon termination, if the user was silent for a while or didn't say "Done", the system will finalize automatically at 30s. If nothing was recognized at all (e.g. user stayed silent), we consider it a non-response and could prompt “No words heard. You can tap to type if needed.”.
Processing recalled words: After the voice input ends (done or timeout), we have a collection of words the user said. The SpeechTranscriber might give us one final string like "apple ball cat" or an array of segments if they paused (often it will finalize each word as a separate result since the user pauses). We will aggregate them into a unique set:
swift
Copy
Edit
let spokenWords = transcript.lowercased().split(separator: " ")
let uniqueWords = Set(spokenWords)
Each spoken word is checked against the correct list (selectedList). For scoring, 1 point is awarded per unique correct word. We update the MemoryModule.trials data with what was recalled. We already gave immediate UI feedback during speaking, so by the end, the slots are filled green for correct words and any incorrect attempts would have flashed red and remained blank (per spec). We then show a “Next Trial in 2…1…” countdown. Subsequent trials: At Trial 2 and 3, the flow repeats. The user can again choose voice or fallback to manual. The voice commands “Begin” for starting the next trial could be enabled when the “Next Trial” countdown is displayed or if we require confirmation to start. However, since the app automatically starts the next trial after the short countdown, a voice “Next” could be used to skip the countdown. If we implement that, listen for “next” during the countdown state and if heard, immediately jump to showing the words of the next trial. After Trial 3’s recall, we record the end timestamp (for delayed recall scheduling) and finalize the module.
Code Snippets
Starting a trial via voice:
swift
Copy
Edit
// Ready state before Trial 1
voiceController.startCommandMode(commands: ["begin", "start test"]) { cmd in
    if cmd == "begin" || cmd == "start test" {
        startTrialOne()
    }
}
This would be set up when the module is first loaded (if a manual start is needed). startTrialOne() would perform the list presentation. Capturing recall via voice:
We encapsulate this in a function triggered on mic tap:
swift
Copy
Edit
func beginRecallListening() {
    voiceController.startDictation(timeout: 30) { resultText in
        // Split the final transcript by spaces into words
        let words = resultText.lowercased()
                           .replacingOccurrences(of: ".", with: "") // remove punctuation
                           .split(separator: " ")
        DispatchQueue.main.async {
            self.processSpokenWords(words)
        }
    }
}
Where processSpokenWords(_:) updates the UI and model:
swift
Copy
Edit
func processSpokenWords(_ words: [Substring]) {
    var alreadyCounted = Set<String>()
    for w in words {
        let word = String(w)
        if word == "done" || word == "" { continue }  // skip empties or "done"
        if selectedList.contains(word) && !alreadyCounted.contains(word) {
            // Correct new word
            markSlotFilled(with: word)
            playChime()
            alreadyCounted.insert(word)
        } else {
            // Not in list or duplicate
            flashSlotRed(for: word)
            playErrorTone()
        }
    }
    trials[currentTrialIndex] = alreadyCounted.map{$0}  // save recalled words
    // (Proceed to next trial or finish)
}
This pseudocode uses the UI helper methods to mark slots. We maintain an alreadyCounted set to avoid double-counting a word if the user accidentally repeats it (the spec says only first occurrence counts). We also ignore the “done” token. During the voice listening, we also implement immediate feedback: in a more advanced approach, we’d handle partial transcriber.results inside the loop. For each final word result, we could call processSpokenWords([word]) incrementally. However, the code above processes all at once at the end. If we want truly real-time feedback:
We can modify our loop: whenever result.isFinal == false (volatile result), do nothing, but when a final result comes in, it likely corresponds to one word (since the user pauses). We then process that single word immediately (update the UI slot). This is more complex to manage (must track slot usage live), but achievable. The specification explicitly describes immediate feedback per word, so implementing per-word final results is ideal.
Apple’s transcriber tends to finalize each word separately if the user pauses between them. We can rely on that behavior: each time result.isFinal comes with a result.text (like "apple"), we handle it and update UI, without waiting for “done.” Ending the voice session: If the user said “Done,” our logic breaks out of the results loop early. We then call voiceController.stopListening() which cancels the underlying recognition Task. The UI moves on.
Fallbacks and Edge Cases
No Voice Input: If the user doesn’t start speaking at all after tapping the mic (maybe they choose to type instead), we have a 30s timeout. As a safeguard, we could detect 5 seconds of silence and show a prompt or automatically pop up the keyboard (“Please type your answers”). The spec suggests prompting after 30s of no input. We can shorten that in practice to keep test flow moving.
Partial Recognition / Low Confidence: If the speech API produces a string that has very low confidence (e.g. lots of ??? in interim results or an empty final result), we should fall back. For instance, if after “Done” we ended up with an empty transcript or some garbled text that doesn’t match any list word, likely the recognition failed. In that case, the clinician can manually mark which words were recalled. (Alternatively, if the environment was noisy, one could hit “Repeat” to redo the recall trial, but this isn’t in protocol—so manual correction is the way.)
Accidentally speaking during word presentation: We disable or pause the recognizer when the words are being shown (the app is speaking the words via AVSpeechSynthesizer too). If the user inadvertently speaks or rehearses during presentation, we don’t want to capture that. Thus, the mic icon should be inactive until the presentation phase ends. We only call beginRecallListening() after that.
Multiple people speaking: In some test scenarios, a clinician might coach the patient. We have to ensure only the patient’s recall is counted, not the clinician’s voice. Ideally, the clinician stays quiet during recall. If needed, the clinician could use a mute switch or not tap the mic until the athlete is ready to speak. This is more procedural; technically the system can’t distinguish speakers (no speaker ID in SpeechTranscriber by default).
Module transitions: After Trial 3, the delayed recall timer starts (5 minutes). We definitely stop any ongoing speech tasks at that point. The user will later use voice in the Delayed Recall module separately.
Overall, voice greatly speeds up the memory recall scoring – the app can auto-record which words were recalled correctly without the clinician manually checking off a list. The combination of “Begin”, speaking words, and “Done” makes the interaction hands-free and efficient, while always allowing a fallback to tap if voice isn’t working well.
Delayed Recall Module – Voice Interaction
Delayed Recall occurs after a 5-minute interval, prompting the user to recall the same word list without seeing it again. The voice interaction here is very similar to Immediate Memory’s recall phase, but with only one trial.
Voice Commands in Delayed Recall
Begin Recall: If the module requires an explicit start (for example, a “Start Delayed Recall” button when the 5 minutes have elapsed), the clinician can say “Begin” to initiate the recall prompt. In many designs, the recall prompt appears automatically after the timer, so this voice command may not be needed. (Use it only if you give the examiner control to start.)
Recall Words: The user can speak all the words they remember from earlier, in any order, just like in Immediate Memory. They should say each word distinctly and then say “Done” when finished (or stay silent if they can’t recall more).
Submit/Finish: Saying “Done” triggers the app to end voice capture and finalize the results. There is no concept of multiple trials to say “Next” here – it’s one attempt.
Voice Recall Process
After the 5-minute countdown, a panel appears: “Delayed Recall: Say all the words you learned.” with blank circles for each word. At this point, we activate the microphone for the recall attempt:
The user likely will tap the mic icon to start (as per UI control). We start a SpeechAnalyzer session in dictation mode with ~30 seconds allowed.
As the user speaks words, we provide immediate feedback similarly to immediate recall:
Each correct word fills the next blank circle in green with a pleasant chime.
Incorrect words or repeats cause a circle to flash red and remain empty.
The user says “Done” when they cannot recall any more words (or the 30s runs out).
We stop listening and compile the list of spoken words. We compare against the original list (the app knows which list was used from earlier). We score 1 point per correct word (max 5 or 10 depending on list length).
Since this is a single trial, once “Done” is received, we finalize immediately:
swift
Copy
Edit
voiceController.startDictation(timeout: 30) { transcript in
    let spokenWords = transcript.lowercased().split(separator: " ")
    let unique = Set(spokenWords.filter{ $0 != "done" && !$0.isEmpty })
    let correct = originalList.filter { unique.contains($0.lowercased()) }
    result.score = correct.count
    result.recalledWords = correct
    // Update UI circles for any correct words not already filled
    // (Though we likely filled them live)
    finishModule()
}
In this pseudocode, originalList is the list of target words (we ensure to use the same list as in Immediate Memory). We already marked feedback live; the final computation mainly serves to store results. The UI might show which specific words were correct or just the count (filling all circles green if filled or leaving some blank). Live feedback: Because users might recall out of the original order, we can fill circles in order of recall or in a predetermined order. A simple approach: each time a correct new word is spoken, fill the next available circle. It doesn’t necessarily correspond to the word’s position in the list (and that’s fine). We just want to visibly count them. By the end, if they recalled 3/5 words, 3 circles will be green. Stopping conditions: The voice session will stop at 30 seconds regardless. If it stops without the user saying “Done,” that’s fine – it likely means time up or the user trailed off. We then proceed with whatever was recognized.
Additional Commands
There are typically no “Next” or navigation commands here, because Delayed Recall is a single step. Once done, the app usually proceeds to the next module (or summary). If needed, the clinician could say “Next test” to proceed to the next module, but more likely they’ll just gaze-select the continue button. We haven’t explicitly enabled “Next” here, but it could be part of a global command vocabulary if desired. If the user could not recall any words and is just silent, after the 30s we consider the trial over (score 0). We might prompt them at ~10s remaining: “Try to say any of the words if you remember.” – but that’s an UI/UX choice rather than voice input.
Fallbacks
If voice recognition fails (e.g. the user’s speech is very unclear due to injury), the clinician can tap “Tap to type” to open a keyboard and either the clinician or patient can type the recalled words. We detect failure if, for instance, no confident words were recognized. Our plan: if after one attempt the speech result yields zero matches and the user seems frustrated, automatically present the keyboard. (The spec suggests auto-fallback to keyboard after one failed attempt.)
Manual correction: The clinician can also manually mark which words were correct if needed. However, since our system already identifies correct words, this may not be necessary unless the speech engine misunderstood a word. For example, if the user said “eagle” but it transcribed “legal,” the app wouldn’t mark it correct. The clinician can override by seeing that and giving credit. In practice, we might not build a full override interface for this – instead, ensure high accuracy by possibly using custom vocabulary. (One idea: because we know the 5 target words, we could bias the recognition toward them. The new API doesn’t allow a custom word list directly, but we can post-process: if the transcript word has Levenshtein distance 1 from a target word, assume it was that word. However, this might be overkill. The built-in model is usually good at common nouns.)
The user will only have one opportunity. If they accidentally trigger “Done” too early (perhaps they said “I’m done” after 5 seconds, cutting themselves off), the clinician can choose to redo the trial by restarting the module (not standard, but possible if it was a mistake). We do not implement a voice command for “redo” – it would be a manual intervention outside normal flow.
Module Completion
Once the voice input is processed, the module calls context.completeModule with the DelayedRecallResult (which includes the recalledWords and score). Voice integration doesn’t change this, except it automates populating recalledWords. We capture the timestamp as required for audit. The app can then verbally or visually inform the user: “You recalled X out of Y words.” (No voice command needed here; it’s just feedback.) By using voice in both memory tests, the user experience is consistent. They know to speak the list of words and say “Done” when finished. This simplicity helps the concussed athlete focus on recalling words rather than fiddling with UIs. And because our system automatically checks each word, the clinician is free to observe the patient instead of tallying scores manually.
Concentration Module – Voice Interaction
The Concentration module has two parts: Digit Span (reciting digits backwards) and Months in Reverse. Voice input can significantly streamline both, allowing the athlete to speak their answers instead of using a keyboard or other manual entry. We’ll integrate voice carefully because these tasks require precise responses.
Voice Commands in Concentration
Start Digit Test: The clinician can say “Start” or “Begin” to initiate the Digit Span presentation, as an alternative to tapping a Start button.
Recall Digits: After each sequence of digits is presented, the athlete can speak the digits in reverse order. They just say the sequence continuously (e.g. if the digits shown were 7-2-4, and they need to recall backwards, they would say “4 2 7”). We capture this spoken sequence.
Done (Digits): Usually the athlete will stop speaking when finished with the sequence. We don’t explicitly require saying “Done” after digits, because the number of digits is known. However, to be safe, if the athlete isn’t sure and pauses, they could say “That’s all” or we simply detect the pause. We will automatically finalize when we detect a long pause or the expected count of digits have been spoken.
Next Sequence: If the clinician wants to manually skip to the next digit list (e.g. if the athlete clearly failed), they can say “Next” to proceed. Normally, the app auto-advances to the next sequence once an attempt is marked correct or incorrect, so this command may not be needed often.
Months Backwards: The athlete can recite “December November … January” out loud. This is effectively a free recall of a known sequence. They should attempt to say all months in reverse order in one go.
Done (Months): If they finish (reach “January”) or give up, a pause signals completion. They could say “Done” but typically finishing the word “January” is naturally the end. We’ll treat a reasonable silence after “January” as completion.
No other specific commands are expected. “Repeat” is not allowed (they shouldn’t repeat the sequence prompt). If they mis-hear a digit, the test protocol is to count it as wrong; we won’t implement “repeat digits” by voice.
Voice Interaction Flow
Digit Span Part:
Starting: The module might wait on a “Start Digit Span” prompt. Voice “Start” triggers runDigitSpan to begin with the first sequence. We then disable further start commands.
Presenting digits: During the 1-second paced display of digits (which might also be spoken by TTS), we keep the microphone off. We don’t want to capture the system speaking the digits.
Recall prompt: After the sequence, the UI shows blank slots for the athlete’s response and a mic icon. The athlete taps the mic (or we auto-start listening immediately when slots appear).
Listening for digits: We configure the transcriber to expect a short sequence of numbers. We can help it by restricting to digits if possible. Since there’s no direct grammar API, we’ll parse the output:
As the athlete says digits, the SpeechTranscriber will likely output them as words (“7 4 1”) or possibly numeral strings (“741”). Typically, it recognizes individual numbers as words in continuous speech. We handle both by mapping words to digits.
We allow up to ~10 seconds for a response (the spec says auto-advance after 10s of no response). If no speech for 10s, we time out and prompt manual input (“Please type the numbers”).
If the athlete finishes speaking sooner, we finalize early. We don’t require “Done” here—once they’ve said a sequence and then pause, the system can finalize. However, if they do say something like “done” or “that’s it,” we can accept that as a terminator (and ignore those filler words).
Processing digits: We compare the spoken sequence (in the order they gave) to the correct reversed sequence:
The app knows the original list (e.g. [7,2,4]). The correct reversed is [4,2,7]. We check if the spoken sequence exactly matches [4,2,7].
If yes, score 1 for that trial. If not, it’s a fail for that trial.
Regardless of correctness, we display what the user said: fill the blank slots with the digits they spoke.
If correct, we fill them in green with a chime.
If wrong, we fill what they said until the mistake: for example, if sequence was 4-2-7 and they said “4 2 9”, we would fill 4, 2 in green and then the 9 triggers an incorrect – the third slot might flash red. (Spec says highlight first mistake then end.) We can implement: when a mismatch is detected, flash that slot red and stop – do not fill remaining slots.
If they gave fewer digits than expected (e.g. only said two digits when three were expected), that’s incorrect; we might flash the next empty slot red to indicate an incomplete response.
We then either move to the next list or stop according to the SCAT stop rule (2 consecutive fails).
Next via voice: The app automatically calls the next sequence after a brief confirmation pulse. We likely don’t need a “Next” voice here. But if the test required manual confirmation, voice “next” would trigger runDigitSpan for the next index. Our implementation can include it just in case:
Listen for “next” in the brief interval after marking a trial result. If heard, it skips any remaining wait and goes on.
If the stop rule met (two fails), module would auto-skip to Months section; a “next” command at that point might directly jump to Months if for some reason it hasn’t already.
Months in Reverse Part:
The Months part likely has a “Recite the months backward” prompt and again a mic icon. When the athlete is ready, they hit the mic or just start speaking if auto-listen is enabled.
Listening: We capture up to 15 seconds of speech. We expect a longer utterance (12 month names). The SpeechTranscriber will transcribe a continuous phrase. It might output the months separated by spaces (ideal), or sometimes with commas – but likely just spaces.
As they speak, we could give subtle feedback: perhaps fill a list or count how many they’ve said. However, the spec suggests we highlight the first mistake if they get it wrong and then end. This is a bit challenging to do live without knowing when they’ll finish. Instead, a simpler approach:
Let them speak the whole sequence without interruption (no real-time correction).
Once final, we compare their spoken sequence of months to the correct sequence (Dec→Jan).
If it matches exactly, we score 1 (pass) and maybe display a “✔️ All months correct” message or just a chime.
If not, we find the first point of error. For example, if they said “December, November, … June, (and then wrong month)”, we identify the first wrong month. We can highlight that point – perhaps by listing the months and marking where they erred. In VR, maybe the UI is a scrollable list of months; we could highlight up to the point they got right, then flash the next one.
We score 0 in any case of an error (SCAT requires the entire sequence correct for 1 point).
Provide gentle feedback: maybe “Incorrect – sequence not completed” along with the visual highlight of mistake.
The user doesn’t need to say “Done” after “January” – the silence after finishing should finalize the transcript. If they stop early (didn’t reach January and went silent), the system will finalize after a pause. That will obviously be incorrect (they didn’t list all 12). We count that as 0 and mark where they stopped as the mistake (stopping early is effectively forgetting the remaining months).
Example: The athlete says: “December November October August …” (skipping September). The transcription might be "december november october august ..." until they trail off. Our logic compares to the expected:
December (correct 1st), November (2nd), October (3rd), expected next is September but they said August. So at the 4th month, there’s a discrepancy. We highlight “September” as missed (or highlight “August” as out-of-order). We then stop – no need to analyze further months since any error yields 0 score.
The UI might show the correct sequence with a red mark at “September” to indicate that’s where it went wrong, or simply a message “Sequence incorrect”.
We’ll implement a straightforward check:
swift
Copy
Edit
let spokenMonths = transcript.lowercased().split(separator: " ")
let targetMonths = ["december","november",...,"january"]
var allCorrect = true
for (i, month) in spokenMonths.enumerated() {
    if i >= targetMonths.count || month != targetMonths[i] {
        allCorrect = false
        markMonthIncorrect(index: i)
        break
    }
}
if allCorrect && spokenMonths.count == targetMonths.count {
    score = 1
    playChime()
} else {
    score = 0
    playErrorTone()
}
This pseudo-loop checks each month in order until a mismatch. We also ensure they said all 12 (if they only said 11 months, that’s a failure, we’d catch it by length check after loop). Because the months task is essentially free recall of a known sequence, we don’t give partial credit or intervene mid-speech with voice cues. It’s either pass or fail.
SwiftUI Integration
For each digit trial:
After displaying the digits, the module calls something like:
swift
Copy
Edit
voiceController.startDictation(timeout: 10) { spoken in
    self.processDigitResponse(spoken)
}
This is triggered either automatically or on mic tap for that trial. We might actually design it to auto-listen to reduce friction (the athlete knows to respond immediately after digits). However, to avoid confusion, using the mic tap as a clear signal is okay.
In processDigitResponse(_:):
We parse the spoken string for digits:
swift
Copy
Edit
let cleaned = spoken.lowercased().replacingOccurrences(of: "done", with: "")
let digitsSpoken = cleaned.split(separator: " ").compactMap { wordToDigit(String($0)) }
where wordToDigit maps "zero"/"0"->0, "one"->1, ..., "nine"->9.
If digitsSpoken is empty (no recognized digits), we treat it as no response.
We compare digitsSpoken to the expected reversed sequence (currentSeqReversed). Set isCorrect = (digitsSpoken == currentSeqReversed).
Update UI: fill slots with each spoken digit. If a digit was wrong or missing:
For the first position where digitsSpoken[i] != currentSeqReversed[i], flash that slot red (and we can stop filling further slots).
If the lengths differ (user gave too few or too many digits), that’s automatically incorrect:
If too few, the first missing digit is the mistake point.
If too many (unlikely, giving extra digit), the extra digit is wrong.
Call advanceToNextTrial(isCorrect) which adds score if correct and either goes to next or ends digit span (if 2 fails in a row).
For months:
On the months screen, likely we’ll have a mic the user can tap. We start listening for up to 15s as soon as they tap.
After getting the transcript, processMonthsResponse(transcript) does the loop as above to check each month.
Update UI: We might simply present the spoken sequence and maybe highlight the mistake. To keep it simple:
If correct, display a success (maybe fill the list green, though UI spec said just a chime).
If incorrect, maybe highlight the first wrong month name in red. For instance, we could have an invisible text of all months that becomes visible to show the comparison. Or flash the panel to indicate an error.
Then call finishConcentrationModule() with score (0 or 1 for months, plus whatever digit score accumulated).
Throughout, fallback is always possible:
For digits: a “Tap to type” toggle opens a numeric keypad. Our logic: if after 10s no voice input or the user presses the type toggle, we cancel voice and let them use the keypad. If the voice came through partially but the user switches to typing, we should probably discard the voice result (to avoid double answers).
For months: the UI provides an optional scrollable list of months that can be gaze-selected (perhaps if the person can’t verbalize, they could select months in order). If voice isn’t working (maybe the athlete mixes up order verbally), the examiner could ask them to use that list. Our voice code will simply timeout or yield an incorrect result; the clinician can then decide to manually mark it. There’s no easy partial credit logic; either they eventually get it via selection or accept the fail.
If at any point voice recognition mishears (e.g. in digits, “1” heard as “one” which is fine, or “8” heard as “ate” – our mapping still gets 8, so that’s fine; numbers are usually recognized well). For months, misrecognition is more likely if the athlete’s enunciation is poor (e.g. “August” might be misheard as “office”?). Because any error = 0 score anyway, a misheard month or a truly wrong month are the same outcome. The clinician can use judgment if the transcript was wrong but the athlete actually said correct – but that requires them noticing and possibly re-testing. In a strict app, we’d go with what’s transcribed. To mitigate, ensure the device’s microphone is close/good quality (Vision Pro’s mics are high-quality and in a quiet environment it should be fine).
Voice Commands Summary
“Start” – begins the digit span test.
(no explicit command needed to end digit input – just silence) – the system detects end of response for digits.
“Next” – skip to next digit sequence (optional; generally auto).
“Repeat” – not used, no repeats allowed.
Digit utterances (“7 1 4…”) – captured as the answer.
Month sequence (“December … January”) – captured as answer.
“Done” – not required but if said, will terminate capture early (we ignore the word “done” in content).
By implementing voice in this module, the athlete can simply speak their answers, which is usually faster and less cognitively taxing than fiddling with pinch gestures on small keypad buttons (especially when already doing a mentally challenging task like backwards digits). It also frees the clinician from manually checking if the sequence was correct – the app does it instantly.
Symptom Evaluation Module – Voice Interaction
The Symptom Evaluation module involves the athlete (or clinician) rating 22 symptoms on a 0–6 scale, plus two yes/no questions and a 0–100 percentage slider. This is largely a form-filling task, and voice can make it much faster by allowing spoken ratings and toggles. Our voice integration will be context-aware: it uses gaze context (which symptom is focused) plus key phrases to set values.
Voice Commands in Symptom Module
Symptom Rating by Number: While a symptom card is highlighted (center of the carousel), the user can say a number “0” through “6” to set that symptom’s severity. For example, if “Headache” is the active card and the athlete says “5”, the app will record a headache severity of 5. This is equivalent to gazing and pinching the 5 on the Likert scale.
Symptom Name + Number: The clinician can verbalize a rating in one phrase. For instance, “Headache four” will immediately set Headache = 4. This is useful if the athlete verbalizes their rating and the clinician just repeats it to the device. It also allows setting a rating for a symptom that isn’t currently centered: e.g. say the “Pressure in head” card is not front-and-center, but the clinician says “Pressure in head six” – we can interpret that and update that symptom’s value. (If we implement this, we’ll need to bring that card to focus or at least update it in the data model.)
Toggle Questions – “Yes/No”: For the “Worse with physical activity?” and “Worse with mental activity?” toggles, the user can say “Yes” or “No” when that item is in context:
If one of those toggle buttons is focused (user gazing at it), a spoken “yes”/“no” will toggle it accordingly.
Alternatively, the user can say “Physical yes” or “Physical no”, “Mental yes/no” at any time in the symptom module to set those specifically. This uses keyword matching: we listen for “physical” or “mental” along with yes/no.
Percent Normal Slider: The user can set the 0–100% slider via voice in a phrase. The design specifically suggests “Set percent normal to 80%”. We will support commands of the form:
“[number] percent” or “[number] percent normal” or “normal [number]”.
The number can be 0 to 100. We parse the number and update the slider value accordingly.
For example, saying “80 percent” will move the slider to 80%. Saying “100 percent” sets it to 100, etc. We’ll also allow just the number by itself if the slider is focused (but because numbers alone could also be symptom ratings, we prefer the user include “percent” to differentiate).
Navigation – “Next/Previous symptom”: The user can say “Next” to scroll to the next symptom card in the carousel, or “Previous” to go to the prior card. This voice alternative to swiping can speed up moving through the list, especially if the clinician’s hands are occupied.
Module Completion – “Done” (optional): Once all ratings are entered, the clinician might say “Done” to indicate completion, but since the module likely finishes when they scroll past the last item or hit a finish button, we may not need a voice command. We could map “Done” to pressing a finish/summary button if one exists.
Voice Command Implementation
The Symptom module’s voice interaction benefits from knowing which UI element is in focus:
We track which symptom card is centered (via gaze or programmatically). Let’s call it currentSymptom.
We also know if the user’s gaze is on a toggle or the slider at any given time (we can get this from focus events or by the fact they highlighted it).
We will run a continuous SpeechAnalyzer session throughout this module (since the user might rapidly go through symptoms and voice-rate them). This is one case where always-on listening in context is useful. We will filter the recognized speech for our commands. Specifically:
Whenever a final result comes in, parse it:
If it’s exactly a number “0”–“6” (or word “zero”–“six”), and a symptom card is in focus, treat it as a rating for currentSymptom.
If it contains a symptom name and a number (e.g. “neck pain 3” or “sadness six”), find if that symptom name matches one of the 22. We can have a dictionary of symptom keywords:
swift
Copy
Edit
symptomKeywords = ["headache": "Headache",
                   "pressure in head": "Pressure in head",
                   "neck pain": "Neck pain", ... ]
We’d check each key if it appears in the spoken text. For reliability, require the number to be present as well. Example: spoken "pressure in head six". We find "pressure in head" in it and also extract the number 6. Then:
swift
Copy
Edit
model.ratings["Pressure in head"] = 6
And we update that card’s UI (if it’s not visible, perhaps briefly flash it or just trust that when the user scrolls, it’s set).
If it’s “yes” or “no”:
If the currentSymptom is one of the toggle questions (“Worse with physical activity” or “...mental activity”), we apply it to that. For physical: yes→toggle on (true), no→toggle off (false).
If not focused, but the text includes “physical” or “mental”, we handle accordingly:
“physical yes/no” sets the physical activity toggle.
“mental yes/no” sets the mental activity toggle.
If it’s a percentage command:
We look for a number up to 100 in the text and the word “percent” or “normal”. If found:
swift
Copy
Edit
model.percentNormal = number
Update the slider UI to that value (programmatically move the thumb).
Example: spoken "set percent normal to 80%". We parse number 80, set slider to 80.
Another example: spoken just "50 percent". Same outcome.
If the user just says "50" while focusing the slider, we can also treat that as 50%. But to avoid confusion with symptom ratings, we might prefer they include "percent".
If it’s a navigation word:
“next” or “next symptom” -> programmatically scroll carousel to next card. We can call the same method as a swipe gesture would. Also update currentSymptom.
“previous” -> scroll to previous.
We might also allow “go to [symptom name]” (not requested, but in theory one could jump by name. We won’t implement this unless needed, because sequential navigation or voice naming the symptom with a rating covers the use case.)
Continuous listening: We keep this voice session open as the user goes through all items. That means handling multiple results sequentially:
We do not break after one command; instead, after processing one utterance, we continue listening for the next. The session can last several minutes theoretically (the entire time the user is rating symptoms). Apple’s SpeechAnalyzer can handle long form input, but to be safe, we might restart it after a long silence or after a certain count of recognitions. However, since commands are short and sporadic, it should be fine.
We likely should allow brief pauses without cutting off. Using .volatileResults the system will give partial words and then finalize. We rely on final results to act. Example workflow:
The athlete is looking at “Headache” card. Clinician asks “How bad is your headache on 0-6?” Athlete says “four.” The device hears “four”:
Recognizes "four" (final result).
currentSymptom = Headache, so we set Headache=4.
The UI card “Headache” animates the slider or rating to 4 (maybe the card UI had 7 radio buttons 0–6; we highlight the one for 4 as if pinched).
The app auto-advances to next card “Pressure in head” (say we implemented auto-scroll on voice input, or clinician swipes or says “Next”).
Athlete says “two.” The device: currentSymptom=Pressure in head, sets 2.
Next card: “Neck pain.” Suppose the clinician directly says “Neck pain zero” (maybe jumping backward or reaffirming). Device finds "neck pain" in phrase and number 0, sets that rating.
The athlete might skip voice on some and pinch manually – that’s fine, voice will still be listening but nothing triggers.
For “Worse with physical activity”, the clinician can just ask the athlete. If athlete says “Yes”, device hears “yes” while currentSymptom is that toggle -> sets toggles on = true.
Or if the athlete doesn’t speak, clinician can voice it: “physical yes” to mark it.
For percent normal: the user might gaze at the slider, then say “eighty percent.” Device sets slider=80. (We’ll ensure to update the slider UI position accordingly by calling the same code as dragging it.)
They reach the end. The clinician could say “Done” if there’s a finish step; if not, they just navigate away which ends the voice session.
Throughout this, we maintain an updated SymptomResult in the model:
The ratings dictionary gets filled as each rating is set (via voice or manual).
The two booleans worsensPhysical, worsensMental get set on yes/no.
percentNormal gets set on that slider command.
We need to ensure the UI and voice do not conflict:
If the user also manually interacts (e.g. pinches a number), that updates the model too. If voice hears a number at the same time, we might double-set to same value – which is benign. The risk is if voice misfires and sets a wrong value while the user was about to set another. But the user can always override by immediately pinching a different number. Our voice input will not lock out manual input at any point; manual changes should override or update seamlessly.
Voice Confirmation: The spec mentions if speech is ambiguous, confirm with follow-up. For example, if the user says “four” but we somehow aren’t sure which symptom it was for (shouldn’t happen if we track focus), or if a phrase wasn’t clearly parsed, we might ask “Did you say Headache 4?”. Given our approach, ambiguous cases are few:
If the user just says a number when a symptom card is focused, it’s unambiguous for that symptom.
If they say symptom name + number, it’s explicit.
Possibly confusion between symptoms with similar names? Not likely (they are all distinct terms).
One case: If they say “no” when not on a toggle question – does it mean 0 rating or they were answering a yes/no? If current card is a symptom slider, a "no" might be misinterpreted. We will interpret any “yes/no” strictly for toggles. So if someone says “no” on a symptom card, we might ignore it (since presumably they meant 0? But they should say "zero", not "no"). To avoid mis-setting 0 vs no, we won’t treat “no” as 0. Only number words or digits set a rating. “No” is reserved for toggles.
Another potential: The word “one” vs “won” or “want” in conversation. If extraneous talk is picked up, could be an issue. However, since we assume the environment is an exam, extraneous speech is minimal.
If a voice command is picked up incorrectly (e.g. device thought it heard “five” when the athlete didn’t say anything, due to noise), the visual feedback (slider moving to 5) will alert the clinician, who can immediately correct it (e.g. set it back to 0). To minimize false triggers, we might set a confidence threshold: only accept the transcription if it’s clearly a number or known phrase. Usually, random noise won’t form a valid word like “five” with high confidence.
SwiftUI Integration
We will likely attach the voice listener at module start:
swift
Copy
Edit
voiceController.startContinuous(commands: symptomCommands, partialResults: false) { text in
    self.handleSymptomVoice(text)
}
Here, symptomCommands might not explicitly enumerate every possible phrase (that would be a lot), but the handler will parse dynamically. We might just keep it open to any speech and do parsing inside handleSymptomVoice. handleSymptomVoice(_ text: String) in the SymptomViewModel does what we described:
swift
Copy
Edit
func handleSymptomVoice(_ spoken: String) {
    let utterance = spoken.lowercased().trimmingCharacters(in: .whitespaces)
    if let num = parseRatingNumber(utterance) {
        if currentItem.isSymptom {
            // It's a 0-6 rating
            setRating(for: currentItem.name, to: num)
        } else {
            // If current item not a symptom slider, maybe ignore or treat as percent if slider
            if currentItem.isPercentSlider {
                setPercentNormal(num)
            }
            // if it's a toggle question, a bare number is irrelevant (ignore)
        }
    } else if utterance == "yes" || utterance == "no" {
        if currentItem.id == .physicalToggle {
            worsensPhysical = (utterance == "yes")
        } else if currentItem.id == .mentalToggle {
            worsensMental = (utterance == "yes")
        }
        // Otherwise, if not on a toggle, ignore a lone yes/no
    } else if utterance.contains("yes") || utterance.contains("no") {
        // Check combined commands like "physical yes"
        if utterance.contains("physical") {
            worsensPhysical = utterance.contains("yes")
        }
        if utterance.contains("mental") {
            worsensMental = utterance.contains("yes")
        }
    } else if utterance.contains("%") || utterance.contains("percent") || utterance.contains("normal") {
        if let percent = parsePercentage(utterance) {
            setPercentNormal(percent)
        }
    } else if utterance == "next" || utterance == "next symptom" {
        goToNextCard()
    } else if utterance == "previous" || utterance == "back" {
        goToPreviousCard()
    } else {
        // Check symptom name + number pattern
        for (key, symptomName) in symptomKeywords {
            if utterance.contains(key), let num = parseRatingNumber(utterance) {
                setRating(for: symptomName, to: num)
                // If the spoken symptom is not current, optionally navigate to it:
                if symptomName != currentItem.name {
                    jumpToCard(named: symptomName)
                }
                break
            }
        }
    }
}
This pseudo-code tries various checks. parseRatingNumber will map number words or digits to 0–6, and ensure the utterance is just that number or has only that number (to avoid parsing the "100" in "100 percent" as a symptom rating inadvertently). parsePercentage would find a number in 0–100 in the string. We must ensure order of checks avoids misinterpretation:
Check explicit yes/no first so "no" doesn’t become 0.
Check percent before interpreting a number in it as a symptom rating.
Only then check bare numbers for symptom rating.
Updating UI and model:
setRating(for: symptomName, to: num) will update the SymptomUIController to mark that card as selected at that number (e.g. highlight that rating). If the card is currently visible, just update it; if not, store it in data (the next time that card scrolls into view, it will show the selected rating).
setPercentNormal(percent) will programmatically move the slider thumb to that value and update ui.sliderValue.
Toggling yes/no will update the toggle button state (we can call the same logic as if pinch toggled it, triggering the UI binding).
Navigation commands call the same functions as swipe gestures to move the carousel.
One technical nuance: Continuous listening vs push-to-talk – The symptom spec implies voice fallback continuously (the clinician could just speak values as they go). To implement continuous recognition with SpeechAnalyzer, we started one session at module start and keep it running. We should be mindful of performance: The model might be listening the whole time, but since our phrases are short and discrete, it should handle it. If there’s a long lull (the athlete might take time rating on their own), the recognizer might keep waiting. It’s fine – Apple’s on-device model is efficient. We just need to ensure it doesn’t accidentally finalize due to a long silence and then require restart. The SpeechTranscriber by default might finalize an utterance after some silence and continue listening for the next (especially with .continuous behavior). We will observe that in testing and adjust if needed by either restarting or using the .continuous mode if available (the WWDC examples show handling long input in one go, so it likely continues until we explicitly stop).
Fallbacks and User Experience
Manual always available: The interface is fully operable by gaze/pinch, so if voice fails on a particular symptom (e.g. it didn’t catch the number), the clinician can just pinch the rating. The voice system will hear that as well (maybe the athlete says it again or so), but even if it misfires, the manual action corrects the record.
Misheard numbers: If the engine misrecognizes a number (say athlete said “six” and it heard “sticks”), our logic might not find a valid command and thus do nothing – which is actually good (better to do nothing than to do something wrong). The clinician can prompt the athlete to repeat or just manually input.
Double inputs: If both the athlete and clinician speak at the same time (e.g. athlete says “six” and clinician repeats “six”), the recognizer might merge or confuse the audio. To avoid echo, it’s best only one speaks. This is a matter of training the test administrators. Our system can handle if an utterance like “six six” comes through – it will parse a number (six) and likely ignore the rest or treat it as symptom name? But "six six" doesn’t fit a pattern except maybe two separate results “six” and “six”. Possibly the transcriber would finalize the first "six" then pick up the second as another result. If that happens, we’d set the rating twice (harmlessly the same value). It’s not ideal but not catastrophic.
Ending voice session: When the module ends (the summary or next module is about to show), we stop the SpeechAnalyzer to free resources. This likely happens when the user presses “Done” or navigates away from the last card.
After using voice, the Results Summary will reflect all inputs the same as if manually entered (voice doesn’t change how data is stored, just how it’s input). We ensure to populate TestSession.symptomCount and symptomSeverity automatically from the collected ratings when completing the module (this is likely in the module’s existing complete() logic). Voice input in the symptom module can dramatically speed up the evaluation – especially if the clinician can just say e.g. “Headache six, Pressure five, Neck pain zero, Nausea three, ... Physical yes, Mental yes, 70 percent.” Potentially, the clinician could speak out an entire set of results in one go. Our system isn’t designed to handle a long chain in one utterance (that would require parsing a complex sentence). But doing it one by one is still much faster than clicking through 22 items. We’ll encourage a cadence: focus a card, speak the number, say “Next”, speak next number, etc. This keeps it clear and within our recognition scope. Finally, we carefully handle the percent slider with voice because it’s a unique input. We might verbally confirm if the athlete says a very high or low number to ensure no mistake (e.g. if they intended to say 90 but said 19, the clinician should catch it). But that’s more on the clinician to verify – our system will just take it literally.
Balance Module – Voice Interaction
The Balance Examination (mBESS) involves three stances, each timed for 20 seconds, and counting errors (postural stability errors). Voice control in this module is primarily to help the examiner operate the timer and record errors without looking away from the athlete.
Voice Commands in Balance Module
“Start” (Stance) – Begin the 20-second timer for the currently selected stance. Equivalent to tapping the “Start” button on the stance card.
“Stop” – Manually stop the timer early. (Normally, the timer runs the full 20s. We might include “Stop” in case the athlete falls off stance and the examiner decides to abort early. This is optional; in standard protocol you still try to complete the time if possible.)
“Next stance” / “Next” – Move to the next stance card once the current trial is done. This corresponds to tapping “Next Stance”.
“Error” – Increment the error count for the current stance by 1. This is the most useful voice command: the examiner can simply say “Error” each time the athlete commits an error (hands off hips, stumble, etc.), instead of pinching the “Error +1” button.
“Reset error” (optional) – If an error was recorded by mistake, the examiner could say “Undo” or “Reset” to decrement the count by 1. (The UI has only an “Error +1” button, no minus, but we can implement voice “undo” if desired for convenience. However, we must ensure not to misuse it; maybe we skip this to stay aligned with UI which doesn’t provide minus.)
“Repeat” – Not really applicable; you don’t repeat a stance unless something egregious happened outside of test (in which case, the examiner could manually restart the stance).
There are no numeric inputs or complex phrases needed in this module since it's largely event-driven and navigational.
In summary: “Start”, “Error”, “Next stance”, and possibly “Stop”/“Undo” are the commands.
Implementation Details
We will use continuous listening during each stance trial, specifically to catch “error” utterances. The voice flow:
Between stances: When ready to begin a stance, the examiner can say “Start” instead of pinching the Start button. Our voice handler will detect "start" and call the same logic as pressing start: begin the 20s countdown timer for that stance. Once the timer starts, we likely automatically enable error-count voice commands.
During stance (20s): The examiner stands back observing the athlete. We keep the SpeechAnalyzer running and specifically listen for the word “error” (and possibly “stop”). Each time “error” is recognized as a final result, we:
Increment the error counter (errors[currentStance] += 1) and update the UI label “Errors: X” on the stance card.
Flash the “Error +1” button visually to acknowledge it (similar to how a tap would cause a flash +1 and maybe a haptic on watch). We can programmatically trigger the same animation/haptic.
The app will count errors up to 10 (max) per stance. We will still listen after 10, but if an “error” comes through beyond 10, we can ignore it or just not increment above 10 (the UI should cap it and possibly disable the button).
We do not break the listening loop on each “error”; we continue listening to catch multiple errors. Essentially, each time the model finalizes “error”, we handle it and keep going. We might get partial results like “err…” but we wait for final to be sure the word was detected.
We also watch for “stop” during the trial. If, say, the athlete cannot continue and the examiner wants to cut it short, saying “Stop” would end the timer early. Implementation: if “stop” is recognized:
Immediately end the timer (as if the time ran out). We might call the same function that runs when 20s completes, to wrap up the stance.
We would not normally do this unless needed, but voice gives the option without reaching for a controller. We’ll support it, but the standard flow is to wait 20s.
After 20 seconds, the stance automatically ends (or if “stop” invoked). We then either:
Auto-advance to the next stance with a prompt. The UI likely shows a “Next Stance” button that the examiner must tap. We can allow voice “Next” at this point:
As soon as the stance is over, voice recognition still running can catch “next” to trigger the transition. Or the examiner can just say “Next stance” while the result summary of that stance is displayed.
Alternatively, we might auto-advance after a second or two, but per UI spec it shows a Next button. So using voice to press it is appropriate.
We should reset the error count voice listener when moving to next stance:
The word “error” will still be relevant for next stance, so we continue listening, but we should be mindful if the examiner says something like “That’s the last error” after stance – if it hears “error” outside the timer period, it might incorrectly add. To avoid that, we might enforce that error increments only count while the timer is running (which makes sense – errors are only counted during the 20s trial).
Implementation: perhaps enable the “error” command only between “Start” and end-of-timer. We can do that by an internal flag or by starting a sub-listening session.
E.g., we can start a dedicated SpeechAnalyzer when the stance starts, and stop it when time’s up. But since our architecture can handle continuous, we could also just ignore “error” commands outside the active period.
After the final stance (tandem stance) completes, the module finishes. At that point, we stop listening for these commands (module done).
Accuracy considerations:
The word “error” is quite distinct, but we should consider accents – some might say it more like “err-er”. Our recognizer should catch it given context, but as a backup, we could consider synonyms: maybe “fault” or “miss” if an examiner chooses different words. To keep it simple, we stick to “error” since that’s in SCAT instructions.
Because we use on-device recognition, there’s no lag; saying “error” should register almost immediately (within a fraction of a second). This is crucial so the examiner doesn’t lose count mentally. We will trust the SpeechAnalyzer to be fast (which tests have shown to be the case).
If the recognizer ever mishears something as “error” (like the examiner coughs “err” and it thinks it’s “error”), it might increment erroneously. However, the examiner can correct this via the UI (though no minus button exists, they could note it mentally or restart the stance). If we implement “undo” voice command, they could say “undo” to subtract one. Let’s implement a simple undo:
If “undo” or “reset” is heard and we are currently counting errors (and errors count > 0), then decrement by 1.
Make sure to not go below 0 and maybe provide a quick visual feedback (maybe flash the error count or something).
We have to be careful that "no" isn't misheard as "undo" – unlikely. “undo” is distinct, we can also allow “minus one” as a phrase if needed.
Code integration:
When a stance card is shown, we have:
swift
Copy
Edit
voiceController.startCommandMode(commands: ["start", "stop", "next", "error", "undo"]) { cmd in
    switch cmd {
    case "start":
        if !timerRunning { beginStanceTimer() }
    case "stop":
        if timerRunning { endStanceTimer(early: true) }
    case "next":
        advanceToNextStance()
    case "error":
        if timerRunning { recordError() }
    case "undo":
        if timerRunning { undoError() }
    }
}
This pseudo-handler processes recognized commands:
Only allow “error” to call recordError() (which increments count and updates UI) if timerRunning is true.
Similarly, maybe only allow “undo” if timerRunning and errors count > 0.
“start” only if timer not already started (to prevent double triggers).
We might run this listening continuously through the whole module, or start it at the module beginning. It could run continuously because those keywords are not likely to conflict with normal speech (and ideally during the stance the examiner isn’t chatting beyond saying these commands).
Another approach: Start listening for “start” when stance is ready, then upon “start”, switch to a mode where “error” and “stop” are listened for intensively. But managing switching might not be necessary if one session can handle all and our code just ignores commands that are not relevant at the time (like ignoring “error” before start).
Visual Feedback for Voice Commands:
On “Start” via voice, the timer ring should start and perhaps the Start button could flash to acknowledge voice trigger.
On “Error” via voice, as mentioned, flash the “+1” button and update the counter immediately. The Apple Watch haptic (if paired) can also buzz as it would on manual tap (we can trigger the same code path that sends the haptic to Watch).
On “Next” via voice, the UI will transition to next card – we ensure it looks the same as if button pressed.
Edge cases:
If for some reason the recognizer picks up “next” or “stop” from background conversation or noise (not likely in a quiet exam, but suppose someone else says something), it could prematurely end a stance. The examiner should always be in control, so hopefully extraneous talk is minimal. Since we only have examiner and athlete there, if the athlete talks during the test (they shouldn’t, but if they exclaim “oops” or something), it wouldn’t match our keywords so fine.
If the examiner forgets to say “start” and instead manually presses it, our voice system is still listening. It might catch them saying “Begin stance now” to the athlete. If it hears “begin” which is not explicitly listed, nothing will happen (we use “start” as keyword). If we want to handle synonyms, we might include “begin” as trigger for start as well. Could do: commands: ["start", "begin", ...].
Limit "error" count: after 10, recordError() should stop incrementing. Our UI disables the button after 10 errors (per spec max 10). We enforce same in voice.
If “stop” is used early, and then examiner says “next” quickly, ensure the app has properly ended stance. Usually, after ending stance, showing Next stance button, our code can treat a “next” command as valid then.
After Module Completion:
We stop the voice listening to avoid interference with subsequent modules. We output the BalanceResult with errorsByStance filled from our counts (the code already collects errors in the module data). By using voice, the examiner can keep their eyes on the athlete throughout the 20s, simply calling out “error” whenever needed without having to glance at or tap the device or Apple Watch. This improves accuracy of error counting and overall safety (they can potentially catch the athlete if they stumble without fiddling with a controller). Voice "Start" also allows a hands-free beginning to each trial.
Neurological Exam Module – Voice Interaction
The Neurological & Coordination module consists of several subtests that are mostly observational, with a few requiring yes/no responses from the athlete. Voice integration here is less about continuous commands and more about capturing the athlete’s spoken answers and allowing the clinician to mark results verbally.
Voice Commands and Inputs in Neuro Exam
Athlete’s Yes/No answers: Some subtests involve asking the athlete questions:
Neck Examination: The athlete might be asked if they feel pain. The athlete could simply say “Yes” (if there is pain) or “No” (if pain-free). We can capture that and use it to set the neckPain result (note: if athlete says "Yes, I have pain", that means neckPain = true, which in our data means abnormal).
Double Vision: The clinician asks "Did you experience any double vision?" The athlete answers “No” (hopefully). We capture yes/no to set doubleVision false/true.
These are straightforward voice captures of the athlete’s response.
Clinician’s voice commands for toggles: Each subtest card has a Yes/No or Normal/Abnormal toggle that the clinician usually would set:
Instead of pinching, the clinician can say “Yes” or “No” when that card is active. For example, on the Finger-to-Nose card which has a result toggle (Normal or not), the clinician can say “Yes” meaning normal (no issues observed) or “No” meaning abnormal.
Similarly for Tandem Gait outcome: after timing, the clinician might say “No” if the athlete stepped off line (meaning not normal).
Essentially, whenever a card with a binary outcome is focused, “Yes” = mark normal, “No” = mark abnormal.
Timer control for Tandem Gait: Tandem gait includes a 3-meter walk out and back that the clinician times. If we implemented a Start/Stop timer for it in UI, we can allow “Start” and “Stop” voice commands to operate it (similar to the Balance timer). The spec shows Start/Stop buttons for the gait timer.
So the clinician can say “Start” when the athlete begins walking, and “Stop” when done. The measured time is recorded.
This avoids fiddling with a stopwatch or pinch while also spotting the athlete.
Navigation: The neuro exam is organized as a carousel of cards. The clinician can say “Next” or “Back” to navigate between these subtest cards (like orientation’s navigation).
Skip subtest: If a particular subtest is to be skipped (maybe Maddocks if not needed in orientation, or if an AR component fails), the UI might have a skip. The clinician could say “Skip” to move on, triggering the skip confirmation. (The spec mentions confirm “Skip this subtest?”. We won’t deeply implement that, but voice “skip” could initiate skip dialog.)
Implementation
Yes/No Responses:
For subtests where the athlete’s spoken answer is what we need (Neck pain, Double vision), we actually rely on the athlete to speak. The device is on the clinician’s head, but it will pick up the athlete’s voice if they are nearby and facing clinician – Vision Pro has multiple mics that might catch it. We assume it’s sufficient.
The app will be listening for “yes” or “no” when those questions are asked. We likely start a short SpeechAnalyzer session when a question is posed:
E.g., on Neck Exam card: after instructing the athlete, we listen for their “yes”/“no”. Once received, we set neckPain = (yes -> true pain, no -> false pain-free).
Actually careful: The prompt is “pain-free? Yes/No”. If athlete says "Yes", they are saying "Yes, it is pain-free" -> that means no pain, so neckPain = false. If they say "No", means not pain-free -> neckPain = true. Our code must invert the yes/no for that one because the data field neckPain is true when there is pain.
For double vision: prompt “Did you have double vision? Yes/No”. Yes = doubleVision true (problem), No = false (normal).
We can simply capture the text and have logic per question to assign appropriately.
Clinician’s voice toggles:
We treat these similar to symptom toggles: when the card is active, a spoken “yes” means mark that test as normal/pass, “no” means abnormal/fail.
E.g., Finger-to-nose card has a result toggle (we might label it “Normal” with yes/no or just a checkbox). If clinician says “No” (meaning the performance was not normal: e.g. they missed nose), we set fingerNoseNormal = false.
For reading & instruction following: that one is a bit different – the UI might have two parts (reading aloud and following instruction). Possibly combined outcome “readingNormal”. If the athlete read fine and followed instruction, it’s yes (normal); if they had any issue, no. The clinician can say “Yes” or “No” for that card, and we set readingNormal accordingly.
In some cases, the clinician’s observation might not be a direct yes/no question to the athlete but their own assessment (e.g., Finger-to-nose, Tandem gait). Using voice “yes/no” here essentially saves a pinch:
If looking at Tandem Gait card after timing, the clinician sees if the performance was acceptable. They can say “Yes” (meaning normal gait) or “No” (stepped off line, etc. -> abnormal).
We set tandemGaitNormal bool accordingly. (We also capture the time separately from the timer.)
So, for each card, we’ll have context of what “yes/no” means:
Neck: yes -> no pain (so neckPain false); no -> pain (neckPain true).
Reading: yes -> normal (readingNormal true); no -> issues (readingNormal false).
Double vision: yes -> they experienced double vision (doubleVision true, which is abnormal); no -> none (doubleVision false).
Finger-nose: yes -> normal performance (fingerNoseNormal true); no -> abnormal (fingerNoseNormal false).
Tandem gait: yes -> normal (tandemGaitNormal true); no -> abnormal (tandemGaitNormal false).
We will implement a mapping or condition for each.
Timer (Tandem Gait):
If we have a Start button to begin timing the 3m walk, we can voice-enable it:
When ready, say "Start" -> begin timer (store start time).
The user then likely has to press Stop at end – voice "Stop" will capture end time.
We compute total time and store tandemGaitTime.
If they say "Stop" early, that's fine, the time stops at that moment.
If they forget to say stop and it's presumably done, the clinician might just manually tap or we could possibly have an auto-timeout if they don't stop after e.g. 10 seconds (but 3m walk likely under 10s for healthy, maybe up to ~15s if slow, but we won't auto-stop).
We'll rely on explicit stop command or manual tap.
The voice recognizer can run continuously on this module too or be started when needed:
Perhaps simpler: run it continuously through the carousel, as in Orientation, since commands are simple and sparse.
Or start/stop at specific points (like start listening when expecting an athlete answer or waiting for “start” command).
Navigation:
Just like other modules, “Next” to go to next subtest card, “Back” for previous.
It helps so clinician can keep hands free, especially if they have to physically do something (like help with neck range of motion). They could say "Next" to move to the next card.
Skip:
If voice hears "skip" and that card is skippable (like if AR calibration failed or optional test), we could trigger the skip confirmation dialog. Possibly outside scope to implement fully, but we can note it.
Integration
We’ll use one voice handler active throughout the Neurological module:
It listens for the keywords: “yes”, “no”, “start”, “stop”, “next”, “back”, “skip”.
When it gets a result, we determine context:
We know which card is currently in view (via currentSubtestIndex or id).
We also possibly know if we are mid-timing the tandem gait (so if "stop" comes, apply to timer).
The handleNeuroVoice(spoken) function might look like:
swift
Copy
Edit
switch spoken {
  case "yes", "no":
    switch currentCard.id {
      case .neck:
        neckPain = (spoken == "no")  // "no" means there was pain
      case .reading:
        readingNormal = (spoken == "yes")
      case .doubleVision:
        doubleVision = (spoken == "yes")
      case .fingerNose:
        fingerNoseNormal = (spoken == "yes")
      case .tandemGait:
        tandemGaitNormal = (spoken == "yes")
    }
    // update UI toggles accordingly
  case "start":
    if currentCard.id == .tandemGait && !timerRunning {
      startGaitTimer()
    }
  case "stop":
    if currentCard.id == .tandemGait && timerRunning {
      stopGaitTimer()
    }
  case "next":
    goToNextCard()
  case "back":
    goToPrevCard()
  case "skip":
    if currentCard.isSkippable {
      presentSkipConfirmation() // perhaps still require a manual confirm
    }
}
We’ll include synonyms:
Could consider "no" might be interpreted as “No” or “Know” sometimes; but given question context, likely fine.
"yes" is straightforward.
Capturing athlete answers:
For neck and double vision, the athlete’s "yes"/"no" is effectively doing the same as the clinician toggle because the clinician will rely on that answer. So if the athlete says "Yes (I have pain)", our code above for neck would set neckPain = (spoken == "no") -> spoken is "yes", so neckPain = false? Wait, we need to be careful:
If athlete says "Yes (pain-free)", actually that means no pain, which is neckPain false (which our code would incorrectly set to false if spoken "no"? That logic might need clarity).
Let's break it:
For neck: question phrased “pain-free? (Yes = no pain, No = has pain)”.
So if spoken == "yes": pain-free is yes -> neckPain = false.
If spoken == "no": pain-free is no -> neckPain = true.
We might not have the question text context to differentiate "pain-free?" vs others in code easily, so we handle neck as a special case with inverted logic.
For doubleVision: question "did you have double vision? (Yes = had double vision (not normal), No = none (normal))"
So if spoken == "yes": doubleVision = true.
If spoken == "no": doubleVision = false.
That fits our code above except we set doubleVision = (spoken == "yes"), which is correct.
So our switch for neck should actually do:
neckPain = (spoken == "no") as above (because "no" means not pain-free -> pain present).
That seems right in code: if spoken "no", neckPain = true (pain present).
If spoken "yes", neckPain = false (no pain).
Good, our pseudocode does that for neck.
Reading and fingerNose, tandem all follow the pattern yes = normal (true), no = abnormal (false).
Double vision is reversed (yes = abnormal true, no = normal false). But our code above sets doubleVision = (spoken == "yes"), meaning if they said yes (I had double vision) -> true (which is abnormal), if no -> false, which is correct logic.
So just neck and doubleVision have opposite meaning of yes, but our code handled neck specifically and doubleVision naturally. Tandem gait timer:
The startGaitTimer() will note timerRunning = true and start a stopwatch (we can use CACurrentMediaTime or similar). Possibly provide a running timer display.
The user might or might not say "Stop" – if not, presumably they tap stop.
stopGaitTimer() calculates the elapsed, updates tandemGaitTime, and stops the UI timer.
If voice "stop" triggers it, fine. If manual tap triggers it, voice might still be listening and could accidentally catch something as "stop" after the fact, but we can set timerRunning false so it won’t do anything again.
Hand-tracking segments (like finger-nose ARKit tracking, gaze stability):
In gaze stability test (following a dot), we track if they missed frames; result is not directly spoken by athlete. The clinician will mark it pass/fail. They can use "Yes/No".
For reading & following instructions, ideally the device could listen to the athlete reading the sentence aloud to catch slurring. That’s advanced (we could transcribe the sentence and compare to target text to detect misread words). This might be beyond scope; we’ll not do that automatically. The clinician just judges.
But interestingly, for the reading subtest, the clinician might want to confirm if athlete followed the instruction (touch left ear). There's no direct voice part. The result is clinician’s assessment (which they do via "Yes/No").
**Skip:
If skip voice is used, perhaps we pop up the confirmation "Skip this subtest?". We could even allow voice "Yes" to confirm skip in that dialog. However, to keep things simple, skip likely rare; the clinician can tap confirm. We'll not detail that further.
Summary
Voice in Neuro exam mostly captures simple yes/no responses and a start/stop for timing:
We integrate it by starting a continuous listener when the module begins, similar to Orientation, filtering out commands by context.
Ensure we stop or ignore input when not relevant (like don’t let random "yes" when no question is active flip something unintentionally).
Because multiple yes/no toggles exist on different cards, we only apply when that card is active.
All voice commands are redundant to UI options (ensuring nothing is voice-only). If voice fails or is misheard, the clinician can manually toggle or input as needed. Finally, when the module completes, we compile the NeuroResult with all the booleans and time. Voice input will have populated those in real-time.
Results Summary & Notes – Voice Interaction
The Results Summary module mostly displays outcomes and has a Notes field for additional comments. The primary voice feature here is dictation for the notes.
Voice Dictation for Notes
Instead of typing on the floating keyboard, the clinician can use voice to dictate the clinical notes. VisionOS likely has system dictation, but we can integrate our SpeechTranscriber for consistency and possibly better control:
When the clinician gazes at the “Notes” text area and activates it (say by pinching or saying a command), we start recording voice input.
For example, a microphone icon could appear in the Notes pane. If the clinician taps it or says “Take note” (we can use a command to start dictation), the app will begin transcribing everything the clinician says until they stop.
The clinician can then speak freely: e.g. “Athlete complained of headache and dizziness. Advised rest and follow-up in 24 hours.”
We capture this continuous speech and convert it to text in the notes field. We should include punctuation if possible:
The SpeechAnalyzer model can insert basic punctuation (not sure if by default; if not, the clinician may have to say “comma”, “period” which is supported by the engine).
Alternatively, since it's a longer dictation, we might leverage the new model’s ability for long-form transcription which often does add punctuation and capitalization to some extent (the WWDC mention it’s used for Notes app with punctuation).
The text appears in the Notes field in real-time (like a typical dictation).
The clinician can then verbally say “Done” or just pause to end. Possibly we provide a voice command “Stop dictation” or just they tap a Done button.
We finalize the text and keep it in the notes.
If our voice system is still running from previous module, we may want to pause or disable the command parsing when focusing on free-text dictation. It might be easier to not run continuous commands in summary screen, but rather only start voice when needed for notes. So, we’ll implement notes dictation as a separate mode:
Possibly have a mic icon next to Notes. On tap or voice command "dictate notes", we create a new SpeechAnalyzer (or reuse one but with different options) focusing on transcription of potentially longer speech, not command mode.
We might not use .fastResults here; accuracy is more important for notes. We definitely use .volatileResults to show text as the user speaks.
The user can speak multiple sentences. The transcriber should output interim results which we place into the TextEditor live, and finalize with punctuation. Apple’s model might handle sentence breaks by pause detection.
Voice Commands in Summary:
“Add note” or “Take note” or “Dictation” – to start note dictation (if we want a voice trigger, otherwise the user can just tap the mic button).
During dictation: No special commands except saying punctuation or “new line” if they want formatting, which the Apple engine may support by voice (in older Siri dictation, speaking “new line” actually inserts newline, etc. We can assume similar behavior).
“Stop note” or “Done” – to end dictation (or just a long pause might finalize anyway). We could listen for the word "done" but if the clinician actually says "done" as part of note, that would erroneously stop. Perhaps better to just tap to stop. Or say "stop dictation".
Navigation: If the summary is part of a sequence, maybe voice "Next" could finalize and exit summary (e.g. say moving to another screen), but likely summary is end so not needed. Possibly “Finish” could be a voice command to finalize the test and save, but presumably tapping sign-off is required anyway. We might skip that to avoid accidental closure.
Implementation
We present a mic icon for notes. Developer-wise:
Use another SpeechTranscriber instance for the notes dictation or reuse global with different mode.
Possibly easier: reuse the global with no command restrictions but when notes active, treat everything as dictation text.
Maybe simpler: Start a separate SpeechAnalyzer for notes:
swift
Copy
Edit
notesTranscriber = SpeechTranscriber(locale: .current,
                                     transcriptionOptions: [],
                                     reportingOptions: [.volatileResults],
                                     attributeOptions: [])
notesAnalyzer = SpeechAnalyzer(modules: [notesTranscriber])
Then on start:
swift
Copy
Edit
try await notesAnalyzer.start(inputSequence: audioStream)
for try await result in notesTranscriber.results {
    let text = result.text
    if result.isFinal {
        notesText += text + " "
    } else {
        partialNotesText = text  // show partial in UI
    }
}
We combine finalized text in a buffer and show partial separately (like the WWDC example did). Or simpler, update the TextEditor with finalizedText + partialText on the fly. We can allow long running until the clinician manually stops:
The app might not know when the clinician is done speaking, unless they remain silent ~5s and engine finalizes. We can decide to auto-stop after a period of silence or wait for user action.
Perhaps the clinician will tap a “Done” button to stop recording.
Focus handling:
We should pause or turn off the normal command listener when doing notes dictation to avoid interpreting dictated words as commands. For example, if the clinician says "... advised rest and follow-up." we don't want "follow-up" or "up" to be taken as some navigation command.
So likely, once the Notes mic is activated, we suspend the command voice controller (or ignore everything in it), and use a dedicated transcriber for dictation.
After finishing dictation, we can resume normal voice commands (though at summary there may be none needed aside from maybe "sign off").
Sign-Off:
There's a “Clinician Sign-Off” button in UI. Possibly a voice command like “Sign off” could trigger the sign-off process (like bring up the list of clinician profiles or auto-select if only one). But for safety, probably leave that manual because it's essentially finalizing the record.
If desired, one could do it, but it requires selecting a name. We'll skip voice for sign-off.
Fallback
If dictation misses a word or spells something wrong (e.g. medical term), the clinician can manually edit the text after or during (using keyboard or by voice spelling, etc).
If the environment is noisy (like sideline), voice dictation might be challenging; the clinician can default to typing in those cases.
Because this is an offline model, it should still do a good job with general English medical notes. If they speak clearly, it’ll be as good as iOS dictation or better.
At this point, we've fully integrated voice throughout the app. The master voice controller either runs continuously and adapts to context, or we instantiate listeners on a per-module basis as needed (to keep things simpler and avoid cross-talk, likely the latter in implementation). Regardless, the developer guide emphasizes how to implement each piece with exact Swift logic and the visionOS speech APIs, which we have detailed with code snippets and algorithmic steps, citing relevant Apple documentation where useful. By following this guide, a developer can implement a reliable, efficient voice control system in the visionOS SCAT5 app that enhances user experience while adhering to SCAT5 protocol and maintaining the option to revert to traditional input at any time.
