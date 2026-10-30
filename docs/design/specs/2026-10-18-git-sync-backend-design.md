# Git as a sync and backup backend

Status: design approved in conversation 2026-10-18, release v1.8.3.

## Why

The maintainer already uses Git, and a Git host is reachable from every
device they own. Today Submersion syncs through iCloud, Dropbox, Google
Drive, S3 or WebDAV; none of those is the place this diver already keeps
things. A Git backend lets a diver point Submersion at a private repository
on any Git host and have every device sync through it, with no new account
or storage service to sign up for.

Success: a diver pastes a repository address, a username and an access token
into one screen, taps Save, and every device that does the same converges on
the same library, with cloud backups landing in the same repository. The
repository stays small enough that hosts never warn about it in normal use.

## Goals

- A sixth sync backend, "Git", beside the existing five, that works with any
  Git host speaking the smart HTTP protocol: GitHub, GitLab (gitlab.com and
  self-managed), Gitea and Forgejo, Bitbucket Cloud, and plain self-hosted
  servers.
- Works on all five platforms (iOS, Android, macOS, Windows, Linux) with no
  native code and no dependency on a `git` program being installed.
- Cloud backups go to the same repository when cloud backup is on, exactly as
  they go to the active backend today.
- Encrypted sync works unchanged on top of it.
- The repository stays bounded in size over years of use.

## Non-goals (this version)

- SSH transport and SSH keys. HTTPS with a token only. SSH can come later
  through `dartssh2` without changing the backend's shape.
- Signing in through the host's website (OAuth device flow). The diver pastes
  a token.
