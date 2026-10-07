# Workstream 1: Pinned model downloads

Status: accepted.

## Task packet

### Outcome

EchoTypeCore can download a model's pinned files from Hugging Face into EchoType's Application
Support directory, verify every file, and report progress, so a local service's readiness can
say "Downloading models, 1.2 of 3 GB" and load weights only once they are complete. Nothing uses
the store yet; workstream 2 does.

### Scope

- A manifest type: name, repository, full commit revision, licence, and files with path, byte
  size and SHA-256.
- A store that, for a manifest:
  - answers its state: missing, downloading (bytes done, bytes total), installed (directory URL)
    or failed (message);
  - starts its download on request, idempotently, with at most one download per manifest, in a
    task the store owns so it survives the requester going away;
  - downloads each file from `https://huggingface.co/<repository>/resolve/<revision>/<path>`;
  - writes files in progress apart from installed ones, verifies size and SHA-256, and installs
    the manifest's directory only after every file verifies;
  - recovers after interruption: a relaunch finds no half-installed model and can start again,
    reusing or discarding partial files as you judge simplest, never loading them;
  - yields on every state change through a fresh `AsyncStream` per follower, suitable for
    `Readiness.changes`.
- Location: `~/Library/Application Support/EchoType/Models/`, shared by the app and the bench.
  Make the root injectable for tests.
- Focused tests with an injected download source: a successful install, a SHA-256 mismatch that
  fails without installing, and an interrupted download that leaves nothing installed and
  succeeds on retry.

Suggestions, not requirements: `URLSession` download tasks for large files; reporting progress
at a coarse interval so followers are not flooded.

### Non-goals

- Any real manifest or real download; workstream 2 supplies them.
- Deleting, updating or garbage-collecting old revisions, disk quotas, or a model-management UI.
- Hugging Face authentication; every planned repository is public.
- Using a runtime's own downloader (see the plan's decision log).

### Initial ownership

- `Sources/EchoTypeCore/Providers/Local/` (create it), for the manifest and store files.
- `Tests/EchoTypeCoreTests/` for one new focused test file.

### Required seams

Produces the plan's model store location, manifest and store interface contracts. Workstream 2
consumes them unchanged.

### Acceptance criteria

1. A manifest's state is installed only after all its files are present and verified.
2. A size or SHA-256 mismatch ends in failed with a message, and nothing is installed.
3. An interrupted download leaves the manifest missing or retryable on the next start, never
   installed with partial files.
4. Concurrent start requests for one manifest run one download.
5. Progress reports bytes done and total, and followers are notified of state changes.
6. The store depends on nothing outside Foundation and the Swift standard library, and names no
   model or candidate.
7. The new tests pass without network access.

### Targeted verification

```bash
swift build
swift test --filter EchoTypeCoreTests
```

Also run your new test suite alone with `swift test --filter` and its name.

## Implementation handoff

- Base commit: `dac6a8906debed3fb7c140ea18176c926bb0f53e`
- Outcome: The store and manifest are in `EchoTypeCore`, internal (workstream 2 is in the same
  module), with the live Hugging Face download source and three tests. All acceptance criteria
  are met. The live source was also run once by hand against a local HTTP server (20 MB, progress
  reported, 404 becomes `HTTP 404 from <host>`); that scratch test was deleted.
- Files changed (all new):
  - `Sources/EchoTypeCore/Providers/Local/ModelManifest.swift`
  - `Sources/EchoTypeCore/Providers/Local/ModelStore.swift` (also `ModelState`, `ModelStoreError`)
  - `Sources/EchoTypeCore/Providers/Local/ModelDownloadSource.swift`
  - `Tests/EchoTypeCoreTests/ModelStoreTests.swift`
- Interface for workstream 2:
  - `ModelManifest(name:repository:revision:license:files:)`, with
    `File(path:size:sha256:)` (size in bytes, lowercase hex SHA-256; `path` may contain
    subdirectories). `totalBytes`, `directoryName` (`<name>-<revision>`) and
    `downloadURL(for:)` are derived.
  - `ModelStore(root: = ModelStore.defaultRoot, source: = .live)`. `defaultRoot` is
    `~/Library/Application Support/EchoType/Models/`.
  - `state(of:) -> ModelState`: `.missing`, `.downloading(done:total:)`, `.installed(URL)`,
    `.failed(String)`. Synchronous and cheap, so a `Readiness.check` can call it directly.
  - `start(_:)`: synchronous, non-throwing, idempotent. It does nothing for an installed or
    downloading manifest and restarts a failed one. The download runs in an unstructured `Task`
    the store owns, so a provider switch does not stop it. There is no cancel.
  - `changes() -> AsyncStream<Void>`: a fresh stream per call, for `Readiness.changes`. It yields
    when any manifest's state changes, so a follower should re-read the state it cares about.
    Progress yields at about 1% steps.
  - `ModelDownloadSource(fetch:)` is the test seam: `(url, destination, progress)`, where
    `progress` takes the bytes of the current file written so far. `fetch` writes `destination`.
