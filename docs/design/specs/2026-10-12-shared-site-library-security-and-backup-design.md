# Shared site libraries: privacy, signing, encryption and backup

Issue: #2567. Release: v1.8.3. PR: #3324.

Builds on [the shared site library design](2026-10-12-shared-dive-site-library-design.md).
Everything here ships in the same PR, before the feature's first release, so
library format version 1 is retired rather than migrated: test libraries are
recreated.

## Problem

The first design left five gaps, raised after the PR's review:

1. Adding a site shares its notes and rating, which are personal opinions.
2. Nothing tells the people running the storage how to issue keys, although
   storage keys are the only hard permission boundary.
3. Two libraries on one bucket or server share one account, so the second
   library's keys replace the first's.
4. Roles and edit attribution are honest-client conventions: anyone with
   write keys can rewrite `roles.json` or claim another member's edits, and
   the storage operator can read everything.
5. An owner has no way to back up a library or recover from a bad edit,
   a deleted folder or a lost bucket.

The feature is also renamed throughout: it is a "shared site library" in
strings, code, routes, tests and docs, and the earlier organisation-specific
name is retired.

## Decisions

| Question | Decision |
| --- | --- |
| Notes and rating | Never uploaded; each member keeps their own on a library site, on the device |
| Adding a site | A confirmation lists what is shared and what stays private |
| Setup guide | A sheet on the connect page and a user docs page |
| Keys per library | Account identity includes the library folder |
| Who vouches for a signing key | Owners approve each member's key |
| Key scope | One Ed25519 key per diver profile, carried by personal sync |
| Lost or absent owner | Recovery code, a one-owner warning, and a member-approved ownership reset |
| Encryption | Optional; an owner turns it on or off at any time; changing the passphrase makes a new key |
| Library key on a member's devices | Unlocked once per profile, carried by personal sync |
| Backup | A zip of the library folder, kept on the device and in the library's storage |
| Restore | Back to the backup exactly, re-stamped and signed by the restoring owner |
| Automatic backup | Daily on owner devices, newest 7 unpinned kept per location |
| Earlier name | Retired from this feature everywhere; unrelated older uses of the word stay |

## 1. Private notes and rating

`notes` and `rating` leave `SiteDocument.fieldNames`. A document is built
without them, and an incoming document's `notes` or `rating` entries are
dropped on decode. Merges only write fields in `fieldNames`, so the columns
of a library site row hold the local member's own values and nothing remote
reaches them. Library rows stay out of personal sync, so these values stay
on the device. Pushing a personal site keeps its notes and rating on the row
(same id) and uploads neither. Suggestions, the edit history sheet and the
suggestion review diff no longer offer either field.

"Add to shared site library" first shows a confirmation: "Add *name* to
*library*?", listing what other members will see (name, location, depths,
description, hazards, access, entry and exit, mooring, parking, site types,
tags, species, features) and what stays private (your notes and rating; dives
and photos never leave your personal library). Cancel leaves the site
personal.

## 2. Storage setup guide

The connect page gains "How to set up storage", opening a sheet:

- Libraries live in `submersion-sites/<folder>/` at the top of the bucket or
  server.
- Two kinds of keys. Owners and editors: read and write the library folder.
  Everyone else: read the library folder, write only `members/` and
  `suggestions/`.
- An example S3 IAM policy for each kind, with a Copy button, scoped to
  `submersion-sites/<folder>/`.
- WebDAV: give readers a read-only share of the folder and a writable share
  of `members/` and `suggestions/` where the server allows it (Nextcloud
  share permissions); otherwise the role file still governs the app.

`docs/user/shared-site-libraries.md` is the full user guide: connecting,
roles and approval, private fields, encryption, recovery code, backups, and
the storage guide above. It is listed in `docs/user/_sidebar.md`.

## 3. One name

