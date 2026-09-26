# Read aloud

Select text in any app, press a hotkey, and EchoType reads it out in a Grok voice.

Status: implemented, 2026-09-26. The spike chose REST; see decision 0018.

## Problem

Reading long text on screen is tiring, and macOS's built-in Speak Selection voices sound
flat next to Grok's. xAI's text to speech uses the API key EchoType already holds, and
reading follows the same shape as dictation: a hotkey, the pill, and a network stream.

## Spike: does the REST endpoint stream?

The gate before any code. `POST https://api.x.ai/v1/tts` returns raw audio bytes. If it
sends them while it is still generating, one HTTP request can feed the player as bytes
arrive. If it only responds once the audio is complete, a long selection means seconds of
silence first, and reading has to use the WebSocket, `wss://api.x.ai/v1/tts`, which the
docs say streams.

The docs don't say which it is. `optimize_streaming_latency` is described as applying to
REST and changing "first-chunk size", which suggests REST streams, but that's not proof.

On the Mac, copy two or three paragraphs of prose (about 2,000 characters), then:

```bash
jq -n --arg text "$(pbpaste)" '{text: $text, voice_id: "ara", language: "en",
  output_format: {codec: "pcm", sample_rate: 24000}}' > /tmp/tts.json

curl -sS --trace-time --trace-ascii /tmp/tts-trace.txt -o /tmp/tts.pcm \
  -X POST https://api.x.ai/v1/tts \
  -H "Authorization: Bearer $XAI_API_KEY" -H "Content-Type: application/json" \
  -d @/tmp/tts.json

grep -E '^\S+ (=> Send data|<= Recv header, 17|<= Recv data)' /tmp/tts-trace.txt \
  | sed -n '1,4p;$p'
```

The timestamps show when the request went out, when the headers arrived, and when the first
and last audio bytes arrived.

- **REST streams** if the first audio bytes arrive well before the last. For example, first
  bytes within a second and the last several seconds later.
- **REST doesn't stream** if the audio arrives in one burst at the end, or if the headers
  come late and all the data follows at once.

Repeat with `"optimize_streaming_latency": 1` added to the JSON, and note the time to the
first bytes. Then listen to both. Playing raw PCM needs ffmpeg
(`ffplay -f s16le -ar 24000 -ac 1 /tmp/tts.pcm`). Without it, change the codec to `mp3`,
save to `/tmp/tts.mp3` and use `afplay`.

Last, copy a selection full of Markdown, code and a URL. Listen with and without
`"text_normalization": true` to decide whether reading turns it on.

Record in a decision record: whether REST streams, the time to first audio at each
`optimize_streaming_latency` setting, which setting reading uses, and whether
`text_normalization` is on.

## Behaviour

- **Read Aloud** gets its own Settings tab with three settings:
  - **Hotkey**: ⌥S by default, or ⌃⌥S, mirroring the dictation presets.
  - **Voice**: Ara or Altair. Ara by default.
  - **Speed**: a slider from 0.7 to 1.5, 1.0 by default, the endpoint's range.
- Pressing the hotkey copies the selection in the focused app and starts reading it.
  The pill shows a `Reading` phase with a stop hint.
- The same hotkey, Escape, or a click on the pill stops reading. When the audio ends, the
  pill fades.
- If nothing is selected, the pill shows "Nothing selected" in red, like any other error.
- A selection over 60,000 characters, the REST limit, is cut to its first 60,000. That
  costs about 90 cents at $15 per million characters. The pill says "Reading the first
  60,000 characters" in its text area.
- Pressing the dictation hotkey while reading stops reading and starts dictating. Pressing
  the read-aloud hotkey during a dictation does nothing.
- Missing keys and API errors are shown in the pill in red, worded as for dictation.
- Reading uses the General tab's `language`.

## Copying the selection

Post Cmd+C with explicit flags, as `Inserter` does for Cmd+V, so the held Option key
doesn't turn it into Cmd+Opt+C. Then poll the pasteboard's `changeCount` every 10ms for
up to 300ms.

