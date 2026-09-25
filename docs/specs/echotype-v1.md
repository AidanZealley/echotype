# EchoType v1

Push-to-talk dictation for macOS. Press Opt+D, speak, press Opt+D again, and the
transcript is inserted at the caret in whatever app has focus. Built around xAI's
`grok-voice-transcribe-2.0` streaming API.

Primary use is writing prompts into coding agents, which means 20 to 60 second
utterances full of technical jargon. That shapes several decisions below.

Status: drafted 2026-09-21, not yet implemented.

## Scope

In v1:

- Global hotkey toggle, overlay showing live transcription, insertion at the caret
- Menu bar item and a settings window
- User supplies their own xAI API key
- Local install on the author's Mac, no distribution

Deliberately out of v1:

- LLM cleanup pass over the transcript
- Per-app profiles, voice commands, local Whisper fallback
- Overlay that follows the caret
- Live population of the target field while speaking
- Hold-to-talk, and a full hotkey recorder UI
- Transcript history. The pasteboard already holds the last transcript, which
  covers a failed paste, so a store would be machinery without a job
- Notarization and distribution to other people

## Platform choice

Native SwiftUI with a thin AppKit layer. Not Electron.

The reasoning is that this app is mostly OS integration. It needs `CGEventTap`,
`CGEventPost`, `NSPasteboard`, `NSPanel`, `NSStatusItem`, TCC handling and
`SMAppService` no matter what it is written in. Electron would not remove any of
that, it would add a second runtime and an IPC protocol beside it. Going native
means one language, one binary and no third-party dependencies at all.

The cost is that the whole project is macOS-only, including its tests. See
"Development workflow".

The deployment target is macOS 26.0. Nothing here needs a recent API: `CGEventTap`
dates to 10.4, `AVAudioEngine` to 10.10, `URLSessionWebSocketTask` to 10.15, and
the newest things in the design are `MenuBarExtra` and `SMAppService` at macOS 13.
26 is chosen for the Liquid Glass materials in the overlay and because there is no
reason to pin the project to an OS released a week ago.

## Interaction model

Opt+D starts recording. Opt+D again stops it, transcribes, and inserts.

Escape cancels and discards, consumed by the tap only while a session is open so
it behaves normally the rest of the time. Clicking anywhere on the overlay does
the same as Opt+D, which works because a non-activating `NSPanel` routes clicks
to its content without taking key status from the focused app.

Toggle rather than hold, because holding a key through a minute of dictation is
tiring, and prompts for coding agents run long.

### Silence, pausing and the hard cap

Nothing is ever inserted by a timer. Text reaches the target app only when the
user presses Opt+D or clicks the overlay. This is the rule the rest of this
section follows from.

Going quiet pauses the session rather than committing it. After ten seconds
without new transcript activity the overlay dims and shows a paused state,
keeping the accumulated text on screen. Speaking again resumes it. The session
stays open indefinitely and waits.

The earlier draft committed on silence, with a countdown in the overlay warning
the user it was about to. That was wrong in two ways. Pasting half a prompt into
an editor is a bad enough outcome that the timeout had to be set uncomfortably
long to avoid it, and a visible countdown pressures the user to keep talking
while they are trying to think.

Pausing is non-destructive, so the timeout is free to be whatever reads best, and
there is nothing to warn about so there is no countdown.

Implementation is a display state and nothing more. The socket stays open and
audio keeps streaming throughout. The server's own voice activity detection is
already the signal, but it is not the arrival of events that carries it: partials
keep arriving at roughly 1 Hz with empty text all through a silence, and stop
entirely for the two to three seconds the server spends deciding where an
utterance ended. Speech is therefore a partial with non-empty text, or a
`speech_final`. Anything else is quiet. That avoids local RMS thresholds,
noise-floor calibration, a reconnect, and the first-word clipping a reconnect
would reintroduce.

