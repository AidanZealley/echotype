# Settings layout study

Status: Aidan selected C's sidebar structure on 9 October 2026, with separate Dictation
and Read Aloud destinations replacing Overview. The focused revision is ready for review.

Aidan rejected A because horizontal tabs restrict navigation growth and push settings
into accordions. B combines too many purposes on one long scrolling page. Preserve C's
provider and app destinations while giving each feature its own settings page.

The current focused native demo is at
`.build/settings-focused-revised/EchoType Settings Local Demo.app`. Double-click opens it
directly. Dictation and Read Aloud each have their own sidebar page. xAI, Local,
General, Keyterms, Agents and Updates keep their separate destinations. There is no
Overview page, layout picker or accordion navigation.

After reviewing the first focused mock, Aidan requested a clearer Local page. The
revision gives Dictation and Read Aloud separate model cards with independent status
and actions. Storage is a compact summary with a Manage files sheet for removal,
retained downloads and obsolete assets. Provider assignment stays on feature pages;
sources and licences is a secondary link below storage.

The first focused build remains at
`.build/settings-focused/EchoType Settings Focused Demo.app` for comparison.

The earlier three-option study remains at
`.build/settings-variants/EchoType Settings Demo.app` for comparison. Both demos have
distinct bundle identifiers and use in-memory mock state, with no
SettingsStore, Keychain, providers, microphone, network or model-store operations.

## Options

| Variant | Arrangement | Tradeoff |
| --- | --- | --- |
| A, Feature tabs | Dictation and Read Aloud tabs own their provider choices and feature settings. Providers & Storage holds credentials and local files. More holds the other app settings. | Closest to the current compact Settings arrangement. Seeing both choices or managing installation requires changing tabs. |
| B, Feature overview | Both features appear side by side, with shared credentials, local installation and storage underneath. Other app settings use disclosures below. | Makes a mixed-provider setup immediately visible, but puts more content on one scrolling page. |
| C, Provider workspace | A sidebar separates the feature overview, provider setup and existing app concerns. Local owns download and storage panels. | Gives setup and storage a clear home, but feature choices and provider management are separate destinations. |

All three keep transcription and cleanup together under Dictation. All provider
choices, credentials, downloads, removal and tests are mocked. Model/storage sizes
are illustrative; they are not a new manifest or a final installation estimate.

## Exploring states

In the earlier study, use Layout to switch A/B/C. Feature selects which local feature the Scenario control
affects; it does not change that feature's provider. Use Scenario to show missing,
downloading, installed, preparing, failed, active-reading or cancelled states. Local
Dictation and Read Aloud have independent installation states. Appearance switches
between system, light and dark within the demo.

In the focused demo, opening Dictation or Read Aloud automatically targets that
feature's scenario. On provider pages, Local feature chooses the scenario target.

Review Download opens the model list, missing download size and consent step. Mock
Download advances progress, Cancel retains mock partial files, and Retry resumes the
simulation. Installation does not start just from choosing Local.

Providers & Storage in A, the lower shared panels in B, and Local in C expose removal
confirmation, obsolete assets and removal protection while a feature is active.
General, Keyterms, Agents and Updates are placeholders showing their intended locations.

## Validation and next step

The release build and strict signature verification passed. Native UI inspection covered
all three layouts, dark/light appearance, download consent, independent installed state,
removal confirmation, preparation protection and download failure with retained files.
No real download, model preparation, credential change or removal was performed.

The focused release build and strict signature verification also passed. Native UI
inspection confirmed separate feature pages, the Local installation/storage page,
and the Read Aloud preparation state.

The Local revision passed release build and strict signature verification. Native
inspection confirmed both model cards and storage fit without scrolling, the file
management sheet opens, and removal confirmation appears within the sheet. Cancelling
returns to the unchanged file list.

The sidebar decision is recorded in the productionization specification. The
[approved workflow](implementation/README.md) carries the chosen structure into native
production Settings and retains the mock as a reference until UI acceptance.
`SettingsDemo.swift` and its `main.swift` entry were removed after acceptance of the production
layout. The study does not require retaining demo machinery in the shipped app.