Every user-facing string in all eleven locales, identifier, comment, route,
test name and design document of this feature says "shared site library"
(or "library" where the context is clear); the earlier name appears in
none of them. Routes move to `/settings/shared-libraries...`. Older, unrelated
uses of that word elsewhere in the app (a species name, the dive centre
search text, certification providers) are not part of the feature and stay.

## 4. Separate keys per library

`LibraryAccountSetup.saveS3(server, folder:)` and `saveWebDav(server,
folder:)` store the account with prefix `submersion-sites/<folder>/` (WebDAV
folder `submersion-sites/<folder>`), so `s3NaturalKey` and
`webdavNaturalKey` give each library on a server its own account and its own
keychain entry. The label is `<bucket> @ <host> (submersion-sites/<folder>)`
or `<user> @ <host> (submersion-sites/<folder>)`. The transport still
resolves the library from the storage top, so the account prefix is identity
only. On the connect page the folder field moves above the account picker
and the inline account form saves for that folder. Existing sync and media
accounts stay in the picker. A folder whose first segment is one of a
library's own folders (`sites`, `members`, `suggestions`, `backups`) is
refused, so a library at the top of `submersion-sites` never shares a folder
with another library.

## 5. Signed edits

### Keys

Each diver profile has one Ed25519 key pair, made the first time it creates
or joins a library and used for every library. The private key lives in a
pair of columns on the profile's membership rows (see Local data model),
carried to the profile's other devices by personal sync: encrypted in transit and at rest only when personal sync encryption is
on. The member card `members/member-<id>.json` carries `publicKey` and is
signed by that key.

A profile without its key on a device (a fresh install without personal
sync) makes a new one; its card then shows a different key and the member is
Pending again.

### Roles and approval

`roles.json` becomes:

```json
{
  "version": 7,
  "owners": ["m1"],
  "editors": ["m2"],
  "approvedKeys": {"m1": "<base64>", "m2": "<base64>", "m3": "<base64>"},
  "recovery": {
    "publicKey": "<base64>",
    "salt": "<base64>",
    "kdf": {"alg": "argon2id", "m": 65536, "t": 3, "p": 1}
  },
  "reset": false,
  "signedBy": "m1",
  "signature": "<base64>"
}
```

The signature covers the canonical JSON of every other key, prefixed with
`ssl-roles:v1`, a newline, the library id and a newline, so roles signed for
one library never count in another. A device keeps
the last `roles.json` it trusted for each library (`trustedRolesJson` on the
library row) and accepts a new one only when:

- `version` is greater than the trusted version, and
- `signedBy` is an owner of the trusted version and the signature verifies
  with that owner's trusted approved key, or `signedBy` is `recovery` and it
  verifies with the trusted recovery key.

At join the device trusts the `roles.json` it finds when it is
self-consistent (signed by one of its own owners or its recovery key). A
device that already trusts roles for the library (another profile's
membership, a reconnect) keeps them, and the folder's roles go through the
rules above. An ownership reset counts only with a single owner who signed it
with the key it approves. While the folder holds roles the device refused, it
only reads the library: its uploads would fight owners it does not know.
Owner actions there are refused before they change a file, since roles it
wrote would undo changes it never saw; only the recovery key signs past the
folder's version. An owner who steps down to editor is recorded like one who
leaves (their key retired at that time), so the roles they sign doing it stay
self-consistent for a device that joins later. The
library page shows each owner's key fingerprint (first 16 hex digits of the
SHA-256 of the public key, in groups of four) so members can compare it
person to person.

A `roles.json` that fails these rules is ignored and the library page warns
"The roles file was changed by someone who is not an owner". The creator's
key is approved in the first `roles.json`. The role a device honours is the
trusted file's role, capped by read-only detection as before.

The Members page shows owners a Pending section (members whose card key is
not the approved key for their id) with name, fingerprint, Approve and
Reject. Approve writes a new signed `roles.json` adding the key; Reject
deletes the card and removes any approval. Readers see only approved
members.

### Signing fields

