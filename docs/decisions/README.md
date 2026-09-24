# Decisions

Short records of decisions made while building EchoType that the specification
doesn't explain on its own. The specification in `docs/specs/` is still the source of
truth for behaviour. These files record why things are the way they are, what was
observed that led there, and which known gaps are handed to later milestones.

Each record has a status, the context, the decision and its consequences. When a
decision is reversed, mark the old record superseded and link the new one. Don't
delete it.

| # | Decision | Status |
|---:|---|---|
| 0001 | [Build on the Mac and sign with a self-signed certificate](0001-build-and-sign-on-the-mac.md) | Accepted |
| 0002 | [Detect speech from what the endpoint actually sends](0002-speech-signal-from-observed-protocol.md) | Accepted |
| 0003 | [Transcript assembly rules](0003-transcript-assembly.md) | Accepted |
| 0004 | [Session and socket lifecycle belong to the session machine](0004-session-lifecycle.md) | Accepted |
| 0005 | [Open the microphone per session and release it when the session ends](0005-microphone-per-session.md) | Accepted |
| 0006 | [API key in the Keychain, errors in the menu bar until the overlay exists](0006-api-key-and-error-surface.md) | Accepted; error surface superseded by 0009 |
| 0007 | [Known gaps handed to later milestones](0007-known-gaps.md) | Open |
| 0008 | [The pill: a text-first layout with a level glow](0008-pill-design.md) | Accepted |
| 0009 | [How the overlay behaves during a session](0009-overlay-behaviour.md) | Accepted |
