# 0015 Settings in tabs, with a masked saved key

Status: accepted, 2026-09-25, updated 2026-10-01 for the Provider tab. Replaces the key field handling in
[0013](0013-test-button-and-system-rows.md).

## Context

The settings window was one grouped form with a box around every section. The key sat in
a one-line secure field on the right of its row, so a pasted key scrolled sideways and
could not be checked, and removing it meant emptying the field.

## Decision

- The window has General, Keyterms, Read Aloud, Agents, Provider and Updates tabs.
  General uses the columns form style, with labels in one column and controls in the next.
  The Provider tab replaces API Key. It lists the registered providers in a picker, then
  the selected provider's summary, its features, its key row if needed, and Test.
- Features come from the services. Live transcription and Read aloud are required and
  show green SF Symbol check marks; Cleanup shows a green check when its service exists
  and a grey mark otherwise. Colours follow the system theme, with no cards or pills.
- The key spans the width of the Provider tab, with buttons on the right. Switching
  provider creates a separate key editor, so a draft, revealed key or async result cannot
  carry into another provider's editor. Providers that need no key show Test without a
  key row. Test uses the selected provider and is disabled while the controller is busy.
- Read Aloud lists that provider's voices by display name and its speed range with a 0.1
  slider step. Both edits are remembered per provider. Keyterms shows the selected
  provider's limit minus one for the built-in EchoType term. General has no cleanup
  toggle; cleanup runs whenever the provider supplies it.
- A saved key is never shown in an editable field. It shows masked, as its prefix, enough
  bullets to fill the line and its last four characters, with a button at the end of the
  line that reveals it wrapped and selectable.
  Test, Replace and Remove act on the saved key. Remove asks first.
- With no key, or after Replace, a field that wraps takes the key, and Save writes it.
  Masked text cannot wrap, so the key being entered is visible. Nothing is written until
  Save, so leaving the window mid-edit discards the edit.
- Key writes disable the key buttons until they finish, so two cannot race.

## Consequences

- Test no longer saves anything, so it always tests the key the Keychain holds.
- The key is visible on screen while it is pasted.