The trade is that the microphone streams to xAI during a pause. This is bounded
by the hard cap below, so the worst case is ten minutes of dead air and a few
pence, on a session the user explicitly started.

The same ten second setting covers the case where the user triggers and never
says anything. With no accumulated text there is nothing to show, so the overlay
closes and the session cancels silently rather than sitting paused and empty.

Ten seconds rather than something tighter, for two reasons. Long thinking pauses
are normal for this author when composing a prompt, and a short timeout would
have the overlay flicking between listening and paused throughout a single
dictation. And on the no-speech path, a short timeout closes the overlay while
the user is still gathering their thoughts, leaving them talking into nothing.

Neither failure costs anything except annoyance, since no text is at risk either
way, so the value is tuned for how it feels rather than for safety.

A hard session cap of ten minutes ends everything, inserting whatever has
accumulated. This exists for the case where the user walks away, not for normal
use.

### Why Opt+D

Two keys, left hand, pinky on Option and middle finger on D. Mnemonic for
dictate. macOS reserves nothing at Opt+letter, and most apps avoid binding there
because it types special characters.

Opt+E was the first candidate and was rejected. Opt+E, Opt+I, Opt+U, Opt+N and
Opt+` are dead keys that compose accents on a US layout. The tap consumes the
keydown while the app runs, but if the app is stopped or the tap has been
disabled, pressing one leaves the keyboard in a pending-accent state. Opt+D fails
safe by typing a harmless character instead.

Fn was considered and rejected. The emoji picker fires from WindowServer, which
subscribes to IOHID events below where a `CGEventTap` sits, so no app can
suppress it. Wispr Flow defaults to Fn and simply asks users to change
`com.apple.HIToolbox AppleFnUsageType` to 0. Choosing Opt+D removes that
onboarding step, the arming window needed to distinguish a bare Fn from Fn+arrow,
and the whole class of problem.

Alternates offered in a settings dropdown:

- Ctrl+Opt+D, if some app turns out to claim Opt+D. Note that Ctrl+Opt is
  VoiceOver's modifier key, so every Ctrl+Opt chord collides with a VoiceOver
  command. Harmless unless VoiceOver is in use, but it is why this is not the
  default.
- Right Option double-tapped, as a zero-conflict escape hatch. Option alone does
  nothing so nothing can collide.

Avoid Opt+Space (Raycast and Alfred both want it), Ctrl+Cmd+Space (reserved for
the Character Viewer), Cmd+Opt chords (dense with browser and dev tool bindings)
and Caps Lock (handled below the event tap, same problem as Fn).

Store the binding as a keycode plus modifier flags, not a string, so the preset
dropdown is a one-line change and a recorder UI later is a drop-in.

## Overlay

A pill at bottom centre of the screen holding the focused window, roughly 420pt
wide, Liquid Glass material, rounded. It must never take focus, so: `NSPanel` with
`canBecomeKey` false, `isFloatingPanel` true, `level` at `.screenSaver`, shown
with `orderFrontRegardless()`, and `collectionBehavior` including
`.canJoinAllSpaces` and `.fullScreenAuxiliary`.

If it ever takes focus, the target text field loses it and insertion goes
nowhere. This is the single most important constraint in the UI.

Contents, left to right: an input level meter, the transcript text, elapsed time.
A dim hint line underneath reads `⌥D stop · esc cancel`.

The level meter is the most valuable element. Without it, a muted mic or a wrong
input device is invisible until an empty transcript comes back. Small vertical
bars driven by RMS, not decorative waveform art.

The transcript shows partials as they arrive, one or two lines, truncating from
the left so the tail of what was just said stays visible. Interim text renders
dimmed, text that has arrived with `is_final` renders solid. This is what lets
the user notice a misheard term and cancel rather than paste something wrong.

Elapsed time earns its place because the trigger is a toggle and it is possible
to forget a session is running. It counts up only. No countdown, since nothing
happens automatically that the user needs warning about. It turns amber at eight
minutes as the hard cap approaches.

States: starting, listening, paused, transcribing (the brief moment between
committing and the final result), error shown inline in red for a few seconds, and
a silent fade when nothing was heard.

Starting covers the moment between Opt+D and the input device delivering audio.
The microphone is released when each session ends, so every session pays the 100
to 300ms it takes to open, and anything said before it is ready is lost. The
overlay appears at once in a visibly not-ready state and switches to listening
only when audio is flowing, so the user can see when to start speaking and a
clipped first word is never silent.

Paused dims the level meter and the elapsed timer while keeping the accumulated
transcript at full contrast, since that text is the thing the user is reading.
The hint line stays as it is: the available actions do not change.

Placement follows the focused window's screen rather than the screen holding the
mouse, since the overlay describes what is about to happen to that window.

Bottom centre rather than following the caret. Caret placement via
`AXFocusedUIElement` and `AXBoundsForRange` depends on the target app
implementing those properly, and many do not, so it degrades into appearing in
the wrong place.

## Menu bar and settings

A `MenuBarExtra` whose icon reflects state. Its menu holds current state, a
Settings item, and Quit. No manual trigger item: clicking it would leave focus
wherever it was, so it cannot do the real job, and the settings test button
covers the case it was meant for.

Settings opens a real window rather than a popover, because a popover that
dismisses on click-away is irritating while pasting an API key or editing a term
list.

Panes:

- API key, shown masked once saved, with Test, reveal, replace and remove
- Hotkey preset dropdown
- Input device picker
- Keyterms editor
- Language
- Launch at login, via `SMAppService`
- Permission status rows with buttons that open the relevant System Settings pane

The Test button records a few seconds, transcribes, and shows the result inline
in the pane rather than pasting anywhere. One click validates the microphone, the
device choice, the API key and the socket, which is most of what can go wrong
during onboarding.

The keyterms editor matters more than it looks. The API accepts up to 100 terms
and it is the highest-value accuracy lever available, which is what fixes
"shadcn", "Zustand", "pnpm", "TanStack" and "t3code".

The input device picker defaults to following the system default input, so
connecting AirPods does the obvious thing, with an explicit selection overriding
that.

Settings live in `UserDefaults`. The API key is the only thing in the Keychain,
stored as a `kSecClassGenericPassword` item.

The menu bar icon is the SF Symbol `waveform` for now, to be replaced with a
custom asset.

## Transcription

### API facts

Verified against xAI's documentation. Several secondhand write-ups describe an
OpenAI-compatible `/v1/audio/transcriptions` endpoint, which does not exist.

Batch, not used in v1 but useful for the settings Test button:

```
POST https://api.x.ai/v1/stt
Authorization: Bearer $XAI_API_KEY
multipart/form-data, `file` must be the last field
```

Streaming:

```
wss://api.x.ai/v1/stt
Authorization: Bearer $XAI_API_KEY
```

Configuration is entirely URL query parameters. There is no setup message.

Server events: `transcript.created` (ready, wait for it before sending audio),
`transcript.partial` (carries `text`, `words`, `is_final`, `speech_final`),
`transcript.done` (after `audio.done`, closes the connection), and `error`.

Client messages: binary frames of raw audio, `{"type":"finalize"}` to force
finalisation, `{"type":"audio.done"}` to signal end of audio.

Errors: 400 bad request, including a wrong API key, 401 no credentials sent,
413 over 500 MB, 429 rate limited, 502 URL download failed, 503 unavailable.

Pricing is $0.10 per hour for batch and $0.20 per hour for streaming. A 30 second
dictation costs under two tenths of a cent, so cost is not a design input.

### Connection parameters

```
?encoding=pcm
&sample_rate=16000
&interim_results=true
&endpointing=2000
&filler_words=false
&format=true
&language=en
&keyterm=...&keyterm=...
```

`endpointing` is how much quiet the server waits through before it decides an
utterance has ended, closes the segment and sets `speech_final`. It is set high
deliberately. Utterance boundaries are controlled by the hotkey, and the default
400ms would chop a prompt into fragments every time the speaker pauses to think.

The number is a floor rather than the boundary. Measured live at
`endpointing=2000`, the boundary landed 2.73-2.80s after the endpoint's own last
reported word, with the frame in hand at about 3.0s of wall clock. Budget 3s, not
2s, for anything that depends on when a segment closes. Those figures came from
inserted digital silence, which is the easiest case a voice activity detector
gets, so a real room may be slower still.

`filler_words=false` is the default and removes "um" and "uh" with no cleanup
pass, which is most of the reason v1 does not need an LLM step.

Open the socket on trigger, not at launch. An idle open socket bills streaming
time.

### Assembling the transcript

The final text is every `speech_final` segment concatenated in order, plus
whatever trailing partial the `finalize` resolves into. Accumulate as events
arrive rather than expecting one blob at the end. Interim text can be rewritten
and must never be treated as committed.

## Audio

`AVAudioEngine` input tap, converting device rate Float32 to 16 kHz mono Int16
with `AVAudioConverter`, sending roughly 100ms chunks as binary WebSocket frames.
That is 32 KB/s, so the API's Opus option buys nothing and would cost an encoder.

Opening the input device takes 100 to 300ms, which is enough to clip the first
word. Acquire the stream on trigger and release it as soon as the session ends,
so the macOS microphone indicator is lit only while dictating. Holding it warm
between sessions avoided the open cost, but a microphone that stays live for
minutes after use is disconcerting. The overlay's starting state covers the gap.

## Insertion

Insert once, at the end. Not live.

Partials are provisional and get rewritten, so streaming them into the target
field would require synthetic backspaces to correct. That fights autocomplete,
corrupts undo history, and is dangerous in a terminal. No shipping dictation app
does it, for that reason.

The sequence:

1. Record `NSPasteboard.general.changeCount`
2. Write the transcript to the general pasteboard
3. Post Cmd+V via `CGEventPost` to `cghidEventTap`
4. After roughly 800ms, restore the previous contents, but only if `changeCount`
   advanced by exactly one

The `changeCount` guard decides which of two things happens. If nothing else
wrote to the pasteboard, the previous contents come back, so dictating does not
cost the user whatever they had copied. If something else did write, that write is
left alone and the transcript stays on the pasteboard, so a paste that landed
nowhere is still recoverable.

The text is inserted exactly as the model returned it, with no leading or
trailing whitespace added and no capitalisation adjustment. Padding rules are
felt on every single use, so this is a default to live with for a while and tune
against real usage rather than guess at now.

Setting the focused element's value through the Accessibility API was considered
and rejected. It sounds cleaner but Electron apps and terminals, which are the
main targets here, expose poor AX text implementations.

## Architecture

One SwiftPM package. No `.xcodeproj`, because it is a generated XML blob that
produces unreadable diffs and that agents edit badly.

```
Package.swift
Sources/
  EchoTypeCore/          decisions: no UI, no global state, no I/O
    SessionMachine.swift
    SessionClock.swift   injected time and the system clock
    RelayTransport.swift forwards messages read by the session
    Settings.swift
    STT/
      TranscriptAssembler.swift
      STTClient.swift    depends on a WebSocketTransport protocol
  EchoTypeApp/           macOS only
    App.swift            MenuBarExtra, Settings scene
    HotkeyMonitor.swift  CGEventTap
    AudioCapture.swift   microphone and capture session lifecycle
    AudioChunker.swift   sample conversion and 100ms chunks
    DictationController.swift
    Inserter.swift       pasteboard + CGEventPost
    OverlayPanel.swift   NSPanel shim hosting a SwiftUI view
    Keychain.swift
    Views/
