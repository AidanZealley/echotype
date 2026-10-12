# Local model storage and removal

Status: implemented, updated 2026-10-12. Public release checks remain open in
[0026](decisions/0026-local-model-stack.md#build-and-release-checks).
That record also owns model choices, loading, the install queue, keyterm boosting
and measured limitations. [0025](decisions/0025-provider-adapters.md) owns setup's
provider contract.

## Owned files

The managed root is `~/Library/Application Support/EchoType/Models/`.
Only the supported manifests' revision folders and their retained downloads under
`Incomplete/` belong to the storage inventory. Historical or obsolete model names
are not owned. Generated Emma voice data, `ANE/bf_emma.bin`, and Kokoro's internal
`kokoro-82m-coreml` link stay inside its supported model folder.

The only external link is the CTC tokenizer cache at
`~/Library/Application Support/FluidAudio/Models/parakeet-ctc-110m-coreml`.
Loading creates it or replaces an existing link only when its target belongs to
EchoType's store. A real directory or foreign link is preserved and loading reports
a conflict. Inventory includes the link only when it targets a supported model
folder in the store. Removal also removes links to the deleted installation.

Core ML specialization caches belong to the system. EchoType does not manage them
or promise to reclaim their space. English pronunciation data ships in the app's
resources, not in the model store.

## Removal and uninstalling

The provider page shows an on-disk total. Manage Files opens a table of installed
and generated folders, retained downloads and the owned runtime link. Select rows
and confirm Remove. A feature's Remove action removes its files. Settings, provider
choices and keys remain saved. Removal checks the current inventory again before
deleting, and reports failures so they can be retried.

Files used by setup, preparation or an active operation cannot be removed. Cancel
setup or stop the operation and wait for teardown first. Removing one feature
preserves files needed only by the other. Removed models stay absent until an
explicit download in Settings.

Before uninstalling, use Manage Files to remove supported local assets. Dragging
EchoType to Trash leaves model files behind. If the app is already removed and no
process uses those files, delete the supported model folders and their retained
downloads. Remove the CTC cache link only if its destination is in EchoType's store.
Do not remove broad FluidAudio or Core ML caches. Leave unrelated folders and
foreign links alone.
