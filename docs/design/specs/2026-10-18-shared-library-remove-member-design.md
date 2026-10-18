# Removing people from a Shared Site Library

Date: 2026-10-18
Release: v1.8.3
Builds on: [shared dive-site library](2026-10-12-shared-dive-site-library-design.md),
[security and backup](2026-10-12-shared-site-library-security-and-backup-design.md)

## Intent

An owner needs to remove a person from a Shared Site Library: someone who has
left the group, or simply to tidy the list of people who have access. Today
the only removal is **Reject**, offered for members still waiting for
approval. An approved member cannot be removed at all; an owner can only
demote them to reader.

The maintainer's rule: **anything a person contributed always stays**,
whether or not they are still a member.

## Goals

- An owner can remove any approved member other than themselves, from the
  Members page, behind a confirmation.
- Everything the removed person signed before the removal keeps counting on
  every device. Nothing they sign afterwards counts.
- The removal sticks: the removed person's app does not silently put them
  back in the list.
- An owner can undo a removal ("Allow back"); the person then goes through
  normal approval again.
- The removed person's app tells them they were removed.

## Non-goals

- Revoking storage access. Storage credentials remain the hard boundary
  (2026-10-12 design). A removed person who still holds the storage keys can
  read the library (and decrypt it, if they know the passphrase). The
  confirmation says so: cutting off reading means changing the storage keys,
  and the passphrase if the library is encrypted. Automating key rotation is
  out of scope.
- Changing **Reject** for pending members, or **Remove role** in the "Left"
  section. Both stay as they are. Reject still discards everything a never
  approved key signed, which is right for a stranger nobody approved.

## Anti-goals

- Any removal that makes a past contribution disappear, on any device, now or
  after a later sync. This is why Remove cannot reuse `rejectMember` as it
  stands: Reject deletes the person's approved key and clears their retired
  keys, so `dropUnverified` stops accepting every field they ever signed.
- Breaking libraries shared with members still on v1.8.2. Signed roles
  shipped in v1.8.2, and the signature covers the re-serialized model
  (`SharedLibraryRoles.unsignedJson`). A new field in `roles.json` would fail
  signature checks on every v1.8.2 device, which would then refuse the roles
  and hold the library read-only. So the roles file gains **no new field**.

## Design

### Roles change (existing fields only)

Removing member `M` at time `T` rewrites `roles.json`, signed by the acting
owner, as:

- `M` moves to reader (out of `owners` and `editors`).
- If `M` was an editor or owner with an approved key, that key is added to
  `retired[M]` with `until = T`, exactly as `SharedLibraryRoles.changeRole`
  already does on a demotion, so every edit they signed before `T` keeps
  counting.
- `M`'s key is removed from `approvedKeys`.

A reader's key is **not** retired (builder's call, from the review). A
reader's direct field edits never counted, so they were never contributions;
retiring the key would start accepting them, and since the time compared is
the author's own signed clock, a removed reader with storage write access
could backdate new edits into acceptance. The last-owner guard applies as it does for
`setRole` (in practice it never fires, since an owner cannot remove
themselves).

### The removal record

The lasting "this person was removed" fact lives in its own file, not in
`roles.json`, so v1.8.2 devices ignore it:

- Path: the library's members folder, file `removed-<memberId>.json`, beside
  the `member-<memberId>.json` cards. v1.8.2 lists that folder filtered by
  the `member-` prefix, so it never sees these files. Sealed like a member
  card when the library is encrypted.