Each `FieldClock` gains `sig`, an Ed25519 signature by the clock's member
over the UTF-8 bytes of:

```
ssl-field:v1
<libraryId>
<siteId>
<field>
<hlc>
<memberId>
<hex SHA-256 of the canonical JSON of the field's value>
```

`deleted` is signed the same way. An upload carries other members' clocks
and signatures unchanged; the uploader signs only the fields it stamps.

On pull a device verifies only the remote fields it would adopt (those newer
than its own clock). A field with no signature, a bad signature, or a signer
with no approved key in the trusted roles is treated as absent: the local
value stays, and the device's next upload of that site writes its own signed
value back. When the trusted roles change, the library's stored remote
modification stamps are cleared so the next sync re-reads every document
and applies edits held back from members just approved.

Verification runs off the UI isolate. The first sync after joining verifies
every field once; the build measures it (target: under 10 s for 500 sites on
a mid-range phone) and batches by isolate if needed.

### Suggestions

A suggestion carries `signedBy` and `signature` over its canonical JSON.
Owners list and act on verified suggestions only; others stay on storage
until their author is approved.

### Recovery code and owner loss

At creation the app makes a library recovery code (the word format of
`RecoveryCode`) and shows it once, as encrypted sync does. Argon2id of the
code with `recovery.salt` gives a 32-byte seed for an Ed25519 key pair whose
public key is `recovery.publicKey`. A `roles.json` signed with it is
accepted like an owner's.

- Library page, "Recover ownership": enter the code; the device signs a new
  `roles.json` (version + 1) making the profile an owner with its current
  key approved.
- Owners can issue a new code, which replaces `recovery` in a new signed
  `roles.json` (and the recovery keyslot when encrypted, section 6).
- While a library has one owner, its page warns "Only one owner. If they
  lose access, only the recovery code can restore it." with a button to the
  Members page.
- "Reset ownership", for someone with full storage keys but neither an owner
  key nor the code, writes a `roles.json` with `reset: true` naming their
  profile as the only owner, signed with their own key. Each member's device
  finds a file it cannot accept by the rules above and, because `reset` is
  set, asks "Ownership of *library* was reset by *name* (*fingerprint*).
  Accept?". Accept makes it the trusted file. Decline keeps the library
  read-only on that device with a banner that reopens the question. On an
  encrypted library the reset needs the library key (the person resetting
  has unlocked it), since `roles.json` is written encrypted.

## 6. Encryption

### Keys and files

An encrypted library has a random 256-bit library key with id `keyId`,
wrapped in `keyslots.json` (the `KeyslotFile` format: Argon2id and AES-GCM)
with two slots: `passphrase` and `recovery` (the section 5 recovery code).
The data key is HKDF of the library key with info `ssl:v1:data`. Every
encrypted file is an SBE1 envelope (`SyncEnvelope`, AES-256-GCM, gzipped)
sealed with `keyId` and with the file's path inside the library folder as
associated data (`sites/site-<id>.json`), so a file cannot be swapped for
another.

Encrypted: site documents, member cards, `roles.json`, suggestions, and
`info.json`, which holds the library's name. Plain: `manifest.json` (id,
format version, `encrypted`, `keyId`) and `keyslots.json`. File names,
counts, sizes and change times stay visible to the storage operator.
Signatures cover plaintext; encryption wraps the signed document.

A reader recognises an envelope by its magic bytes, so plain and encrypted
files can coexist while a library is converted.

### Unlocking

Check on an encrypted library says "Encrypted library. Enter the passphrase."
and accepts the passphrase or the recovery code; then it shows the name and
Join. The unlocked key is stored on the profile's membership row for the
library, carried by personal sync like the signing key, so a
member enters it once per profile. A device that meets a `keyId` it does not
hold stops uploading to that library and asks for the passphrase.

### Turning it on, off, and changing the passphrase (owners)

