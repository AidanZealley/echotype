# EchoType for iOS

Status: draft, 2026-09-26. This describes the intended product and the device checks needed before committing to the cross-app flows.

## Goal

Bring EchoType's dictation and Read Aloud features to iPhone. The app must be useful when opened directly. A custom keyboard should let someone dictate into a text field in another app. A Share action should let someone send selected text to EchoType for immediate reading. After onboarding, keep the app's navigation to a main screen and an in-app Settings screen.

## Onboarding

On first launch, show a short sequence that explains each step before asking the user to act. Keep the copy specific to what EchoType needs:

1. **How it works.** Explain Dictate, Read and the optional keyboard. State that dictated audio and text submitted for Read Aloud go to xAI for processing. Link to the privacy details before the user starts either feature.
2. **API key.** Let the user enter their xAI key, explain that EchoType stores it in the iPhone Keychain, and provide a way to edit it later in Settings. This is account setup, not an iOS permission.
3. **Microphone.** Explain that Dictate records only during an active session, then offer an Enable Microphone button that triggers the system permission request. A denial leaves Read available and shows a route to iOS Settings for a later change.
4. **Keyboard.** Explain that the keyboard provides a dictation control in other apps and a way back to the system keyboard for typing. It may need Full Access for its cross-app handoff. Provide steps to enable it in iOS Settings, then return to EchoType and show the detected setup state. Request Full Access only if the device prototype confirms it is needed. Let the user skip this step and use the standalone app.
5. **Try it.** Offer a short practice dictation and a way to finish onboarding without practicing. Introduce Read and the Share action without asking for another permission.

Resume at the current step if the app is interrupted during setup. Show onboarding once; Settings retains the instructions and status checks so any skipped step can be completed later. Ask for a denied system permission again only through the appropriate iOS Settings path. Do not treat installing a keyboard or enabling Full Access as a prerequisite for standalone Dictate or Read.

## Main screen

The main screen has Dictate and Read modes. Opening EchoType normally starts in Dictate. Settings is available from the main screen. Switching modes stops an active recording or reading before starting the other mode.

### Dictate

- Show a prominent mic button. A tap starts recording; another tap finishes. Provide a separate Cancel action that discards the session.
- Show the live transcript while recording, with provisional text visually distinct from committed text. Show starting, listening, paused, finishing and failure states. Keep long text readable as it grows. Reuse the session behavior in `EchoTypeCore` where it applies; follow the shipped macOS behavior rather than an unimplemented draft spec.
- In a session started directly in EchoType, copy the nonempty final transcript to the system clipboard once it is ready. Show the final text and a Copy button so it remains recoverable. Cancel and empty sessions do not change the clipboard.
- In a session started from the keyboard, deliver the final text to the keyboard for insertion into the original text field. Do not use or alter the system clipboard for this handoff. Keep the final text available in EchoType if the return or insertion fails.
- Ask for microphone permission from the main app and explain the xAI audio request before first use.

### Read

- Show editable text, a system Paste control, Play and Stop. Opening Read directly allows typing or pasting text. Playback uses the existing EchoType voice, speed and language settings, and the current TTS endpoint.
- Read Aloud streams speech as it becomes available. Keep the text visible during playback. Stop cancels playback and its request.
- Text received from a Share action opens Read with that text populated and starts playback automatically, **if the Share-to-app handoff gate below succeeds**. Sharing never overwrites the user's clipboard.

## Keyboard extension

- Provide a minimal keyboard view with a dictation control and a way to switch to the next keyboard. In the private build, the user switches to the system keyboard for ordinary typing. The dictation control starts the handoff to EchoType's recording screen. After recording, return to the original app and insert the final transcript at the active caret through `textDocumentProxy.insertText(_:)`.
- Use an App Group for the session request and result if device provisioning supports it. Associate each result with its request so a late result cannot insert into a later field or session. Keep the API key in the main app's Keychain, not in shared state.
- If iOS cannot return to the original app, show how to return manually and keep the transcript recoverable in EchoType. If the original field is gone, do not insert into another field.
- Explain keyboard setup and Full Access in onboarding and Settings. The next-keyboard control works without Full Access or network service. Dictation may require both.
- Expect the system keyboard in secure fields, unsupported field types and apps that disable third-party keyboards.