- Contents: `memberId`, `displayName` (from the card at removal time, so the
  Removed list can name the person after the card is gone), `publicKey` (the
  key the owners had approved for them, when there was one), `removedAt`
  (ms), `removedBy` (the acting owner's member id), `signature`.
- Signature: over `ssl-removal:v1\n<libraryId>\n<canonical json of all but
  the signature>`, made with the acting owner's signing key, following the
  roles and suggestion signature pattern.
- Valid when signed by a key that the current roles approve for a member who
  is an **owner** now. (Removal is always done by a signed-in owner, so the
  recovery key never signs one.) An invalid or unreadable record is ignored
  (the person is treated as not removed).

Known limit (accepted): a removal signed by an owner who later leaves the
library no longer verifies, and the person can reappear as pending (still
unapproved, so nothing they sign counts).

### Order of writes

`removeMember` (owner only, refused for the acting member themselves):

1. Write the signed roles change. If this fails, nothing else happens and
   the error is shown as for any other owner action.
2. Write the signed removal record.
3. Delete `M`'s member card.
4. Refresh the local member list and the cached removals.

`allowBack` (owner only): delete the removal record and refresh the cache.
Roles are not touched; the person's next sync rewrites their card and they
appear as pending, to be approved (and given a role) as usual.

### Sync

Each library sync lists and verifies the removal records alongside the
member cards, and caches the valid ones locally.

- **On the removed person's device** (its own member id has a valid record):
  - it does not rewrite its member card;
  - it holds all writes, as for a read-only library (no site uploads, no
    suggestions);
  - downloads continue, so the library stays current and readable.
- **On every device:** a member with a valid removal record is never treated
  as pending (their key is not held, it is simply not approved), and the
  Members page lists them only under Removed.
- A v1.8.2 device that was removed keeps rewriting its card; newer owners'
  apps show it under Removed, and its edits are dropped because its key is
  no longer approved. A v1.8.2 owner sees that card as pending. Both are
  acceptable for a release-to-release overlap.

### Undecided suggestions (maintainer's decision)

A removed person's suggestions that no owner has accepted or declined yet
**stay reviewable** in every owner's inbox. Today `_pullSuggestions` trusts
only `roles.approvedKeys` (pending) or the author's card key (held), and
deletes anything else from the local inbox; removal takes away both, so a
device that had not pulled the suggestion yet would drop it while devices
that had would keep it.

So suggestion verification gains a third source: a valid removal record's
`publicKey`, for a suggestion whose `createdAt` is at or before the record's
`removedAt`. Such a suggestion comes in as pending, and an owner decides it
as usual. Suggestions already pulled are untouched (they are not re-read).
`createdAt` is the author's own claim, so a removed person could backdate a
new suggestion; that is accepted, because an owner still reviews every
suggestion before it changes anything. Owners still on v1.8.2 drop these
suggestions from their own inbox; that is accepted for the release overlap.

### Backups and restore

Backups leave removal records out. A backup archive accepts only a fixed set
of file names, and a v1.8.2 owner refuses any archive holding another, so a
backup with `removed-*.json` in it could not be restored there. A restore
instead keeps the folder's current records and applies each again to the
roles it brings back, so a removal outlives a restore from a backup taken
before it; the backup's card of someone removed since is deleted again. A
restore into an empty folder starts from the backup alone and carries no
removals. (Builder's call, revised during the build.)

### Removals outlive their owner's ownership

Every owner roles write re-signs, as the writing owner, each record that held
under the roles it replaces but not under the new ones. Removing, demoting or
re-keying the owner who removed someone therefore keeps that removal. An
owner who leaves signs their own demotion and is no owner afterwards, so
their removals lapse: the known limit below, now limited to that case.

Reject keeps any keys the member had retired before (someone removed, then
allowed back), so rejecting them never takes back what they contributed.

When a member has both a valid removal record and an approved key (a
restore race, or an old owner app approving them), **the record wins**: they
are listed under Removed and their own device holds writes. (Builder's
call.)

### Local cache

The valid removal records for each library are cached on the device in a new
nullable text column on `shared_libraries` (JSON list), written by sync and
by `removeMember` / `allowBack`. It is device-local, like the rest of that
table. This needs a schema rung, added the usual way (new table file column,
migration rung under `lib/core/database/migrations/`, schema test).

### Members page (owners)

- **Approved member rows** (not the owner's own row): the role menu gains a
  divider and a **Remove from library** item.
- **Confirmation dialog:** title "Remove {name}?". Body: they can no longer
  edit or suggest changes; sites and edits they already contributed stay in
  the library; they can still read the library until the storage keys are
  changed (and the passphrase, if the library is encrypted). Actions:
  Cancel, Remove.
- **Removed section** (owners only, after Pending and Left): each removed
  person with their name, "Removed {date}" (date in the diver's preferred
  format), and an **Allow back** button. No confirmation for Allow back,
  since it grants nothing by itself.
- Pending excludes removed people.
- Errors (offline storage, a refusal) show in a snack bar, as the page's
  other owner actions do.

### Library page (removed person)

A banner, in the style of the existing read-only and roles banners: an owner
removed you from this library; its sites stay on this device but you can no
longer change them; leaving the library keeps personal copies of the sites
you dived. The existing Leave action is unchanged.

### Strings

All new strings in all ten ARB locales, translated, following the
`sharedLibrary_members_*` and `sharedLibrary_library_*` naming. The feature
is a "Shared Site Library"; no string, identifier, comment or test uses the
word "club".

## Testing

- Model: removal record sign/verify (valid owner, non-owner signer,
  tampered field, wrong library id).
- Roles: removal retires the key with the right `until` for owner and
  editor, does not retire a reader's, drops the approval, and a field signed before `T` still passes
  `dropUnverified` while one signed after does not.
- Service: `removeMember` write order and refusals (self, non-owner, roles
  write failure leaves no record and the card in place); `allowBack`.
- Sync: the removed device neither rewrites its card nor uploads; other
  devices do not hold the removed key as pending; an undecided suggestion
  from before the removal is pulled as pending, one dated after it is not.
- Widget: Remove appears for other approved members and not for the owner's
  own row or for non-owners; Cancel changes nothing; Remove calls the
  service; the Removed section and Allow back; the removed-person banner.

## Left to the builder

- Where the removal-record type and the roles helper live (new files are
  preferred: `shared_library_models.dart`, `shared_library_transport.dart`
  and `shared_library_store.dart` are already at or over 800 lines; the
  transport and store can take part files).
- The exact popup menu value type on the Members page.
- Error type for removing oneself (the UI never offers it).