- If the count goes up, read the string and put back what the pasteboard held before.
- If it doesn't, nothing was selected.

`Inserter`'s save and restore moves into a small pasteboard helper that both use.

Some editors, VS Code among them, copy the current line when nothing is selected. In those
apps, pressing the hotkey with nothing selected reads the current line. That's fine.

## Fetching and playing audio

Audio is requested as 16-bit PCM at 24 kHz, the endpoint's default rate, and played through
an `AVAudioEngine` with an `AVAudioPlayerNode`. Each chunk is converted to Float32 and
scheduled as it arrives. A sample can be split across two chunks, so an odd trailing byte
is carried over to the next chunk. Stopping calls `player.stop()` and cancels the request.
Reading ends when the last scheduled buffer finishes.

What feeds the player depends on the spike:

- **If REST streams:** `URLSession.bytes(for:)` on a `POST /v1/tts` with `text`,
  `voice_id`, `language`, `speed`, `output_format` and the settings the spike chose.
  Bytes are gathered into roughly 100ms buffers before scheduling.
- **If it doesn't:** the WebSocket, with `language`, `voice`, `codec=pcm`,
  `sample_rate=24000`, `speed` and the spike's settings as query parameters. It uses the
  same auth header as the STT socket, sent over `WebSocketTransport`. EchoType sends the
  text as one `text.delta` followed by `text.done`. Each `audio.delta` carries
  base64 audio in `delta`. `audio.done` ends the stream, and `error` carries a `message`.

## Implementation

### Core

- `Settings` gains `readAloudHotkey: Hotkey = .optionS`, `voice: String = "ara"` and
  `speechSpeed: Double = 1.0`. Each decodes on its own, as in
  [0010](../decisions/0010-settings-storage-and-api-key.md). `Hotkey` gains `optionS` and
  `controlOptionS`, and `readAloudPresets`.
- `Speech`, the TTS request: the REST request or the socket URL and frames, depending on
  the spike. Also the 60,000-character cap and the voice list as a constant.
- The Int16 to Float32 conversion with the carried byte, which is the part most likely to
  go subtly wrong.

### App

- `HotkeyMonitor` matches both hotkeys and reports which one was pressed.
- `Pasteboard` holds the save and restore extracted from `Inserter`, plus the copy.
- `SpeechPlayer` wraps the engine and player node.
- `Reader` runs one reading: copy, fetch, play, stop. `DictationController` already owns
  the tap and the panel, so it owns the `Reader` too. It routes the read-aloud hotkey to
  the reader. Escape and pill clicks go to the reader while it's reading. Starting a
  dictation stops the reader first.
- `Pill.Phase` gains `.reading`. The level glow and meter follow the audio as it plays, on
  dictation's scale.
- `SettingsView` gains a `ReadAloudTab` with a `speaker.wave.2` icon, placed after
  Keyterms.

## Tests

- The request, or the socket URL and frames, carry the voice, speed, language and codec.
- Decoding `audio.delta`, `audio.done` and `error` frames, if the socket is used.
- PCM conversion: a chunk split mid-sample produces the same samples as the whole buffer.
- `SettingsTests`: extend the pinned stored payload with the three new keys, and check that
  a payload without them decodes to the defaults.

Copying, the pasteboard and playback live in the app target, which has no tests, and are
checked by hand.

## Checking it on the Mac

1. `swift test`.
2. Select a paragraph in Safari, Notes, VS Code and a terminal, and read each aloud. Note
   the time to first audio.
3. Stop with the hotkey, Escape and a click. The audio should cut off immediately.
4. With a known string on the pasteboard, read something aloud. The string should still be
   on the pasteboard afterwards.
5. Press the dictation hotkey while reading. Reading stops and dictation starts.
6. Press the hotkey with nothing selected in Notes.
7. Change voice and speed. The next reading uses them.

## Out of scope

- Highlighting words as they're read, using `with_timestamps`.
- A preview button for voices in Settings.
- Pausing and resuming.
- Cleaning up Markdown or code with an LLM before reading.
- Custom voices.
