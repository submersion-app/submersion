# Shared library details and connection (issue #3389)

## Intent

A diver who has joined a shared site library cannot see where it lives, and
nobody can change anything about the library itself once it exists. Today the
account and folder are picked once on the connect page and never shown again;
the library's name is set once at creation and never again.

This feature adds two things to the library page
(`lib/features/shared_library/presentation/pages/shared_library_page.dart`):

1. **About:** the library's name and a new free-text description. Owners can
   edit both; every member sees them.
2. **Connection on this device:** the account, server or bucket, and folder
   this device uses to reach the library, with a way to repoint it to another
   account and/or folder that holds the same library.

The main user need is "see where the library lives" (the maintainer's words).
Changing the connection is the second need: today the only fix for a moved
folder or replaced account is Leave and rejoin, which loses private-notes state
and may need the owner to re-share access.

## Goals

- Show the connection details of a connected library: account label, account
  kind (S3 or WebDAV), the S3 bucket or WebDAV server where readable, and the
  folder (prefix).
- Let any member change this device's connection to a different eligible
  account and/or folder, but only after a check proves the new location holds
  this same library.
- Let an owner change the library's name and description, which every
  member's device picks up on its next sync.
- Show the description wherever a library is introduced: the library page, and
  the join preview on the connect page when the library is not encrypted.

## Non-goals

- Changing the library's id, format version, roles, encryption or members:
  those already have their own sections or are fixed.
- Moving the library's files. The user (or group) moves or copies the folder in
  their storage; this feature only repoints the device.
- A contact field, cover image, or default site visibility rules. Contact was
  considered and deferred until a group asks for it; images go against the rule
  that the app stores no photos; visibility rules are a policy feature.
- Signing `info.json`. The name is unsigned today and stays so; see
  Constraints.
- Repointing other devices. Each device holds its own connection.

## Anti-goals

- Saving a connection to a folder that holds a different library, an empty
  folder, a retired library, or one needing a newer app. The old connection
  must survive any failed check untouched.
- Any path that loses trusted roles, private notes, last sync, backups, site
  states or suggestions when the connection changes.
- Letting a non-owner's edit of name or description look accepted in the UI.

## Current state (what the builder starts from)

- `SharedLibrary` (`lib/core/services/shared_library/shared_library_models.dart`)
  holds `connectedAccountId` and `prefix`; `copyWith` cannot change either.
  The row lives in the device-local `shared_libraries` table
  (`lib/core/database/tables/shared_library_tables.dart`).
- The transport is built fresh on each use from the stored account id and
  prefix (`sharedLibraryTransportFactoryProvider` in
  `lib/features/shared_library/presentation/providers/shared_library_providers.dart`),
  so updating the row is enough to repoint every later sync.
- `SharedLibraryMembershipService.probe` returns a `LibraryProbe` with the
  manifest's `id`, `encrypted` and `keyId`; `unlockProbe` opens an encrypted
  one with a passphrase or recovery code.
- `SharedLibraryMembershipService.join` already accepts a library whose row
  exists from an earlier account: it keeps trusted roles, `rolesRejected`,
  `pendingRoles`, `lastSyncAt` and `lastAutoBackupAt`, writes the member card
  at the new location, and stores the new account and prefix. The connection
  change should reuse this logic (or extract its shared core) rather than
  duplicate it, with the extra rule that the probed id must equal the
  library's id.
- Each profile's `SharedLibraryMembership` carries `libraryName`,
  `backendKind` and `locationHint` (`'<account label>: <prefix>'`), and these
  rows reach the profile's other devices through personal sync.
- The library name lives in `info.json` in the library folder
  (`SharedLibraryTransport.readInfo` / `writeInfo` / `readName`). It is
  written once by `createWithRecovery` as `{'name': name}`, and each sync
  re-reads it into `shared_libraries.name` via `setLibraryStatus(name: ...)`.
  `info.json` is sealed like other files when the library is encrypted.
- `eligibleLibraryAccountsProvider` lists the S3 and WebDAV accounts; the
  connect page has the account dropdown, the "Add account" form, folder
  validation (`_folderProblem`) and the storage setup guide.
- `LibraryAccountSetup.s3Bucket(accountId)` reads an S3 account's bucket from
  its stored settings.

## Design

### Library page layout

As shown to and approved by the maintainer in a mockup:

- **About** section directly under the sync row: a tile with the library name
  as title and the description as subtitle (or nothing when it has none).
  Owners see an edit affordance; tapping it opens an editor for name and
  description. Non-owners see the same tile without the affordance and it is
  not tappable.
- The existing tiles follow (your name in this library, members, suggestions,
  add my sites, backups).
- **Connection on this device** section after the divider that ends those
  tiles, before Ownership and Encryption:
  - Account tile: the account label, with a subtitle naming the kind (S3 or
    WebDAV) and the S3 bucket or WebDAV server URL when it can be read from
    the stored settings.
  - Folder tile: the prefix as stored (an empty prefix shows as the root,
    worded by the builder).
  - A **Change connection** button opening the change screen.
  - When the account is no longer on this device (the transport factory
    throws in that case today), the account tile says so and the button still
    works, since repointing is the fix.

### Changing the connection

A new screen (route under `/settings/shared-libraries/<id>/connection`),
reusing the connect page's pieces: the folder field with its validation and
setup-guide link, the eligible-account dropdown, and the "Add account" form.
Shared widgets should be extracted from `connect_shared_library_page.dart`
rather than copied; that file is already 680 lines.

- The fields start with the library's current account and folder.
- **Check location** probes the typed folder on the chosen account.
  - Same id, not encrypted: show "Found <name>. This is the same library." and
    a **Save connection** button.
  - Same id, encrypted, and this device holds a key for the manifest's
    `keyId` (`SharedLibraryStore.cipherNamed` / `libraryCipherFor`): same as
    above.
  - Same id, encrypted, and no key held for that `keyId`: ask for the
    passphrase or recovery code (as the connect page does), then allow saving;
    the opened key is kept as `unlockLibrary` keeps it.
  - Different id: "This folder holds a different library (<name when
    readable>). Your connection is unchanged."
  - No manifest: "No library found in this folder. Your connection is
    unchanged."
  - Same id, but the copy looks older than this device's view: its
    `roles.json` (read and, when signed, checked as the sync checks it) has
    a lower `version` than the roles this device trusts. Show a warning,
    "This copy looks older than the one you have been syncing with", with a
    **Save anyway** button in place of Save connection. This catches a
    folder copied instead of moved, restored from an old backup, or left
    behind while the group writes elsewhere. A missing or unreadable
    `roles.json` at the new location is treated the same way (warn, allow
    save anyway). (Decided by the maintainer: warn, do not refuse, and do
    not probe the old location.)
  - Retired or needs-newer-app: the connect page's existing messages.
  - Storage errors: `libraryErrorText`, connection unchanged.
