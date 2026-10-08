# Database Password Protection - Design

Date: 2026-08-06
Status: Approved design, pending implementation plan
Worktree: `worktree-db-password-protection`

## Overview

Add a two-tier security model to Submersion:

1. **App Lock** - a password/biometric gate shown at app launch and after a
   configurable background timeout. Works standalone against a plaintext
   database.
2. **Database Encryption** - at-rest encryption of the main database
   (`submersion.db`) using SQLCipher, so the file on disk is unreadable
   without the key.

The two tiers compose freely and share a single credential (one app password,
one recovery code). When the user cannot unlock the current database, the
lock screen offers an escape hatch: recovery-code unlock, or setting the
locked database aside and starting fresh (with restore-from-backup available
through the existing first-run wizard).

## Goals

- Real at-rest encryption of the main database, opt-in, per device.
- Password or biometric unlock at launch; re-lock after background timeout.
- Single shared credential for both tiers, with a recovery code.
- Escape hatch when the password is unknown: recovery code, or set-aside +
  start fresh + restore from backup.
- Zero performance or behavior change for users who enable neither tier.
- Backups remain portable plaintext SQLite artifacts regardless of DB
  encryption state.

## Non-Goals

- Encrypting the local cache database (`submersion_local.db` - derivable
  public map/reef data).
- Encrypting media files (photos/videos) at rest. Possible later phase.
- Multi-database/profile switching. The escape hatch sets the old DB aside;
  it does not add general database browsing.
- Protection against an attacker with full control of the unlocked OS user
  account (see Threat Model).
- Lockout counters or wipe-after-N-failed-attempts.

## Threat Model (honest statement)

After first unlock, the Master Key is cached in the OS keychain/keystore via
`flutter_secure_storage` so that biometric unlock and headless background
tasks (Workmanager scheduled backups) keep working.

Protects against:
- Reading `submersion.db` off disk, from filesystem backups, or from another
  app/user account.
- Device theft where the OS user account is locked.

Does not protect against:
- An attacker running code inside the user's unlocked OS session with
  keychain access.
- The macOS no-sandbox (Developer ID) build stores the cached key in a file
  via `FallbackSecureStorage` - same limitation as existing backup/sync keys
  on that build.

App Lock alone is a UI gate only; it does not encrypt anything.

## Architecture

### Engine: SQLCipher via `sqlcipher_flutter_libs`

Replace `sqlite3_flutter_libs: ^0.5.42` with `sqlcipher_flutter_libs` in
pubspec. Same maintainer as drift, same `sqlite3` Dart API, supported on all
five platforms. The packages cannot coexist (same native symbols), so this
is a clean swap.

- Unencrypted databases open at full speed with no key - SQLCipher's codec
  only engages when `PRAGMA key` is set. Users who never enable encryption
  pay only app-size cost (~1-3 MB/platform).
- Side effect: retires the EOL'd `sqlite3_flutter_libs` pin (issue #433).

Platform hazards with explicit verification steps in the plan:

1. **Android**: `open.overrideFor(OperatingSystem.android, openCipherOnAndroid)`
   must run before any open, in **every isolate** that opens the DB -
   `open` overrides are per-isolate state, so the drift background isolate
   entrypoint applies it too.
2. **iOS/macOS symbol collision**: another plugin linking system SQLite
   (candidate: photo_manager) can cause the dynamic linker to resolve
   `sqlite3_open` to the non-cipher library. Mitigation: pod dependency
   audit + runtime assertion that `PRAGMA cipher_version` returns non-empty
   at startup (debug and release), so a bad link fails loudly.
3. **Compile-option parity**: confirm the SQLCipher build enables the same
   SQLite compile-time features the app relies on (FTS, JSON1, etc.) before
   any code depends on the swap.

### Key architecture

Reuses the keyslot design already shipped for encrypted backups and
encrypted sync (`lib/core/services/sync/crypto/keyslots.dart`):

- Enabling security mints a random 32-byte **Master Key**.
- The Master Key is wrapped AES-256-GCM under KEKs derived with **Argon2id**
  (m=64 MiB, t=3, p=1 - same params as backups) into two keyslots:
  `passphrase` (the app password) and `recovery` (recovery code, shown once
  at setup using the existing recovery-code UX).
- Keyslots live in a **sidecar file next to the database**
  (`submersion.keys`, JSON) - readable before any DB open, and it travels
  with the DB in set-aside, storage-move, and safety-copy scenarios, like a
  LUKS header.
