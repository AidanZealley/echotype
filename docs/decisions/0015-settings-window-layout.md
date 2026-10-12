# 0015 Settings in a sidebar, with a masked saved key

Status: accepted, 2026-09-25. Updated 2026-10-12 for the sidebar and keyterm input.
Replaces the key field handling in [0013](0013-test-button-and-system-rows.md).

## Context

Tabs limited navigation growth. Putting providers and app controls on one long page
mixed unrelated tasks. A sidebar gives each feature its own controls and keeps
provider setup separate.

## Decision

- `NavigationSplitView` has a `List(selection:)` sidebar driven by a `Pane` enum.
  Each pane carries its title and SF Symbol. The sidebar toggle is removed.
- The first group is Dictation and Read Aloud. The second lists providers with an API
  key or setup capability, currently xAI and Local. The last is General, Keyterms,
  Agents and About.
- Pages use grouped `Form` sections and navigation titles. Feature pages own the
  provider picker, service status and feature options. Provider pages own credentials
  and installation controls. [0025](0025-provider-adapters.md) owns the generic setup
  contract. Permissions appear only under General.
- Read Aloud shows the selected provider's voices and speed range. Choices are saved
  per provider. About contains version information and Updates.
- Keyterms are removable chips in one input. Return adds the draft. Backspace in an
  empty draft removes the last term. Each chip also has a remove button. The count
  uses the selected Dictation provider's limit.
- A saved key appears masked in `LabeledContent`, with its prefix and last four
  characters when long enough. Replace opens a visible draft field. Save writes it
  to the Keychain. Remove asks for confirmation. Key writes disable the buttons
  until they finish. The editor's identity uses the provider id.
- Test belongs to Dictation and uses its selected provider and saved credential.
  It never saves a key and is disabled while the controller is busy.

## Consequences

Feature choices and provider setup have separate destinations. New providers appear
through their declared capabilities. A key is visible while it is entered, and
leaving an unfinished editor discards its draft.
