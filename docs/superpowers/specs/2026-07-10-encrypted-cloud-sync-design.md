# Encrypted Cloud Sync and Cloud Backups (E2E) — Design

Date: 2026-07-10
Issue: https://github.com/submersion-app/submersion/issues/520
Status: approved design, pre-implementation

## 1. Summary

Opt-in client-side encryption for everything Submersion writes to a cloud
provider: sync changesets, base snapshots, manifests, epoch/moved markers, and
cloud backup artifacts. A passphrase (plus a generated recovery code) protects
a random master key; the provider only ever stores opaque blobs. The sync
protocol keeps working unchanged because discovery is filename-based and all
merging is client-side.

### Threat model

- Protects against: the storage provider (Google, Dropbox, Apple, any S3
  operator) or anyone with access to the stored files reading logbook content
  (GPS positions, buddy names, notes, certifications); a provider swapping or
  replaying stored file contents undetected.
- Does not protect against: a compromised device, a weak passphrase under
  offline brute force, or traffic/metadata analysis (file names, sizes,
  timestamps, device counts remain visible — see Non-goals).

### Relation to the abandoned 2026-06-01 attempt

An earlier encrypted-sync feature (device-pairing model, ~77 commits, tip
`b1c008077e1`, still recoverable as dangling commits) targeted the old
full-snapshot transport and was abandoned. This design is fresh: the changeset
transport (PR #330) reduced the problem to encrypting discrete blobs behind a
single byte seam, and the passphrase model removes pairing entirely. Nothing
from the old branch is required.

## 2. Decisions (settled with the user)

1. Key model: wrapped master key. A random 256-bit master library key (MLK)
   is wrapped by passphrase-derived keys in a keyslot file (restic/LUKS
   pattern). Passphrase change rewraps one file; KDF parameters are
   upgradable; multiple slots are native.
2. Scope: sync payloads and cloud backups in one release. Local backup
   files (including pre-migration backups) stay plaintext.
3. Recovery: v1 ships with a recovery code (second keyslot) generated at
   enable time.
4. Architecture: an encrypting decorator around `CloudStorageProvider`, so
   every uploaded byte is ciphertext by construction.
5. Compression: gzip-before-encrypt inside the envelope, on by default for
   encrypted uploads (encrypted bytes are incompressible downstream; sync
   JSON shrinks 5-10x).

## 3. Cryptographic design

### 3.1 Key hierarchy

```
passphrase    --Argon2id(salt_p, params)--> KEK_p --AES-256-GCM unwrap--+
                                                                        +--> MLK (32 random bytes)
recovery code --Argon2id(salt_r, params)--> KEK_r --AES-256-GCM unwrap--+
                                                                        |
                                        data key = HKDF-SHA256(MLK, info="sbe:v1:data")
```

- MLK: generated once per encrypted library via `Random.secure()`; exists in
  the cloud only wrapped. Identified by a random `libraryKeyId` (UUID).
- Argon2id parameters (initial): m=64 MiB, t=3, p=1. Parameters are stored
  per slot in the keyslot file so they can be raised later by rewrapping.
- Wrong-passphrase detection is free: unwrap is AES-GCM, so a bad KEK fails
  tag verification. No separate verifier field.
- HKDF sub-derivation gives future domain separation (e.g. a media key)
  without touching keyslots.
- Recovery code: 8 words from the EFF short wordlist (1296 words, ~10.3
  bits/word, ~82 bits total), displayed hyphen-separated, normalized
  case-insensitively with whitespace/hyphen stripping on entry. The wordlist
  ships as an English constant (standard practice; not localized).

### 3.2 Keyslot file (the only plaintext file)

Cloud name: `submersion_keyslots.json`, in the sync folder. The name must not
contain the `submersion_sync` discovery stem (same rule as the epoch marker,
see `library_epoch.dart`).

```json
{
  "version": 1,
  "libraryKeyId": "<uuid>",
  "slots": [
    { "type": "passphrase", "salt": "<b64>",
      "kdf": { "alg": "argon2id", "m": 65536, "t": 3, "p": 1 },
      "nonce": "<b64>", "wrapped": "<b64 ciphertext+tag>" },
    { "type": "recovery", "salt": "<b64>",
      "kdf": { "alg": "argon2id", "m": 65536, "t": 3, "p": 1 },
      "nonce": "<b64>", "wrapped": "<b64 ciphertext+tag>" }
  ]
}
```

Unlock tries the matching slot type first, then all slots. The file is small
(< 1 KB) and rewritten only on enable, passphrase change, or recovery-code
regeneration.

### 3.3 Encrypted file envelope (single-shot; all sync files)

```
bytes 0-3   magic "SBE1"
bytes 4-19  libraryKeyId (16-byte UUID)
byte  20    flags (bit0 = payload gzipped before encryption)
bytes 21-32 nonce (12 bytes, random per file)
bytes 33-   AES-256-GCM ciphertext || 16-byte tag
```

- Key: the HKDF data key.
- AAD: UTF-8 of the logical cloud filename. A ciphertext served under the
  wrong name (provider bug or attack, e.g. replaying an old manifest as
  current) fails authentication instead of parsing.
- Download-side name resolution: `downloadFile` takes only a file id, so the
  decorator maintains an id-to-name map populated by its own `listFiles` /
  `getFileInfo` passthroughs (every sync download follows a list through the
  same instance — verified against all current call sites). On a cache miss
  it fetches the name via `getFileInfo` before decrypting.
- Per-file random 96-bit nonces are safe at this scale (GCM birthday bound
  needs ~2^32 encryptions; a library produces thousands).
- Legacy-client behavior falls out of the format: the binary envelope fails
  `utf8.decode`/`jsonDecode`, which is exactly the shipped fail-closed path
  (section 6).

### 3.4 Framed envelope (cloud backups)

Cloud name: `submersion_backup_<timestamp>.sbe`.

```
header:  magic "SBE1" | libraryKeyId (16) | flags (bit1 = framed)
         | uint32 keyslotBlockLen | keyslot block (same JSON as 3.2)
frames:  uint32 len | nonce (12) | GCM(<= 8 MiB plaintext chunk) || tag
         ... repeated; AAD = libraryKeyId || uint64 frameIndex || finalFlag
```

- Embedded keyslots make every backup self-decrypting with only the
  passphrase or recovery code — restorable on a fresh device with no sync
  configured, or from a file downloaded via the provider's web UI. Backups
  made under an older passphrase remain restorable with that passphrase
  (each artifact is a snapshot).
- 8 MiB frames bound crypto memory for multi-hundred-MB databases (sizing
  reference: the 648 MB library from #358). Frame index + final flag in the
  AAD prevent reordering and truncation.

### 3.5 Algorithms and packages

- AES-256-GCM, Argon2id, HKDF-SHA256 from `package:cryptography` (pure Dart,
  all 5 platforms, no native build risk), with `cryptography_flutter`
  registered so platform-accelerated implementations are used where
  available. Wire bytes are identical either way (standard primitives).
  Verify package maintenance status and current versions on pub.dev at
  implementation time.
- gzip via `dart:io` `GZipCodec` (available on all supported platforms).
- Known-answer test vectors are computed with python3 at implementation
  time, never from recall (standing project rule).
- Performance posture: measure before optimizing. No isolate offload up
  front; parts encrypt independently in bounded memory. If profiling shows
  jank on large publishes, offload per-part crypto then.

## 4. Runtime architecture

### 4.1 EncryptingCloudStorageProvider (decorator)

`EncryptingCloudStorageProvider implements CloudStorageProvider`, wrapping the
configured provider at its single construction point when encryption is
enabled. When disabled, the raw provider is used (zero overhead, zero change).

- `uploadFile(bytes, name)`: if `name` is exempt, pass through; else gzip
  (flag bit0), encrypt with AAD=name, upload envelope.
- `downloadFile(id)`: fetch bytes; `SBE1` magic -> decrypt (resolving the
  name for AAD from the file info) and gunzip per flags; no magic -> return
  as-is (plaintext passthrough is required to read legacy folders and detect
  foreign plaintext libraries).
- Exemption list (exactly two patterns):
  1. `submersion_keyslots.json` (it is the bootstrap key material).
  2. `submersion_backup_*` (the backup service applies the framed format
     itself because it embeds keyslots).
- Everything else — `listFiles`, folders, auth, `getFileInfo` — delegates
  untouched. File names are never encrypted.
- Failure typing: decryption problems raise distinct errors —
  `SyncEncryptionRequired` (envelope present, no local MLK, or
  `libraryKeyId` mismatch) vs `CloudStorageException` (auth-tag failure =
  corruption/tamper).

Consequences audited:

- Streamed base parts already pass through `uploadFile`/`downloadFile`
  per part (writer line ~102, reader line ~175), so streaming stays bounded.
- Manifest/changeset checksums are computed and verified above the seam, on
  plaintext, on both sides — unchanged. GCM tags independently authenticate
  ciphertext.
- `CloudFileInfo.sizeBytes` reflects ciphertext size. The only consumer that
  cares is the compaction byte-ratio trigger, which compares like with like
  (writer-recorded plaintext sizes); no change needed.

### 4.2 Local key custody

- MLK + `libraryKeyId` in `flutter_secure_storage` (Keychain / Keystore /
  DPAPI / libsecret), reusing the existing `FallbackSecureStorage` pattern
  from the S3 provider for the macOS `-34018` sandbox case.
- "Encryption enabled" flag + cached `libraryKeyId` in `SyncPreferences`
  (SharedPreferences). Deliberately not in the `settings` table: that table
  syncs, and these are device-local.
- No database schema migration is required.

### 4.3 Unlock gate

New `SyncResultStatus.awaitingPassphrase` (sibling of `awaitingAdoption`).
`performSync` catches `SyncEncryptionRequired` and halts with it; the Cloud
Sync page shows an "Enter passphrase" banner using the same interaction
pattern as the adopt banner. Unlock flow: derive KEK per slot, unwrap MLK
from the keyslot file, store in secure storage, re-run sync.

## 5. Lifecycle flows

Every flow rides existing, device-verified machinery; encryption adds one halt
state and one decorator, not new protocol.

- Enable (device A): set passphrase (entry + confirm) -> display recovery
  code with a confirm-saved step -> generate MLK -> upload keyslot file ->
  run the existing library replace (`executeLibraryReplace`) through the
  now-encrypting decorator. The replace already wipes all plaintext sync
  files and republishes marker + base; they come out encrypted. The enable
  dialog warns: all other devices must be updated and will re-download the
  library; lost passphrase + lost recovery code = cloud data unrecoverable
  (local data on devices is never at risk). Optional checkbox (default on):
  delete existing unencrypted cloud backups now.
- Join (updated device B): next sync raises `SyncEncryptionRequired` ->
  `awaitingPassphrase` banner -> passphrase entered -> unwrap MLK ->
  re-sync: the encrypted epoch marker now decrypts, epoch differs from
  accepted -> the existing adopt flow re-downloads the library.
- Legacy device C (older app): the encrypted epoch marker fails
  `utf8.decode`/`jsonDecode`/`fromJson`, so `_runEpochGate` fails closed
  ("Could not read the library epoch marker") until the app is updated.
  Nothing is destroyed or leaked (see section 6).
- Disable: confirmation -> library replace back to plaintext -> delete the
  keyslot file. The MLK stays in secure storage so previously made encrypted
  backups remain restorable without re-prompting.
- Change passphrase: rewrap slot 1 (new salt + nonce) in the keyslot file.
  Recovery code untouched; separate action regenerates it (re-auth with
  passphrase first). Documented explicitly: this does not rotate the MLK —
  full rotation = disable + enable.
- Conflicting re-enable: a device holding an MLK whose `libraryKeyId` does
  not match the cloud's envelopes/keyslot treats it exactly like join
  (re-prompt); copy explains the library's encryption was reset elsewhere.
- Backend switch: established-provider store and switch dialog unchanged.
  Establishing an encrypted library on a new backend writes the keyslot file
  as part of the first publish. Joining an encrypted backend via switch uses
  the same unlock flow.
- Backups-only user (cloud backups configured, sync off): enable works the
  same minus the library replace; no cloud keyslot file is required because
  every backup artifact embeds its own slots.

## 6. Legacy-client safety analysis (the migration keystone)

Verified against current `sync_service.dart`:

- `readLibraryEpochMarker` deliberately throws on unparseable content
  ("unreadable must be distinguishable from absent") and
  `LibraryEpochMarker.fromJson` throws `FormatException` without a plaintext
  `epochId`. `_runEpochGate` catches and fails the sync closed. This is the
  path every shipped client takes when it meets an encrypted marker. Safe.
- The path that had to be designed around: a readable (plaintext) marker
  whose epoch has no readable ssv1 library sends old clients into
  `_recoverUnreadableEpoch`, which after a 1-hour grace window wipes the
  cloud folder and republishes plaintext from local
  (`_reestablishEpochFromLocalLibrary`). Encrypting the epoch marker itself
  is therefore mandatory, not optional — it converts every legacy device to
  the fail-closed path above. The enable flow guarantees this by
  construction: the replace rewrites the marker through the decorator.
- A pre-epoch plaintext folder cannot linger: enable always runs a replace,
  which always writes an (encrypted) epoch marker.
- Regression pin: a unit test feeds an SBE1 envelope to
  `readLibraryEpochMarker` and asserts it throws (section 9).

## 7. Cloud backups

- When encryption is on, `BackupService._uploadToCloud` encrypts the local
  `.db` artifact file-to-file into the framed `.sbe` format (bounded
  memory), uploads that, and records it. Local artifacts (default sandbox
  dir, custom locations, SAF, pre-migration backups) remain plaintext `.db`:
  backups are the disaster-recovery path and must never be locked behind a
  passphrase; restoring plaintext backups keeps working regardless of
  encryption state.
- Restore: the restore flow (picker and cloud list) gains one step — `.sbe`
  extension or `SBE1` magic detected -> if a cached MLK matches the
  artifact's `libraryKeyId`, decrypt silently; else prompt (accepts
  passphrase or recovery code, tried against the embedded slots) -> decrypt
  to a temp `.db` -> existing restore machinery unchanged.
- Upload memory: the whole-file read in `_uploadToCloud` is pre-existing
  behavior; encryption does not worsen it (file-to-file crypto is streamed).
  Streaming backup upload is a noted follow-up, out of scope.
- Retention/pruning: unchanged; encrypted artifacts prune by the same
  records. Enable-time cleanup (checkbox) deletes existing plaintext cloud
  backups immediately.

## 8. Error handling

| Situation | Behavior |
| --- | --- |
| Wrong passphrase at unlock or restore | GCM unwrap fails -> inline "incorrect passphrase", retry; both slot types tried |
| Envelope present, no local key | `awaitingPassphrase` halt + banner (never an exception toast) |
| `libraryKeyId` mismatch | Same banner; copy explains the library was re-encrypted elsewhere |
| Auth-tag failure (corrupt/tampered file) | Surfaced like existing checksum failures: reader stops, cursor does not advance, retry next sync |
| Keyslot file missing from cloud | Keyed devices unaffected (they never re-read it); next publish self-heals it (same mirror pattern as the epoch marker); new devices cannot join until then |
| Enable interrupted mid-replace | Inherits the replace flow's existing `pendingReplace` resume |
| iCloud conflicted copy of the keyslot file | Filtered by the existing conflict-copy name check; keyslot writes are rare (enable/rewrap only) |
| Troubleshoot Sync screen (#521) | Gains an encryption status row and an "Enter passphrase" action |

## 9. Testing plan (TDD)

- Known-answer tests: Argon2id, HKDF, AES-256-GCM, single-shot envelope,
  framed envelope — vectors computed with python3 at implementation time.
- No-plaintext-leak invariant: full enable -> sync -> backup cycle against
  `FakeCloudStorageProvider`; assert every stored file except
  `submersion_keyslots.json` begins with `SBE1` and none contains a known
  plaintext marker string.
- Two-device convergence with encryption on: reuse the existing fake-cloud
  convergence harness wrapped in the decorator; include the join flow
  (B halts `awaitingPassphrase` -> unlock -> adopt -> converge).
- Legacy fail-closed pin: encrypted marker -> `readLibraryEpochMarker`
  throws -> gate halts.
- Decorator unit tests: passthrough when disabled, exemption list, AAD
  binding (rename a ciphertext -> auth failure), gzip flag round-trip,
  plaintext passthrough on missing magic.
- Keyslots: wrap/unwrap both slot types, wrong passphrase, slot rewrap
  preserves MLK, KDF parameter upgrade path.
- Backup: `.sbe` round-trip; wrong passphrase; recovery-code redeem;
  bit-flip tamper -> auth failure; truncated final frame -> error; fresh
  device restore with no sync configured; old-passphrase artifact restores
  with old passphrase.
- Lifecycle: enable / disable / change-passphrase / re-enable-with-new-key
  (`libraryKeyId` mismatch), enable-time plaintext-backup cleanup.
- Recovery code: generation entropy source, normalization (case,
  whitespace, hyphens), wordlist integrity (1296 entries).

## 10. UI surface

All new strings land in English plus the 10 non-English locales, then
`flutter gen-l10n` (standing project rule).

- Settings -> Cloud Sync -> "End-to-end encryption" section:
  - Enable: passphrase + confirm -> recovery code display + confirm-saved ->
    warnings (other devices must update and re-download; lost passphrase +
    code = cloud data unrecoverable, local data safe) -> optional delete of
    existing plaintext cloud backups (default on).
  - Change passphrase; View recovery code (re-auth with passphrase);
    Regenerate recovery code; Disable (confirmation, explains plaintext
    republish).
- Cloud Sync page + Troubleshoot Sync screen: `awaitingPassphrase` banner
  and action.
- Restore flow: passphrase/recovery prompt when an `.sbe` artifact is
  selected.

## 11. New components (one purpose each)

| Unit | Purpose |
| --- | --- |
| `lib/core/services/sync/crypto/sync_envelope.dart` | Single-shot SBE1 envelope encode/decode (pure; bytes in, bytes out) |
| `lib/core/services/sync/crypto/keyslots.dart` | Keyslot file model, wrap/unwrap, slot management, KDF params |
| `lib/core/services/sync/crypto/recovery_code.dart` | EFF-wordlist generation + normalization |
| `lib/core/services/sync/crypto/encryption_key_store.dart` | Secure-storage custody of MLK + libraryKeyId; enabled flag via SyncPreferences |
| `lib/core/services/cloud_storage/encrypting_cloud_storage_provider.dart` | The decorator (policy table, gzip, error typing) |
| `lib/features/backup/data/services/backup_crypto.dart` | Framed `.sbe` file-to-file encrypt/decrypt with embedded keyslots |
| Settings/sync UI additions | Enable/manage section, unlock banner, restore prompt |

Existing code touched (small, targeted): provider construction point (wrap),
`performSync` (catch -> `awaitingPassphrase`), `SyncResult`/status enum,
`BackupService` upload/restore seams, Troubleshoot screen, keyslot self-heal
in the publish path.

## 12. Dependencies and risks

- New packages: `cryptography` (+ `cryptography_flutter`). Verify
  maintenance/versions at implementation; pin per repo conventions. Fallback
  if unmaintained: `pointycastle` implementations behind the same seams.
- Pure-Dart crypto throughput on large bases is the main performance risk;
  mitigated by platform delegates, bounded 8 MiB units, and the
  measure-first rule before adding isolate offload.
- Argon2id memory parameter (64 MiB) on low-end Android devices: KDF runs
  only at enable/unlock/restore (interactive moments). If profiling shows
  problems, parameters are per-slot and can be tuned before release.
- User risk: passphrase loss. Mitigated by the recovery code, loud enable
  warnings, and the fact that local data is never encrypted at rest.

## 13. Non-goals (v1)

- Filename/metadata hiding (device counts, sizes, timing remain visible).
- Media-file encryption (media does not sync yet; HKDF leaves room).
- A key-rotation button (disable + enable covers it).
- Per-provider keys, encrypting local backups, biometric-gated unlock
  (the OS keystore already gates key access).
- Streaming cloud-backup upload (pre-existing whole-file behavior).

## 14. Rollout notes

- Release notes + GitHub wiki user-guide page (wiki is the user-doc source
  of truth): enabling requires updating all devices first; recovery-code
  guidance; what the provider can and cannot see.
- Respond on issue #520 with the design summary once the spec is approved
  (owner's call; the reporter offered to contribute).