- Decisions:
  - On disk: installed models are `Models/<name>-<revision>/<path>`; in progress they are
    `Models/Incomplete/<name>-<revision>/`. Each file downloads to `<path>.part`, is verified
    (size, then SHA-256), then renamed to `<path>`. The whole directory is renamed into place
    only when every file is in. So "installed" is exactly "the directory exists", and nothing
    reads `Incomplete/`.
  - Recovery reuses verified files: a retry or relaunch skips any file already present in
    `Incomplete/` under its final name (only verified files get that name) and refetches
    anything else. A mismatching file is deleted. The `.part` file is always discarded and refetched.
  - A relaunched store reports `.missing` after an interruption, not `.failed`; failure messages
    live only in memory for the process that saw them. The failed message is the error's
    `localizedDescription`.
  - A model's directory name includes its revision, so a new revision never mixes with old files
    and old revisions are left in place (garbage collection is a non-goal).
  - Live fetches use a `URLSession` with a delegate and a download task rather than the async
    `download(from:)`, because the async calls never report progress (measured: 0 callbacks).
  - SHA-256 uses CryptoKit, imported only by `ModelStore.swift`.
  - The sole mutable state is one `Mutex` in the store, covering per-manifest in-memory state and
    the followers, so no actor is needed and `changes()` and `state(of:)` stay synchronous.
- Verification: `swift build` passed. `swift test --filter EchoTypeCoreTests` passed (130 tests).
  `swift test --filter ModelStoreTests` passed (3 tests; the three packet scenarios, with
  concurrent starts and progress folded into the success test). The tests use an injected source,
  no network, and no sleeps: they follow `changes()`.
- Known limitations or external checks:
  - The live source has never downloaded from huggingface.co; it is untested in the suite.
    Hugging Face answers `resolve/` URLs with a redirect to a CDN, which `URLSession` follows by
    default, so redirects are expected to work but are unverified. Workstream 2's first real
    download is the check.
  - There is no cancellation, timeout or disk-space check. The URLSession default request
    timeout (60 s of no data) is the only guard against a stalled connection.
  - The `.part` file of an interrupted fetch is discarded, so a single multi-GB weights file
    restarts from zero.
- Specification drift: Acceptance criterion 6 says the store depends on nothing outside
  Foundation and the standard library. SHA-256 verification needs CryptoKit (a system framework;
  the repository had no other hashing), and a hand-written SHA-256 would be slower and riskier. I
  used CryptoKit and `Synchronization.Mutex` (already used in `Apple.swift`). The store names no
  model, candidate, provider or other EchoType type.

## Independent review

- Reviewer: fresh independent review agent (Claude Sonnet 5.5), against base `dac6a89`. Diff is
  four new files only (`git status`: the `Providers/Local/` directory, `ModelStoreTests.swift`
  and the workflow docs); no tracked file is modified.
- Verdict: Accept. No Required findings; two Questions for the lead and three Optional
  observations.
- Verification run: `swift build` passed. `swift test --filter ModelStoreTests` passed (3 tests,
  0.008 s, no network). `swift test --filter EchoTypeCoreTests` passed (130 tests).
- Acceptance criteria:
  1. Met. `installed` is `FileManager.fileExists` on `Models/<name>-<revision>`, and that
     directory appears only through the final `moveItem(Incomplete/... -> ...)` after the loop
     verified every file. `Incomplete/` is a separate subtree and is never read as a model.
  2. Met. `verify` checks size, then SHA-256, before the rename; a mismatch deletes the part,
     throws and `start`'s catch sets `.failed(localizedDescription)`. The mismatch test asserts
     the message and that the installed directory does not exist. The size-mismatch branch is
     not tested, which is reasonable.
  3. Met. A relaunch has no in-memory state, so it reports `.missing` until the directory
     exists. Partial bytes live only in `<path>.part`, deleted before each refetch. Files
     renamed to their final name inside `Incomplete/` were verified first, so reuse is sound.
     The test simulates interruption by a thrown error plus a second store on the same root,
     not by a stale `.part` left by a killed process; the code handles that case
     (`removeItem(partial)`), it is just not exercised.
  4. Met. The check-and-set of `.downloading` happens inside one `Mutex` critical section,
     together with the installed check. The install test calls `start` three times and asserts
     `fetchCount == 2` for a two-file manifest.
  5. Met. Progress is `.downloading(done:total:)` at about 1% steps (file-level `before + written`),
     asserted at `50/150`; every state change calls `notify`; `changes()` returns a fresh
     `bufferingNewest(1)` stream per call and removes its follower on termination.
  6. Partly met, see Question 1. No model, candidate, provider or EchoType type is named. The
     imports are Foundation, `Synchronization` (already used in `Apple.swift`,
     `StreamingResponse.swift`) and `CryptoKit` (new in the repo).
  7. Met. All fetches go through the injected `ModelDownloadSource`; the live source is not
     touched by tests.
