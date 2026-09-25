# 0015 Settings in tabs, with a masked saved key

Status: accepted, 2026-09-25. Replaces the key field handling in
[0013](0013-test-button-and-system-rows.md).

## Context

The settings window was one grouped form with a box around every section. The key sat in
a one-line secure field on the right of its row, so a pasted key scrolled sideways and
could not be checked, and removing it meant emptying the field.

## Decision

- The window has three tabs: General (hotkey, input, language, launch at login,
  permissions), Keyterms and API Key, with no boxes. General uses the columns form style,
  with labels in one column and controls in the next. The key spans the full width of its
  tab, with its buttons on the right.
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