Tests/EchoTypeCoreTests/
  Support/               session test transport, clock and snapshot log
Resources/Info.plist
scripts/deploy.sh
scripts/run.sh
scripts/install.sh
```

The split between the two targets is decisions in `EchoTypeCore`, effects in
`EchoTypeApp`. Whether a keycode and a set of flags match the configured chord is
a decision; `CGEvent.tapCreate` is an effect. Keeping App thin is what keeps the
untestable surface small, since nothing that touches TCC, focus or the window
server can be covered by a test.

The line is pure decisions in Core, not simulate the OS. Protocol-wrapping
`NSPasteboard` so it can be faked would buy tests of the fake.

`STTClient` talks to a `WebSocketTransport` protocol rather than
`URLSessionWebSocketTask` directly. That keeps protocol logic testable with
recorded event streams instead of live sockets.

### State machine

```
idle → listening ⇄ paused → finalizing → inserting → idle
            ↓ esc    ↓ esc
          cancelled
```

`listening` and `paused` differ only in what the overlay renders. Audio streams
in both. The transition either way is driven by the speech signal above, a
partial with non-empty text or a `speech_final`, with ten seconds of quiet moving
to `paused` and the next speech moving back.

`finalizing` is entered only by Opt+D, a click on the overlay, or the ten minute
hard cap. It sends `{"type":"finalize"}` then `{"type":"audio.done"}` and waits
for `transcript.done`.

If the socket fails mid-session, insert the finalised segments accumulated so far
rather than discarding them, and show the error in the overlay alongside. Losing
thirty seconds of speech to a dropped connection is worse than inserting a
truncated transcript the user can see was truncated.

Other edge cases the machine must handle: stop pressed before
`transcript.created` arrives, stop with no audio captured, and
`transcript.done` that resolves to an empty string.

## Permissions, signing and distribution

Required TCC grants: Microphone, and one grant covering both the event tap and the
posted Cmd+V. On macOS 27.2 that is a single "Device Control and Data Access"
prompt attributed to EchoType itself, rather than the separate Accessibility and
Input Monitoring grants earlier versions asked for. The APIs are unchanged: the
check is still the Accessibility trust check, so code and comments naming it are
correct even though the user never sees that word.

The bundle identifier in `Resources/Info.plist` is fixed from the spike
onwards. TCC grants, the Keychain item holding the API key, the `UserDefaults`
domain and the login item registration all key off it, so changing it later makes
macOS treat the result as a new app and resets every one of them. The display
name (`CFBundleName`) is separate and can change freely if the app is renamed.

`Info.plist` needs `CFBundleIdentifier`, `NSMicrophoneUsageDescription` and
`LSUIElement` true so nothing appears in the Dock or Cmd+Tab.

Do not enable App Sandbox. It blocks `CGEventPost` and the event tap outright and
there is no entitlement that buys a way out for a non-App-Store app. Hardened
runtime is skipped for now, since it is only needed for notarization.

Sign every build with the developer's Apple Development identity. Install that
certificate through Xcode and check that `security find-identity -v -p codesigning`
lists it. `scripts/run.sh` selects it automatically when only one matches
`Apple Development`; set `ECHOTYPE_SIGNING_IDENTITY` to its full certificate
name or SHA-1 hash when several match. The release install must use the same
selection. This replaced the self-signed `EchoType Dev` certificate used in
the spike. See [decision 0014](../decisions/0014-sign-with-apple-development.md).

This is the detail that makes the project pleasant to work on. TCC keys its
grants to the code signature. Signing ad-hoc with `codesign -s -` derives the
requirement from the binary hash, so every rebuild looks like a brand new app and
re-prompts for the grants above. Keeping the same signing requirement across
rebuilds is what lets the grants persist.

No notarization for v1. Gatekeeper only applies to quarantined downloads, and
these builds are local. Distribution to other people would need a separate
signing and notarization plan.

Escape hatch when TCC gets confused: use `tccutil reset All` with the bundle
identifier from `Resources/Info.plist`. `reset All` is the verified one;
whether a narrower reset clears the macOS 27 grant was never tested.

## Development workflow

Development happens on the Mac, because that is where the compiler is. An earlier
plan kept `EchoTypeCore` Linux-compatible so a remote Linux machine could build
and test it, and that was dropped once the remaining build order turned out to be
overwhelmingly AppKit: the share of the project a Linux machine could compile was
falling towards nothing, and the price was a hand-written resampler standing in
for `AVAudioConverter`.

```bash
./scripts/run.sh
```

`run.sh` runs `swift build`, assembles the `.app` bundle, copies the plist, signs
with the dev identity, kills any running instance and relaunches. Incremental
builds for an app this size take a few seconds.

`install.sh` does the same in release configuration and copies to
`/Applications`. Same code path, so there is no separate release process to get
wrong.

A `--hud-demo` launch flag shows the overlay cycling through every state with
fake transcripts, so UI changes can be reviewed in one launch rather than by
dictating repeatedly.

### What is tested where

Covered by `swift test`, and this is where the real bugs live:

- Transcript assembly against recorded event streams: partials superseded by
  finals, multiple `speech_final` segments, `finalize` resolving a trailing
  partial, events after `audio.done`, empty results
- The session machine with an injected clock: the listening and paused transitions
  in both directions, several pause and resume cycles accumulating text correctly,
  the no-speech close, the ten minute cap, escape mid-session, stop before ready,
  socket error while listening, stop with no audio
- Query string construction, including the 100 keyterm and 50 character caps

Audio conversion is not on this list. `AVAudioConverter` resamples device rate
Float32 to 16 kHz mono Int16 and is the platform's job to get right, so the
capture layer configures it rather than reimplementing it.

A live integration test runs against `wss://api.x.ai/v1/stt` with a fixture WAV,
given a key in an environment variable. Worth doing early, since the streaming
protocol is specified here from documentation rather than experience.