- The shared dive-site library (#2567) over Git. It keeps its own transports.
- Git as a media store backend (Settings > Media storage). Photos and videos
  in Git history would grow the repository without bound.
- A "reset history now" button.
- Human-readable history. Sync files are gzipped JSON; the commit log records
  that a device synced, not what changed.
- Codeberg. Its terms limit private content to 100 MB and scope the service to
  free-software projects; the setup screen does not special-case it, but the
  docs and help text do not recommend it.

## Anti-goals (failure even if it technically works)

- Rewriting history on any branch Submersion did not create. A typo that
  points Submersion at `main` must never destroy the diver's `main`.
- Shipping native Git libraries (libgit2, go-git) that block a platform
  release, as happened to GitJournal on iOS for over a year.
- A repository that grows by tens of megabytes every few weeks forever.
- Pushing so often that a host throttles or flags the account.

## Decisions made with the maintainer

1. **Any Git host**, not GitHub only. This rules out host REST APIs as the
   transport; Submersion speaks the Git smart HTTP protocol itself.
2. **Submersion's own minimal Git client, in pure Dart.** Research
   (2026-10-18) found no existing package that fits:
   - `git2dart` (libgit2) ships Android libraries without 16 KB page
     alignment, which Google Play requires, and needs the system's OpenSSL on
     Linux.
   - `go_git_dart` covers Android only, SSH only, and has an open push
     failure (GitJournal #963).
   - The pure-Dart packages (`git_dart`, `dargit`) are weeks old,
     single-author, and each misses something we need (mobile SSH, shallow
     fetch).
   - `dart_git` has no network transport at all.

   `git_dart` (Apache-2.0) and `dargit` (BSD-3) are useful reference code;
   any code copied from them keeps its license notice.
3. **Sign-in is HTTPS with a username and an access token**, the one method
   every host supports.
4. **A dedicated sync branch whose history Submersion resets** (replaces with
   a single fresh commit) from time to time. The maintainer accepted that the
   branch keeps no long-term history.
5. **Cloud backups go into the same repository**, under the same folder name
   they use on other backends.
6. **Setup screen shape A**: one repository address field, with the host
   recognized from the address only to choose help text. This follows #3329,
   which replaced WebDAV's server-type presets with a single address.

## How it fits the existing sync engine

Every backend implements `CloudStorageProvider`
(`lib/core/services/cloud_storage/cloud_storage_provider.dart`): upload,
download, list, delete files, and create folders. The changeset log writes a
flat set of files into the sync folder (`ChangesetLogLayout`): one manifest
per device, small numbered changesets, and gzipped base snapshots in 8 MB
parts. Encryption (`EncryptingCloudStorageProvider`) wraps whichever provider
is active. The Git backend is one more `CloudStorageProvider`. Above that
seam there is one addition, `Future<void> flush()`, which defaults to a
no-op for the existing backends (see Write path).

Mapping:

| Provider concept | In the Git repository |
| --- | --- |
| Sync folder (`Submersion Sync`) | A directory of that name at the branch root |
| Backup folder (`Submersion Backups`) | A directory of that name at the branch root |
| `fileId` | The file's path in the tree (`Submersion Sync/ssv1....json`) |
| `listFiles` | Entries of that directory in the branch tip's tree |
| `uploadFile` | A commit on the branch tip adding or replacing that path, pushed |
| `deleteFile` | Removal of that path, folded into a later commit (see below) |
| `downloadFile` | The blob at that path in the tip tree |

The branch root also holds:

- **`README.md`**: says what this branch is, which app writes it, and not to
  edit it by hand.
- **`.submersion/branch.json`**: the marker that identifies a Submersion
  branch, plus the shared history-reset bookkeeping:
  - a format version;
  - `deletedBytesSinceReset`;
  - `lastResetAt`.
- **`.submersion/index.json`**: the file index (decision by the designer, see
  below).

### File index (designer's call)

Git trees record neither a file's size nor its modified time, but the engine
needs both. `CloudFileInfo.modifiedTime` is required, and it is used for:

- peer freshness at launch and in the first-contact guard
  (`sync_initializer.dart`);
- staleness ordering (`sync_device_footprints.dart`);
- sorting backups (`backup_service.dart`);
- tie-breaks on the library epoch and moved markers.

`deletedBytesSinceReset` also needs the sizes of removed blobs, which a
`filter blob:none` fetch never delivers.

So every commit rewrites `.submersion/index.json`, a map from path to
`{blobId, size, modifiedMs}`, where `modifiedMs` is the writing device's
clock at upload. Listings, `getFileInfo` and the deleted-bytes counter read
from it. Rules:

- **Paths missing from the index** (a file added by hand) get their size from
  the blob when it is fetched, and their time from the tip commit.
  Every load reconciles the index with the tip tree, so a file edited by hand
  is treated the same way and a file deleted by hand leaves the index.
- **A missing or damaged index** is rebuilt from the tree by the same rule.
  An index from a newer format version stops sync instead, since rewriting
  it in the older format would lose what the newer one adds.
- **The index's own replaced blob** counts toward `deletedBytesSinceReset`,
  so its churn is reclaimed by resets like everything else.
- **Encoding is the builder's choice:** gzipped JSON, or JSON split per
  directory, if its size per commit matters in measurement.

## Measured scale (why history resets are required)

- **Base size:** a real library's base snapshot is about 27 to 35 MB (four or
  five 8 MB parts).
- **When a new base is written:** a device writes a new base when it reaches
  200 changesets, or when the changes since its last base add up to 30% of
  the base's size (`ChangesetWriter`).
- **Bases don't compress in Git:** they are already gzipped, so Git can
  neither compress them further nor delta them against each other.
- **Growth:** three devices each writing a new base every few weeks add over
  1 GB a year of history.
- **Backups:** each one is a full database copy (about 10 MB for the
  maintainer's library). A daily backup adds about 300 MB a month of history
  once pruned copies are counted.

GitHub recommends repositories stay under 1 GB and strongly recommends
under 5 GB. Bitbucket hard-limits at 4 GB, with a 1 GB figure on its Free
plan. History resets keep the branch near the size of its current tree.

## The Git client

A small, purpose-built client: no working tree, no index, no merge of file
contents. It lives under `lib/core/services/cloud_storage/git/`, split into
small files by concern:

- pkt-line;
- transport and auth;
- protocol v2 fetch;
- pack reader;
- pack writer;
- object encoding (blob, tree, commit);
- the local object cache;
- the branch session.

Protocol surface:

- **Discovery and refs:** `GET <repo>/info/refs?service=git-upload-pack` with
  `Git-Protocol: version=2`, then `POST git-upload-pack` with `ls-refs`
  (including `symrefs`, to learn the default branch).
- **Fetch:** protocol v2 `fetch` with `deepen 1`. Ask for
  `filter blob:none` where the server advertises `filter`, so a fetch brings
  the tip commit and trees only, and blobs come on demand by `want <blob-id>`.
  Where the server lacks `filter`, fall back to a full depth-1 fetch of the
  tip. Fall back to protocol v0 where v2 is not offered.
- **Pack reading** must apply OFS_DELTA and REF_DELTA, because servers send
  deltas even at depth 1. It needs an inflater that reports how many input
  bytes it consumed (`package:archive`, or a hand-rolled streaming wrapper).
  `dart:io`'s `ZLibDecoder` does not report that.
- **Push:** protocol v0 `git-receive-pack`. Send one ref-update line with
  `report-status` and `side-band-64k`, then a pack of only the new objects,
  undeltified (header, objects, SHA-1 trailer). Parse the report-status
  reply and turn `ng` reasons into typed errors.
- **Compare-and-swap is built in:** every ref update names the old tip. A
  push from a stale tip is rejected by the server, so no locking of our own
  is needed for either ordinary commits or history resets.
- **Networking** goes through the app's `HttpClient` path (`AppHttpOverrides`),
  so proxy settings and the platform trust store apply, as they do for WebDAV.
- **Object cache:** Git objects are immutable and content-addressed, so
  fetched trees and blobs are cached locally by id (in the app's support
  directory, bounded in size, evicting least recently used). A listing with
  an unchanged tip costs one `ls-refs` round trip and no download.

## Write path

- **Uploads are durable before the call returns.** `uploadFile` and
  `uploadFileFromPath` commit and push before returning. The engine treats
  the cloud listing as the authority on which base parts landed
  (`changeset_writer.dart`), and it writes the manifest last. A listing must
  therefore never show a file that was not pushed, and a manifest must never
  land ahead of the parts it names.
- **Deletes are deferred and batched.** The changeset engine already
  tolerates a leftover file (a later compaction sweep retries it), so
  `deleteFile` adds the path to an in-memory pending-delete set and returns:
  - Listings and `fileExists` hide pending deletes.
  - The set is folded into the next commit, or flushed on its own after a
    short quiet period.
  - If the app dies first, the deletes are simply redone by a later sweep.

  Without this, a compaction that prunes dozens of files would make dozens
  of pushes.
- **`flush()` pushes pending deletes now.** It is called:
  - by the sync service at the end of every sync run, including runs in the
    headless background isolate, whose provider instance and pending set
    end with the task;
  - by every caller that reports a delete as complete to the diver, before
    reporting it. Examples: `SyncCleanupOutcome` from `_deleteListedFiles`,
    old-backend cleanup, plaintext-backup removal, backup deletes, library
    wipes. The builder searches for every `deleteFile` caller and lists them
    in the plan.
- **Deletes are conditional.** A pending delete records the blob id the
  device saw. If the path holds a different blob when the delete is applied,
  because a peer rewrote it in the meantime, the delete is dropped.
- **Commit shape:**
  - Parent: the tip the client last fetched. Tree: the tip tree with the
    change applied.
  - The commit also rewrites `.submersion/index.json`, and updates
    `.submersion/branch.json` by adding the sizes (from the index) of every
    blob it removes or replaces to `deletedBytesSinceReset`.
  - Message: `Sync from <device display name>`, or
    `Backup from <device display name>` for a backup.
  - Author and committer: the device display name, with email
    `sync@submersion.invalid`. The `.invalid` domain is reserved and can
    never match a real account on any host.
  - With encrypted sync on, the device display name stays out of the
    repository. Author and message use "Submersion" and the first eight
    characters of the device id instead, since commit metadata is never
    encrypted. (Designer's call.)
- **Rejected as stale:** when a push is rejected because the tip moved, the
  client fetches the new tip, rebuilds the same change on it, and pushes
  again. A few retries with jitter, then a typed error. Most files never
  collide: changesets, bases and manifests carry their device id, and
  backups carry a timestamp and device. Some files do have shared names that
  any device may write:
  - `submersion_library_epoch.json`;
  - `submersion_library_moved.json`;
  - `submersion_keyslots.json`;
  - retirement markers that `DeviceRetirement.sweep` writes for other
    devices.

  For these, the rebuild is last-writer-wins, exactly what an overwrite does
  on every other backend today. No new semantics, and none expected by the
  engine.
- **Pacing:** keep pushes below GitHub's recommended six per minute per
  repository. The builder decides the mechanism (a minimum spacing between
  pushes, or coalescing uploads that arrive while a push is in flight),
  provided uploads stay durable before they return.
- **Time budget (designer's call):** callers wrap uploads in a 60 s timeout,
  and lists and deletes in 8 s (`sync_service.dart`). A Dart timeout does not
  cancel the push underneath it. So:
  - Pacing waits at most 10 s.
  - Stale-tip retries are bounded, so a whole upload either finishes or
    throws its own typed error within 45 s.
  - Listings with an unchanged tip are one `ls-refs` round trip.
  - `deleteFile` returns without network I/O.

## History reset

- **When:** after any successful push where `deletedBytesSinceReset` passes
  a threshold. Starting value: 256 MB, a constant the builder may tune with a
  short justification.
- **How:** the device builds a parentless commit whose tree is the current
  tip tree (with `deletedBytesSinceReset` set to 0 and `lastResetAt`
  updated). It pushes that with the current tip as the expected old value, a
  forced update.
- **If another device moved the tip first,** the reset is rejected and simply
  tried again after the next sync.
- **Other devices** notice nothing special. Their next fetch sees a new tip,
  and since they keep no history, it needs no recovery.
- **Hosts reclaim space slowly** after a reset: GitHub on an undocumented
  schedule, GitLab after housekeeping, Gitea when its gc cron is on. That is
  acceptable. The reset bounds growth; it does not promise immediate
  reclamation.
- **When the host forbids it:** a reset rejected by branch protection (for
  example a GitLab rule on that branch) shows a plain-language message
  naming the setting to change. Ordinary syncing carries on.
- **Immediate reset after privacy-motivated deletes (designer's call):**
  removing the plaintext copies when encryption is turned on, a library
  wipe, and old-backend cleanup each flush and then reset history at once,
  whatever the counter says.
- **Honest wording about deletes:** on the Git backend, the confirmation text
  for those actions adds that the host may keep old copies until it runs its
  own cleanup. Git history cannot promise more than that.

## Safety rules for the branch

- **Default branch `submersion-sync`.** The diver may change the name.
- **Submersion writes only to a branch it created.** Two cases:
  - **The branch does not exist:** it is created as a parentless commit
    holding `README.md`, `.submersion/branch.json` and
    `.submersion/index.json`. This includes an empty repository with no
    branches at all.
  - **The branch exists and carries `.submersion/branch.json`:** it is
    adopted.
- **Any other existing branch is refused,** with a message saying it already
  holds other content and Submersion resets the history of its branch.
  Submersion never writes to it. This protects `main` or any other branch the
  diver typed by mistake.
- **A marked default branch is fine.** In a freshly created empty repository,
  `submersion-sync` becomes the host's default branch. Later devices adopt it
  because it carries the marker; it is not refused for being the default.
  Test connection says so when it happens, and suggests a repository used
  only for Submersion.

These rules are what make anti-goal 1 hold, and they need tests that fail
when the rule is removed.

## Public repositories (maintainer's decision)

A public repository is allowed only with encrypted sync on. Unencrypted dive
data (site GPS, buddy names) must never reach a repository anyone can read.

- **Detection:** an anonymous `GET info/refs?service=git-upload-pack` (no
  credentials). A success means the repository is public. A 401, 403 or 404
  means it is private. Any other outcome counts as unknown and is treated as
  private, with nothing shown.
- **Test connection and Save:** when the repository is public and encrypted
  sync is off, Save is refused. The message says the repository is public and
  offers to turn on encrypted sync (opening the existing encryption setup)
  or to make the repository private on the host.
- **Turning encryption off:** while the active backend is a public Git
  repository, turning encrypted sync off is refused with the same
  explanation.
- **A repository made public later (designer's call):** the anonymous check
  runs again once per app launch before the first push. If the repository
  has become public and encryption is off, syncing pauses with that message
  and nothing is pushed until it is fixed.
- **Tests:** each rule gets a test that fails when the rule is removed.

## Setup screen (shape A)

Settings > Data > Cloud sync > Git, a new `GitConfigPage` modeled on
`WebDavConfigPage`. Fields:

1. **Repository address.** The HTTPS clone address. Helper: "The HTTPS
   address you would clone from".
2. **Username.**
3. **Access token.** Stored in secure storage like the WebDAV password.
4. **Branch.** Default `submersion-sync`. Helper: "Submersion keeps this
   branch to itself and resets its history now and then, so the repository
   stays small. Your other branches are never touched."

A host note under the address changes with the host recognized in it. It
changes help text only; the connection works the same for every host.

| Host | Token to create | Username |
| --- | --- | --- |
| github.com | Fine-grained token for this one repository, Contents: read and write | Your GitHub username |
| gitlab.com, or a path that looks like GitLab | Personal or project token with `write_repository`; note tokens expire within a year | Any non-empty value |
| bitbucket.org | API token with repository read and write (app passwords no longer work) | Your Bitbucket username |
| Gitea / Forgejo (recognized by a probe of the server, or unknown) | Token with `write:repository` | Your username |
| Anything else | A token or password with push access | As the host requires |

Each host note links to that host's token documentation.

Buttons: **Test connection** and **Save**, plus **Remove configuration** when
one exists, matching WebDAV's dialog text pattern ("Files on the server are
kept").

Test connection performs receive-pack discovery, which needs push permission
on every major host, plus `ls-refs`. It then checks the branch safety rules
and reports, in order of what to fix:

- the address is not a Git repository, or cannot be reached;
- the username or token was rejected;
- the token can read but not push;
- the branch exists with other content;
- success, saying whether the branch exists or will be created, and noting
  when a newly created branch will become the repository's default.

Save runs the same checks first. The address is validated and normalized:

- `https` is required;
- a trailing `.git` and the web URL form of the major hosts are both
  accepted;
- credentials embedded in the URL are refused.

The setup wizard's backup and sync step lists Git beside WebDAV and opens the
same page. Connected Accounts (Settings > Data) shows the Git account like
the WebDAV one.

## Status and errors

The Cloud sync page shows, for Git:

- the repository (host and `owner/name`);
- the branch;
- the last sync time;
- when history was last reset (from `.submersion/branch.json`).

The Settings > Data health strip treats Git like the other backends.

Error text, every string in every supported language. Each message says what
to do next:

- the token was rejected or has expired (paste a new one);
- the token cannot push to this repository;
- the repository was not found;
- the host could not be reached;
- the host refused a file as too large (name the size);
- the host refused a history reset because the branch is protected (name the
  setting on that host);
- the host is rate-limiting (Submersion will retry later);
- an unexpected reply.

A backup that the host refuses as too large (GitHub and Bitbucket block files
of 100 MB) follows the existing path: the backup stays local and the health
flag for a missing cloud copy is raised. No backup splitting in this version.

Self-hosted servers with a certificate the platform does not trust: reuse the
WebDAV certificate-trust flow (`webdav_tls.dart` and its dialog) if it
generalizes cleanly to a second backend. Otherwise this version requires a
publicly trusted certificate and says so in the error. Builder's call, stated
in the PR.

## Wiring

- **Enums:** `CloudProviderType.git` and `AccountKind.git`. The provider type
  is persisted by name, and two lookups mishandle a name they don't know:
  - `sync_providers.dart` (around line 1330) uses `firstWhere` with no
    `orElse`, so it throws;
  - `SyncRepository.getCloudProvider` silently falls back to Google Drive.

  Builds after this one know `git`. Make both lookups return "no provider"
  for an unknown name, so a future backend added the same way cannot crash
  or silently redirect sync. `AccountKind` needs no schema floor bump:
  unknown kinds are already skipped from schema 280 on.
- **Shared instance:** a singleton in `cloud_provider_instances.dart`, with a
  concrete-typed getter for the config page.
- **Every exhaustive `switch` over these enums** gets a Git arm, among them:
  - `sync_providers.dart`;
  - `cloud_sync_page.dart`;
  - the setup wizard;
  - the account adapters;
  - `media_store_service.dart`, where Git returns null (not a media store)
    and the media storage page does not offer it.
- **Background sync:** the headless isolate path supports Git like the
  others.
- **Switching backends** uses the existing backend-switch flow; no new
  migration logic.
- **Schema:** no change and no migration.

## Testing

- **Unit tests** for each client piece:
  - pkt-line;
  - pack reading, with real packs produced by stock `git`, covering both
    delta kinds;
  - pack writing, with the output verified by stock `git index-pack`;
  - tree and commit encoding, byte-for-byte against `git hash-object` and
    `git mktree`.
- **Provider tests** against an in-process fake:
  - durability of uploads;
  - deferred deletes hidden from listings;
  - stale-tip rebuild and retry;
  - reset threshold and compare-and-swap;
  - every branch safety rule, each with a test that fails when the rule is
    removed.
- **Interop tests** against a real server: stock `git http-backend` served
  on localhost, which needs only `git` on the CI runner, in Linux CI. They
  cover:
  - create branch;
  - push;
  - concurrent pushes from two clients;
  - fetch with and without `filter`;
  - protocol v0 fallback;
  - history reset;
  - refusal of an existing branch with other content (including `main`);
  - creation in an empty repository, and adoption by a second client.

  These tests must run in CI, not skip. Assert that they ran, since local
  Docker is not available for verification. Optionally add a Gitea service
  container job for a second implementation.
- **Widget tests** for `GitConfigPage`: host notes, validation, and each
  test-connection outcome.
- **Before committing:** `test/architecture/` and `test/shared/` run after
  adding files under `lib/`.

## Left to the builder

- File and class layout inside `lib/core/services/cloud_storage/git/`.
- The push pacing mechanism, within the durability rule.
- The pending-delete quiet period, and the object cache size and eviction.
- The exact history reset threshold, starting from 256 MB.
- The detection heuristic for Gitea/Forgejo and self-managed GitLab (help
  text only).
- Whether to reuse the WebDAV certificate-trust flow (see above).
- Wording of every string, following the app's existing sync error tone.