- The SQLCipher key is `HKDF-SHA256(MasterKey, info: 'sdb:v1:dbkey')`
  (pure-Dart `DartHkdf`, per the Android empty-HMAC-key issue #737), passed
  as a raw hex key: `PRAGMA key = "x'<64 hex chars>'"`. Raw-key mode skips
  SQLCipher's internal PBKDF2, keeping opens fast; password changes rewrap
  one small file instead of re-encrypting the database.
- After first unlock the Master Key is cached in `flutter_secure_storage`
  (through the existing `FallbackSecureStorage`), keys:
  `db_security_key_id`, `db_security_mlk`. Biometric unlock = `local_auth`
  success, then read the cached key. Password unlock = Argon2id unwrap from
  the sidecar (new device, keychain wipe, biometric failure/unavailable).
- **App Lock without encryption verifies the password the same way** -
  successful unwrap of the Master Key is the proof. No separate
  password-hash path exists, and enabling encryption later reuses the
  already-established credential.

### New components

- `DatabaseSecurityService` (`lib/core/services/security/`) - owns security
  state (which tiers are enabled), the unlocked Master Key, derived DB key,
  keyslot sidecar read/write, enable/disable/change-password operations,
  and the encrypt-in-place/decrypt-in-place migrations.
- `DatabaseSecurityKeyStore` - secure-storage wrapper, same shape as
  `BackupEncryptionKeyStore`.
- Lock screen + unlock overlay widgets, settings section
  (`lib/features/security/`), escape-hatch dialogs.
- `local_auth` (+ platform packages) for biometrics: iOS, Android, macOS,
  Windows; Linux is password-only. iOS needs `NSFaceIDUsageDescription`.
- Settings storage: SharedPreferences flags (`app_lock_enabled`,
  `db_encryption_enabled`, `app_lock_timeout_minutes`,
  `app_lock_biometrics_enabled`).

### Key path through database opens

One key source threaded to every open of the main DB:

1. `DatabaseService._openDatabase()` - both the main-isolate migration open
   and the normal background-connection path pass a `setup:` callback to
   `NativeDatabase` that issues `PRAGMA key` as the first statement.
2. `BackgroundDatabaseConnection._openerFor` - the key hex rides across the
   isolate boundary as a `String` alongside the path; the worker entrypoint
   applies the Android `open` override and the pragma in its own isolate.
3. The ~6 raw `sqlite3.open()` call sites (schema-version probe at
   `database_service.dart:323`, hot-journal recovery `:346`, migration
   `quick_check` and DB counts in `database_migration_service.dart`, backup
   validation in `backup_service.dart:586`, startup probe via
   `startup_page.dart:189`) are consolidated behind one helper,
   `openRawDatabase(path, {key})`, so no future call site can forget the
   key.

The local cache DB keeps its plain open path unchanged.

### Encryption-state detection

Prefs flag and sidecar say what should be true; the file header is the
truth. A plaintext SQLite file begins `SQLite format 3\0`; an encrypted one
looks random. The open path cross-checks header vs. flag so that an
interrupted enable/disable or restored old prefs produces a precise typed
error, and startup self-heals to the state the file is actually in.

## Unlock Flow

### Cold start

The gate is a new state in `StartupWrapper` (`startup_page.dart`), before
`DatabaseService.instance.initialize()` runs. The splash layer is already a
standalone `MaterialApp`, so the lock screen needs no router involvement and
the DB stays unopened until unlock succeeds.

- **App Lock on**: lock screen appears. If biometrics are enrolled and the
  setting is on, the biometric prompt fires immediately; a password field is
  always available. Success reads the cached Master Key and startup
  proceeds.
- **Encryption on, App Lock off**: no prompt; the key is read silently from
  the keychain. Only if the cached key is missing (new device, keychain
  wipe) does a password prompt appear - the DB is physically unopenable
  without it.
- **Both off**: startup unchanged.

### Re-lock (App Lock only)

Uses the existing `didChangeAppLifecycleState` hook in `app.dart`. On
background, record a timestamp; on resume past the configured timeout
(immediately / 1 min / 5 min / 15 min / never), show a full-screen lock
overlay. The database stays open behind it - no service teardown, no
provider invalidation, no sync interruption. Biometric or password
dismisses.

### Failed attempts

No lockout or wipe. Argon2id at 64 MiB already rate-limits on-device
guessing. Wrong password shows an inline error; the DB is never attempted.

### Escape hatch ("I can't unlock this database")

Lock screen offers, in order:

1. **Use recovery code** - unwraps the Master Key from the recovery slot,
   then forces setting a new password (rewrap only; DB untouched).
2. **Start fresh** - after typed confirmation:
   - Database + keyslot sidecar + WAL/SHM set aside as
     `submersion.db.locked-<timestamp>` (never deleted).
   - Security settings cleared; cached keys removed.
   - Cloud-sync configuration disabled (same as the existing Reset flow) so
     the new database cannot cross-contaminate the old sync library.
   - App boots into the existing first-run wizard, which already offers
     restore from backup.

## Lifecycle Flows

### Enable security (first time)

Set password -> mint Master Key -> write sidecar -> cache key -> show
recovery code once (reusing backup-encryption widget patterns). App Lock
alone stops here; no database change.

### Enable encryption (existing plaintext DB)

1. Automatic safety backup (timestamped, `pre_encrypt_*`, like the existing
   `pre_reset_*` pattern).
2. Strict close -> encrypt-in-place: open plaintext raw, `ATTACH` encrypted
   target with key, `SELECT sqlcipher_export(...)`, carry over
   `user_version`, swap via the same rename dance the restore flow uses
   (WAL/SHM deleted, original set aside until verified).
3. Reopen keyed, `SELECT 1` + `PRAGMA cipher_version` verify, discard the
   set-aside plaintext.

A blocking progress UI (`RestoreBarrier` pattern) covers the export, which
scales with DB size. **Disable encryption** is the identical dance in
reverse (plaintext target, `KEY ''`). Interruption at any point is
recoverable: the swap is atomic-rename based and the header probe tells
startup which state the file actually landed in.

### Change password / regenerate recovery code

Rewrap one keyslot - instant, no DB touch. Mirrors
`BackupEncryptionService.changePassphrase()`.

### Disable all security

Decrypt-in-place if encrypted, then delete sidecar, cached keys, and prefs
flags.

## Feature Interactions

- **Backups stay portable - hard rule.** A backup artifact remains a
  plaintext SQLite file, optionally wrapped in SBE1 by the existing,
  fully-orthogonal backup-encryption feature. When the live DB is
  encrypted, backup creation decrypt-exports to a temp file and feeds the
  existing pipeline. Rationale: a backup must be restorable on a new device
  where the DB password may be unknown; coupling backup readability to the
  DB key would break every recovery story.
- **Restore** (plaintext backup arriving, encryption enabled): existing
  swap runs, then encrypt-in-place executes before reopen. Pre-restore
  safety copies are raw copies of the encrypted file; they stay encrypted
  and the sidecar travels with them.
- **Sync / divelogs.de / media**: operate through the open connection or on
  their own files - no changes. Encrypted sync remains a separate feature
  with separate keys.
- **Storage relocation** (custom folder moves in
  `database_migration_service.dart`): the sidecar moves with the DB.
- **Headless background tasks** (`background_service.dart` Workmanager
  callback): read the cached key from secure storage; if absent, log and
  skip the task gracefully - never prompt, never corrupt.
- **Reset database**: also clears security state (with confirmation) since
  the encrypted file it protected is gone.

## Error Handling

Every lock state has exactly one typed exit:

| Condition | Behavior |
|---|---|
| Wrong password | Inline error on unlock screen (Argon2id unwrap failed; DB never attempted) |
| Encrypted file, no key available | `DatabaseLockedException` -> unlock screen (never the generic startup-error state) |
| Keychain lost (new device/OS restore) | Password prompt rebuilds cache from sidecar; recovery code if password forgotten |
| Sidecar lost, keychain intact | DB opens with cached key; app detects missing sidecar and asks the user to confirm their password once to rebuild it (self-heal) |
| Sidecar and keychain both lost | Honestly unrecoverable; escape hatch (set aside + start fresh/restore) |
| Interrupted enable/disable | Header probe decides actual state; set-aside file retained until verify |
| Biometric failure/unavailable | Password fallback, always present |

Known limitation (documented in-app where relevant): the macOS no-sandbox
build's file-based keychain fallback stores the cached key on disk,
weakening the at-rest story on that one build - identical to existing
backup/sync key behavior there.

## Testing

- **Unit (run everywhere, pure Dart)**: keyslot wrap/unwrap and HKDF
  derivation against precomputed test vectors (computed independently, per
  project practice), header-probe logic, security-state machine,
  escape-hatch set-aside naming, key-hex pragma formatting.
- **Host-test constraint**: `flutter test` on the host loads the system
  libsqlite3 (no plugin registration), which cannot open encrypted files.
  Encrypted open/export round-trips, background-isolate keyed opens, and
  enable -> relaunch -> unlock flows live in `integration_test`.
- **Startup smoke assertion**: `PRAGMA cipher_version` non-empty, so a
  mis-linked native binary fails immediately on every platform in CI.
- **Widget tests**: lock screen, unlock overlay, settings section,
  escape-hatch dialogs, with a mocked `DatabaseSecurityService`. Known
  traps: new provider dependencies break existing consumer tests; new
  strings need all 10 non-English locales + l10n regen.
- **Full suite + all-platform CI builds** before merge - the native-lib
  swap touches every platform build.

## Risks (ranked)

1. iOS/macOS sqlite symbol collision - pod audit + runtime cipher_version
   assertion.
2. SQLite compile-option parity in the SQLCipher build - verify first.
3. App size +1-3 MB per platform (all users).
4. Encrypted-DB overhead ~5-15%; zero for users who do not opt in.

Upside: retires the EOL'd `sqlite3_flutter_libs` pin.

## Decisions Log

- Scope: main DB only (cache DB and media excluded). 2026-08-05
- Lock policy: cold start + configurable background timeout. 2026-08-05
- Credential: independent from backup/sync passphrases; single shared
  password for both tiers. 2026-08-05/06
- Escape hatch: recovery code / start fresh + restore; no multi-database
  switcher. 2026-08-05
- Key caching: keychain-cached after first unlock (background tasks and
  biometrics keep working); threat model documented honestly. 2026-08-05
- Engine: SQLCipher raw-key mode via sqlcipher_flutter_libs (Approach A).
  2026-08-06
- App Lock offered standalone alongside encryption. 2026-08-06