- Boundaries and ownership: Files are confined to `Providers/Local/` and one new test file, as
  the packet allows. Nothing outside the store depends on it yet. No `Providers.all` or bench
  change. Types are internal, fine for workstream 2 in the same module. `changes()` has the
  exact shape `Readiness.changes` needs (`@Sendable () -> AsyncStream<Void>`).
- Lifecycle and cancellation: The download runs in an unstructured `Task` the store owns, and
  `start` has no cancel, as the packet and ADR 0025 ("a task the adapter owns so it survives a
  provider switch") ask. The Task captures `self`, so the store lives as long as its download.
  Follower termination cleanup takes the `Book` lock from `onTermination`, but `yield` never
  terminates a stream, so I found no path that takes the lock while already holding it. The
  live `Download` resumes its continuation exactly once from `didCompleteWithError`, and
  `didFinishDownloadingTo` is delivered before it, so the status failure is not lost.
  `finishTasksAndInvalidate` releases the session's strong reference to the delegate.
- Required findings: none.
- Optional observations:
  1. In-memory `.failed` outranks the disk in `state(of:)`. If another store instance or
     process (the app and the bench share the root) installs the same directory after this
     store failed, `state(of:)` keeps reporting `.failed`, and `start` returns early because the
     directory exists, so it never clears. Evidence: `state(of:)` reads `book.states` first
     (ModelStore.swift:57) and `start` returns without touching `states` when the directory
     exists (line 69). It needs a second writer to the same root, which nothing creates in this
     slice. The smallest fix, if the lead wants it, is to test the disk first in `state(of:)`.
     Two stores downloading one manifest to the same `Incomplete/` directory at once would also
     race on `.part` files; "at most one download" holds per store, so workstream 2 should
     construct one store per process (see Question 2).
  2. `download(_:)` is about 28 lines with the skip, fetch, verify and move inline in a loop.
     It reads acceptably; extracting the per-file body would make the top-level phases (create
     directory, fetch each file, install) clearer, but it is not needed to accept.
  3. The tests would hang rather than fail if a state transition regressed, since `settle` has
     no timeout and waits for `changes()` to end. Acceptable for a three-test file; mentioning it
     only because the failure mode is silent. The live `URLSession` source uses
     `.default` configuration; `.ephemeral` would avoid writing a URL cache entry for multi-GB
     files, but I did not verify that `.default` caches download-task bodies, so treat it as a
     thing to check, not a defect.
- Questions:
  1. Acceptance criterion 6 says "nothing outside Foundation and the Swift standard library",
     and the store imports CryptoKit. The handoff records this as drift with a reason (no other
     hashing in the repo, and hand-written SHA-256 is worse). The criterion's intent reads as
     no third-party or EchoType dependency, and CryptoKit is a system framework on a macOS 26
     target. Recommend accepting the drift and logging it in `plan.md`'s decision and drift log
     rather than treating it as a defect.
  2. A failed manifest restarts on every `start`, and every state change yields on `changes()`.
     If workstream 2's `Readiness.check` calls `start` and the app re-runs `check` on each
     `changes` yield, an immediate failure (offline, HTTP 404) would loop: failed, yield, check,
     start, downloading, yield, failed. The packet does not specify retry policy, so this is not
     a defect in workstream 1, but the lead should decide whether the interface contract for
     workstream 2 should say that `check` only starts a missing manifest, or that a failed one
     needs an explicit retry. Workstream 2 may not change the store's behaviour, so this is
     cheapest to settle now. Related: the store should be a single shared instance per process.

## Resolution

- Finding dispositions: No Required findings, so no remediation pass.
  - Question 1 (CryptoKit): accepted as drift. SHA-256 needs a hash, Foundation has none and a
    hand-written one is worse. The criterion's intent is no third-party or EchoType dependency.
    Logged in the plan.
  - Question 2 (retry loop): settled as a contract for workstream 2, not a store change. `start`
    restarts a failed manifest, and every state change yields on `changes()`. So
    `Readiness.check` must call `start` only when the state is `.missing`; a failed model stays
    failed (showing its message) until relaunch, when the in-memory failure is gone and the state
    is `.missing` again. Logged in the plan. The app and bench must each hold one shared store.
  - Optional 1 (disk should outrank in-memory `.failed`): skipped. It needs a second process
    installing the same model while this one holds a failure, which nothing in this slice does.
  - Optional 2 (split `download`): skipped; it reads acceptably.
  - Optional 3 (test timeouts, `.ephemeral` session): skipped. Three tests with injected
    sources; the live session's caching was not shown to be a problem.
- Simplification/deletion pass: Implementation agent's pass stands (one `Mutex`, no actor, no
  cancel, no extra state). The lead found nothing further to remove.
- Final verification: lead reran `swift build`, `swift test --filter EchoTypeCoreTests` (130
  tests) and `swift test --filter ModelStoreTests` (3 tests); all passed.

## Closure review

- Verdict: Not run. There were no accepted findings or fixes to verify; the lead reran the
  packet's targeted verification itself.
- Remaining required findings: none.