Verified by hand on the Mac, once each, rather than by test:

- TCC grants persisting across rebuilds
- Event tap recovery from `tapDisabledByTimeout`
- Paste landing in the right app and the pasteboard restoring cleanly
- The overlay not stealing focus
- Real first-word clipping

## Known risks

The event tap gets disabled by the system if it takes too long to respond,
delivering `tapDisabledByTimeout`. The handler must catch that and re-enable
itself, or dictation silently stops working after a while. This is the most
likely cause of a "it stopped working and I don't know why" bug.

TCC grants survived rebuilds during the self-signed spike. The current Apple
Development identity is a different signing requirement, so verify grants
persist across rebuilds with that identity too.

The streaming protocol is taken from documentation. Event ordering and the exact
semantics of `speech_final` versus `is_final` may differ in practice. The silence
cap depends on `speech_final` meaning what the docs say it means, so if that
turns out to be wrong the fallback is local RMS-based detection using the level
meter's existing signal.

macOS enables secure event input whenever a password field has focus, which
blocks event taps entirely, so Opt+D will not fire there. That is correct
behavior and not worth fighting. The risk is that buggy apps sometimes leave
secure input enabled after losing focus, at which point the hotkey silently stops
working with nothing logged anywhere. Second candidate for a mystery failure
after the tap timeout.

## Build order

1. The spike, before any app code. `run.sh`, a stable signing certificate, an
   empty menu bar app, a `CGEventTap`, and Opt+D pasting the literal string
   "hello" into TextEdit. This proves the signing loop, TCC persistence and the
   paste round trip in about an hour, and each of those is a place this could
   turn out to be painful.
2. `EchoTypeCore` and its tests, written and run remotely.
3. Audio capture wired to the socket.
4. The overlay.
5. Settings, Keychain, launch at login. This step owns how settings reach
   `UserDefaults` and how the API key reaches the Keychain, and it owes that
   encoding a round-trip test. `EchoTypeCore` deliberately has no serialisation,
   because a conformance written before the encoding is chosen would only assert
   its own invention. The round trip is still where the real bugs are: a hotkey
   that silently stops firing after an upgrade surfaces as a mystery.
6. `install.sh`.