- **On:** the owner picks a passphrase (encrypted-sync strength rules) and
  gets a new recovery code, which replaces the library's old one for every
  owner (the help text and guide say so). The device writes
  `keyslots.json`, then the manifest with `encrypted: true` and `keyId`
  (from here no device writes plain files), then rewrites every file
  encrypted.
- **Off:** records `encryption: {on: false}` in a signed `roles.json`,
  writes the manifest with `encrypted: false` and the rewriting flag,
  rewrites every file plain, clears the flag, and removes `keyslots.json`
  and the list of earlier keys. Members' devices drop the stored key, and
  any key personal sync kept aside for it.
- On and passphrase changes record `encryption: {on: true, keyId}` in the
  signed roles. The manifest is not signed, so a device believes a manifest
  that says off only when the roles it trusts agree; otherwise it keeps the
  key and keeps writing sealed.
- **Change passphrase:** a new library key and `keyId`, a new recovery code
  shown to the owner, a new `keyslots.json`, a new signed `roles.json`
  carrying the new recovery key, then every file rewritten with the new key.
  Devices holding the old key ask for the new passphrase.

Every sync on an owner device also converts any file that does not match the
manifest (a plain file in an encrypted library, an old-key or encrypted file
otherwise), so a member who uploaded during a switch cannot leave the library
mixed for long.

### Limits (documented)

Anyone removed keeps what they already downloaded. Losing both the
passphrase and the recovery code makes an encrypted library unreadable.

## 7. Backup and restore

### The backup file

A zip of the library folder as stored (encrypted files stay encrypted):
`manifest.json`, `keyslots.json`, `info.json`, `roles.json`, `members/`,
`sites/`, `suggestions/`, plus `backup.json`:

```json
{
  "backupId": "<uuid>",
  "libraryId": "<uuid>",
  "name": "<plain name, omitted when encrypted>",
  "createdAt": "<iso>",
  "createdBy": "<memberId>",
  "appVersion": "1.8.3",
  "formatVersion": 2,
  "automatic": false,
  "note": "",
  "siteCount": 412,
  "memberCount": 51,
  "contentSha256": "<hex>",
  "signature": "<base64>"
}
```

`contentSha256` is over the sorted entry names and bytes; the signature is
the creator's over the rest of `backup.json`. A backup whose hash or
signature fails is refused on import and restore. A restore also needs the
backup to be the one picked (its `backupId`) and its creator to be an owner in
the roles the device trusts now, with the key they approve: the roles inside a
zip are whatever its maker wrote. File name:
`submersion-sites-<folder>-<yyyy-mm-dd-hhmmss>-<first 8 of backupId>.zip`,
the folder name cleaned to letters, digits, `_` and `-` and capped.

### Where backups live

Both places for every backup:

- the device, in the app's backups directory under
  `shared-libraries/<libraryId>/`;
- the library's storage, in `submersion-sites/<folder>/backups/`, with
  `backups/index.json` (owner-signed) holding each backup's note, pin and
  counts. Restore and the kind-folder listings skip `backups/`.

The library page's Backups list (owners only) merges both by `backupId`;
each row shows date, note, sites, size, an Automatic tag and where it is
kept (This device, Library storage, Both), with pin, delete (from one place
or both), Export (share sheet or save dialog) and Restore. The list header
has Back up now (with an optional note) and Import. Rows reuse the database
backup tile.

### Automatic backups

After a successful library sync on an owner's device, at most once a day,
and not when any storage backup is younger than 20 hours (so several owners
make one a day between them). Each location keeps the newest 7 unpinned
backups; pinned backups are never pruned.

### Restore: back to the backup

Owner only, run under `SyncCoordinator` like a sync:

1. Back up the current state, pinned, marked as made before a restore (the
   list shows it so; its note stays empty).
2. Every site in the backup is written with every field re-stamped (fresh
   HLC) and signed by the restoring owner.
3. Every site in the library but not in the backup gets a fresh signed
   tombstone; members' dives keep a personal copy as for any delete.