If App Store publication becomes a goal, keep the simple dictation view as the primary interface and add a clearly visible control that toggles to a QWERTY layout within the same extension. That layout must support ordinary typing and editing without Full Access or network service; the next-keyboard control remains available in both views. [Apple's keyboard review rules](https://developer.apple.com/app-store/review/guidelines/) require keyboard input and offline operation, but do not prescribe which view opens first. Validate the finished design against the rules at submission time rather than treating the toggle alone as approval.

## Share action

- Offer **Read in EchoType** for text supplied through the iOS Share sheet. The preferred experience is to open EchoType's Read mode with the shared text and autoplay. The originating app decides what text it sends; the selection is not always available.
- Do not assume a Share or Action extension can launch its containing app. [Apple's documented `NSExtensionContext.open` support](https://developer.apple.com/documentation/foundation/nsextensioncontext/open%28_%3Acompletionhandler%3A%29) does not include these extension points. Prove a supported, reliable handoff on a physical iPhone before implementing the preferred flow. Do not use responder-chain or private-API workarounds.
- If that handoff is unavailable, bring back a concrete alternative for product review. An Action extension with its own temporary player, or saving text for a later manual app open, changes the requested experience and is not an automatic substitute.

## Settings

- Keep app controls in an in-app Settings screen. Include the xAI API key, language, key terms, transcription options that apply on iOS, TTS voice and speaking speed, plus microphone and keyboard setup/status. Store the key in Keychain.
- Do not show macOS hotkeys, launch-at-login or the macOS input-device picker on iPhone. Link to iOS Settings only for permissions and keyboard activation that EchoType cannot change itself.
- Use the current `Settings` type for common values. Split platform-specific settings only if the iOS target needs a separate stored shape.

## Code and distribution

- Keep the macOS app, iOS app, keyboard extension and shared core in this repository. Expose `EchoTypeCore` as a Swift library usable by macOS and iOS. The app targets own microphone capture, audio playback, UI, Keychain and platform handoffs.
- Target private installation on the user's own iPhone. App Store submission is outside this draft's scope; the conditional QWERTY layout above is a possible later addition, not part of the private build.
- Support development signing with a free Personal Team if the required app and extension entitlements provision successfully. Its [seven-day profile expiry](https://developer.apple.com/support/compare-memberships/) is acceptable for private use with periodic reinstallation or refresh.

## Feasibility gates

Build the smallest device prototype before implementing the full UI:

1. On the target iOS release, sign and install a host app, keyboard extension and text Action extension with the available development account. Check App Group provisioning and keyboard Full Access. Record any capability that requires a paid team.
2. From a standard text field in Notes and Messages, tap the keyboard control, start microphone recording in EchoType, return to the same field, and insert one result without changing the clipboard. Check the behavior after the main app enters the background and when the user cancels.
3. Share selected text from at least Safari, Notes and Messages. Confirm what each host supplies. Test whether a supported API can foreground EchoType with that text and autoplay. Record the exact handoff and failure behavior.

If either cross-app handoff cannot be made reliable with public APIs, stop that flow and review the observed behavior before changing this spec. The standalone Dictate and Read modes can still proceed independently.

## Acceptance checks

- Direct dictation shows a live transcript, copies only a nonempty committed result, and leaves the clipboard alone on cancel or failure.
- Direct Read plays typed or explicitly pasted text and can be stopped immediately.
- First launch explains xAI processing and the reason for each access request before prompting. Skipped keyboard setup does not block standalone use; interrupted onboarding resumes, and Settings can reopen every setup step.
- Keyboard dictation inserts once into the intended field after a successful return, leaves the clipboard untouched, and retains the transcript when insertion fails.
- Sharing text opens EchoType's Read mode and autoplays only if the Share handoff gate established a supported path. Otherwise the approved replacement flow is documented before implementation.
- Both themes remain legible, VoiceOver names the controls and session state, and Dynamic Type does not hide the final transcript or Stop control.