- Changing either field after a check clears its result, as on the connect
  page.
- **Save connection** re-checks the location (the folder may have changed
  since the check), then, inside `SyncCoordinator.run` so no sync runs on the
  old location meanwhile:
  - updates `connectedAccountId` and `prefix` on the library row, keeping
    every other field;
  - updates `backendKind` and `locationHint` on every local profile's
    membership of this library, so the profile's other devices see the new
    location (their own connection is untouched);
  - writes each local member's card at the new location as `join` does,
    tolerating a refused write the same way;
  - clears the per-file remote stamps (`SharedLibraryStore.clearRemoteStamps`,
    as a restore does), so the first sync at the new location compares
    content rather than the old location's modified times;
  - clears `lastError`.
  Then it starts a sync of this library and returns to the library page.
- Saving with the same account and folder as now is allowed and is a no-op
  apart from the re-check.
- Any member may change the connection, whatever their role: it only changes
  this device.

### Name and description

- `info.json` gains an optional `description` string beside `name`. Older
  app versions ignore unknown keys in `info.json` (verify this in
  `readName` and the backup and restore code); no format version bump.
- Writing is read-modify-write: keep any keys this version does not know.
- The local `shared_libraries` table gains a nullable `description` column
  (a schema bump: the builder picks the next free version after checking
  open PRs for claims, and follows the split layout in
  `lib/core/database/tables/` and `lib/core/database/migrations/`).
  `SharedLibrary` gains `description`; each sync reads it from `info.json`
  next to the name.
- The editor (owner only) has a name field (required, trimmed, not empty) and
  a multi-line description field (optional; empty clears it). The builder
  sets a sensible length cap on each.
- Saving writes `info.json` through the library's transport, then updates the
  local row (`name`, `description`) and every local membership's
  `libraryName`. On failure (offline, read-only keys) it shows
  `libraryErrorText` and changes nothing locally.
- Members' devices pick up both on their next sync, as the name already is.
  Their memberships' `libraryName` should follow a changed name on sync too.
- The join preview on the connect page shows the description under the
  library name when the probe can read it (unencrypted libraries, or after
  unlocking an encrypted one).

## Constraints

- `info.json` is not signed, and any member whose storage keys can write the
  folder can change it, as for the name today. The owner-only rule is enforced
  by the app's UI only. Accepted for this feature; noted in case signing the
  library's details is wanted later.
- Units are not involved.
- All new strings go through ARB localization.
- File size limits from `CLAUDE.md` (800 lines max); `shared_library_page.dart`
  is 407 lines, so the new sections should be their own widgets under
  `presentation/widgets/`.
- Tests first (TDD), including the failure paths in Anti-goals.

## Calls made for the builder (not agreed with the maintainer)

- About sits under the sync row; Connection sits before Ownership.
- A re-keyed encrypted library at the new location asks for the passphrase,
  as joining does.
- A changed connection updates the membership's location hint for the
  profile's other devices but never their own connection.
- Save re-checks the location before writing.
- A repoint clears the remote stamps, as a restore does.

## Left to the builder

- Exact wording of strings, icons, and the editor's form (dialog or page).
- Whether the connection change lives in `SharedLibraryMembershipService` or a
  small new service, and how much of `join` is extracted to share.
- Length caps for name and description.
- How the account tile reads the WebDAV server URL from stored settings.