4. Roles come back from the backup with `version` above the trusted one,
   signed by the restoring owner, who always remains an owner. Members whose
   keys the backup did not approve return to Pending.
5. Member cards and suggestions come back as they were. Cards of members
   who joined since stay, pending until approved; other suggestions are
   removed.

The result is written under the library's current encryption setting and
key. A backup sealed under an older key asks for that key's passphrase or
recovery code to read it.

Restore into an empty folder moves a library: it keeps the library id, so a
member reconnecting through the new folder keeps their membership. The
restoring profile, when an owner with the approved key, signs the restored
roles one version past the backup's, this device's trusted roles and the old
folder's, keeping itself an owner, so members who trust later roles accept
them. On a device that holds the library only such an owner may restore it.
If the old folder still holds the library, the app warns that the two will
drift apart.

A member who already holds a detached personal copy of a restored site sees
both; they are not merged, so that member's own edits are never lost.

## Local data model

Added to the v289 schema helper, which has not shipped and runs again in
`beforeOpen`, so no new rung is needed.

| Table or column | Synced (personal) | Content |
| --- | --- | --- |
| `shared_library_memberships.signing_public_key`, `signing_private_key` | yes | the profile's key pair, the same on every membership row of the profile |
| `shared_library_memberships.library_key_id`, `library_key` | yes | the unlocked library key |
| `shared_libraries.rolesJson` | no | now the last trusted `roles.json` |
| `shared_libraries.roles_rejected`, `pending_roles_json` | no | the warning, and a reset waiting for the member's answer |
| `shared_libraries.encrypted`, `key_id` | no | manifest state |
| `shared_libraries.last_auto_backup_at` | no | this device's last automatic backup |
| `shared_libraries.notes_backfilled` | no | the profile notes of this library's sites were copied into `library_site_notes` once |
| `shared_libraries.spare_key_id`, `spare_key` | no | a library key personal sync brought before this device saw the change that made it, taken up once the manifest names it |
| `library_site_notes` | yes | each profile's private notes and rating for a library site |
| `shared_library_backups` | no | backupId, libraryId, note, pinned, automatic, counts, size, localPath, inStorage |

The member id already lives on the membership rows and is the same on all of
a profile's rows; the keys follow the same pattern, so personal sync carries
them with no new serializer arms. A membership row arriving without keys
never erases keys a device already holds.

## Error handling

- A roles file that fails verification: ignored, warning on the library page.
- A wrong passphrase or code: "That passphrase does not open this library".
- A missing key for the current `keyId`: no uploads, a banner asking for the
  passphrase.
- Restore or a conversion interrupted: resumable, since each step rewrites
  whole files and an owner sync finishes any file that does not match the
  manifest.
- A backup that fails its hash or signature: refused with the reason.

## Testing

- Documents: notes and rating never encoded; dropped on decode.
- Signing: field signatures round trip; a tampered value, a wrong signer, an
  unapproved key and a missing signature are each ignored and rewritten by
  the next honest upload; approval re-reads held edits.
- Roles: version rollback refused, non-owner signature refused, recovery
  signature accepted, reset prompts and both answers.
- Encryption: on, off and change passphrase over the fake provider, with a
  member mid-sync during each; wrong passphrase; old-key device stops
  uploading; owner sweep converts stray files.
- Backups: zip round trip, hash and signature checks, pruning with pins,
  daily throttle across two owners, restore of edited, added and deleted
  sites and of roles, restore into an empty folder, restore of an old-key
  backup.
- Widgets: add confirmation, setup sheet with copy, Pending approval,
  one-owner warning, reset dialog, unlock prompt, Backups list actions.
- Accounts: two libraries on one bucket keep separate keys.
- Personal sync guards for both new synced tables.

## Out of scope

Revoking data a removed member already downloaded, hiding file counts and
sizes from the storage operator, per-device signing keys, merging a detached
personal copy back into a restored site, and media in libraries.
