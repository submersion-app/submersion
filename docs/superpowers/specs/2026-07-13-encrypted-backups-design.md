# Encrypted Backups (app-wide, password-protected)

- Issue: https://github.com/submersion-app/submersion/issues/580
- Date: 2026-07-13
- Status: Design approved; ready for implementation planning
- Worktree: `.claude/worktrees/issue-580-encrypted-backup` (branch `worktree-issue-580-encrypted-backup`, base `main`)

## Summary

Add an optional, app-wide **backup encryption** feature: the user sets a password
once in Settings, and from then on **every user-facing backup the app writes** — the
scheduled local auto-backups, manual *Save to File* and *Share* exports, and cloud
backups — is encrypted with that password. Restoring an encrypted backup requires
the password (or a recovery code). A recovery code is always generated at setup so
a forgotten password does not mean permanent data loss.

**Out of scope:** the pre-migration safety snapshot (`PreMigrationBackupService`)
stays a plaintext `.db`. It is written by the migration path *before* providers,
secure storage, and the encryption key are initialized (the key may not be
loadable at that point), it never leaves the device, and it is pruned after a
successful upgrade. Encrypting it would risk making the DB-upgrade safety net
itself fail-closed. This backup is deliberately excluded from the guarantee above.

**Password changes and cross-device restore (by design).** Each `.sbe` embeds
its own keyslots at write time and is self-decrypting — there is no cross-device
key coordination (that is the simplification that keeps the feature local-only
and offline). Consequences the UI must be honest about:

- On the **same device**, the master key is retained in secure storage, so every
  backup restores silently regardless of later password changes.
- On **another device**, a backup restores with the password *in effect when it
  was written*. Changing the password does not re-key already-written backups, so
  a new password opens only backups created after the change; older ones need
  their original password.
- The **recovery code is universal** across password changes (it unwraps every
  backup on any device) *until* the user regenerates it; regeneration only affects
  backups written afterward. The change-password dialog surfaces this
  (`settings_backupEncryption_changePasswordWarn`).
- **Re-enabling after Turn-off** reuses the retained key (Turn-off only flips the
  prefs flag; the key/mirror stay), so pre-existing backups keep restoring
  silently on-device instead of being stranded behind a freshly minted key.

This reuses the encrypted-artifact format and crypto primitives already merged in
#520 (encrypted cloud sync), but is a **separate, independent feature** with its own
key, its own password, and its own recovery code. #520's sync-encryption service is
not refactored.

## Motivation

#520 shipped end-to-end encryption for cloud *sync*. As a side effect, backups that
are *uploaded to the cloud while sync-encryption is enabled* become encrypted `.sbe`
artifacts. But:

- Manual **Save to File** and **Share** always produce plaintext `.db`.
- **Local scheduled auto-backups are always plaintext** by design.
- There is no way to password-protect a backup without enabling the entire
  encrypted-*sync* apparatus.

A diver who wants to protect an exported backup (emailing it, putting it on a USB
stick, manually uploading to their own cloud) or who simply wants their on-device
backup history encrypted has no option today. #580 fills that gap.

## Decisions (locked with issue author)

1. **Scope: encrypt all backups app-wide.** One password set once in Settings
   protects every backup artifact the app writes — local auto-backups, manual
   Save-to-File, Share, and cloud uploads.
2. **Recovery: always generate a recovery code** at setup (EFF short-wordlist,
   behind a "confirm you saved it" gate) — same robustness as sync encryption.
3. **Key model: separate backup password.** A distinct backup master key +
   passphrase keyslot + recovery keyslot, stored in secure storage under keys
   distinct from the sync store, gated by its own preferences flag. Parallel to,
   and independent of, #520's `SyncEncryptionService`, which is **not** modified.
   Accepted trade-off: a user who runs *both* encrypted sync and encrypted backups
   maintains two passwords / two recovery codes.
4. **Existing plaintext backups on enable:** offer **Re-encrypt existing backups
   in-place** or **Not now**. (No "delete plaintext backups" option.)
5. **Artifact extension stays `.sbe`; internal magic stays `SBE1`.** No rename. The
   only filename change is that encrypted exports use `.sbe` instead of `.db`.

## Goals / Non-goals

**Goals**
- Optional, off-by-default backup encryption controlled by one password.
- Every backup write path emits an encrypted `.sbe` when enabled.
- Silent restore when the key is present on-device; password/recovery prompt on a
  fresh device.
- A recovery code as a fallback to a forgotten password.
- One-time, idempotent, best-effort re-encryption of existing plaintext backups.

**Non-goals**
- No refactor of #520's sync-encryption service or its cloud-storage decorator
  beyond leaving them functionally intact.
- No unification of the backup password with the sync passphrase.
- No new recovery-code *viewing* ("view recovery code" remains impossible by
  design — regenerate-only, matching #520).
- No database schema change and no schema-version-ladder impact.

## Architecture

### Reused as-is (no edits)

The security-critical primitives are already generic and shared:

- `lib/features/backup/data/services/backup_crypto.dart` — framed `.sbe`
  encrypt/decrypt (`encryptFile`, `decryptFile(secret:)`, `decryptFileWithKey`,
  `isEncryptedBackup`, `libraryKeyIdOf`).
- `lib/core/services/sync/crypto/keyslots.dart` — `Keyslots.createSlot`,
  `tryUnwrap`, `deriveDataKey`, `KeyslotFile`, `Keyslot`, `KdfParams`.
- `lib/core/services/sync/crypto/recovery_code.dart` — EFF recovery code
  generate + `normalize`.
- `lib/core/services/sync/crypto/sync_envelope.dart` — `SBE1` magic + detection.
- `lib/core/services/sync/crypto/crypto_errors.dart` — `WrongPassphraseException`,
  `EnvelopeCorruptException`, `SyncEncryptionRequired`.
- `FallbackSecureStorage` — keychain with the `-34018`/no-sandbox fallback.

### New components (in `lib/features/backup/`)

| Component | Path (new) | Responsibility |
|---|---|---|
| `BackupEncryptionKeyStore` | `data/services/backup_encryption_key_store.dart` | Persist the backup **master key (MLK)** + keyslot-file mirror bytes in `FallbackSecureStorage` under keys distinct from the sync store (e.g. `backup_encryption_mlk`, `backup_encryption_keyslots`). `loadKey()` returns `({SecretKey mlk, String libraryKeyId})`, mirroring the sync `EncryptionKeyStore` so restore can treat both symmetrically. Also exposes the keyslot mirror bytes for embedding. |
| `BackupEncryptionService` | `data/services/backup_encryption_service.dart` | Key lifecycle (as shipped): `enable(passphrase)` → generate random MLK + `libraryKeyId`, build passphrase and recovery keyslots, persist, return the recovery code; `changePassphrase(currentSecret,newPassphrase)`; `regenerateRecoveryCode(currentSecret)`. No `unlock`/`disable`/`selfHealMirror` were needed: the MLK lives unwrapped in secure storage (local-only) so there is no locked state, and each `.sbe` embeds its own keyslots so there is no cloud mirror to self-heal. Fully independent of `SyncEncryptionService`. |
| Providers | `presentation/providers/backup_providers.dart` | Wired into the existing backup providers (no separate `backup_encryption_providers.dart` / notifier): `backupEncryptionKeyStoreProvider` and `backupEncryptionServiceProvider`. The key store is read synchronously (unwrapped MLK in secure storage), so no `ensureLoaded()` launch-race gate is needed. |
| `backupEncryptionEnabled` flag | in `data/repositories/backup_preferences.dart` / `domain/entities/backup_settings.dart` | Boolean preference. Off by default. No DB. |
| `BackupEncryptionSection` widget | `presentation/widgets/backup_encryption_section.dart` | The Settings UI. Two states only (Off / On) — there is no locked state because the MLK is always available locally. |
| Re-encrypt migration | method on `BackupService` (e.g. `reencryptExistingBackups()`) | Idempotent batch that rewrites plaintext history + cloud backups as `.sbe`. |

### Edited (within the backup feature only; #520 untouched)

- `lib/features/backup/data/services/backup_service.dart`
  - Gains the `BackupEncryptionKeyStore` (and access to the active MLK) as an
    optional dependency, symmetric with the existing `_encryptionKeyStore`.
  - Four encrypt-on-write injection points (below).
  - `_materializeForRestore` gains one branch: try the stored **backup** key by
    key-ID before prompting.
- `lib/features/backup/presentation/providers/backup_providers.dart` — wire the new
  key store / service into `backupServiceProvider`.
- `lib/features/backup/presentation/pages/backup_settings_page.dart` — mount
  `BackupEncryptionSection`; encrypted default export filename + FilePicker
  `allowedExtensions` gain `sbe`; post-enable cleanup dialog.
- `lib/l10n/*` — new keys in EN + all 10 non-en locales, regenerated.

**No change** to `encrypting_cloud_storage_provider.dart` (its
`submersion_backup_*` + `.sbe` exemption already covers our artifacts), to
`sync_encryption_service.dart`, or to `encryption_key_store.dart`.

## Data flows

### Enable (once, foreground, in Settings)

Two-phase dialog mirroring #520's enable flow:

1. Enter password + confirm. Then `BackupEncryptionService.enable(passphrase)`:
   - Generate a random 32-byte MLK and a random `libraryKeyId` (UUID).
   - `Keyslots.createSlot(type: 'passphrase', secret: passphrase, mlk)`.
   - `RecoveryCode.generate()` → `Keyslots.createSlot(type: 'recovery',
     secret: <recovery>, mlk)`.
   - Build `KeyslotFile(version, libraryKeyId, slots: [passphrase, recovery])`.
   - Persist MLK + keyslot mirror bytes to `BackupEncryptionKeyStore`.
   - Set `backupEncryptionEnabled = true`; return the recovery code.
2. Reveal the recovery code behind an "I've saved it" gate.

Argon2id (64 MiB, t=3) runs **twice here** (once per slot) — a few seconds, once.
This is the only place the heavy KDF runs on the write side.

### Encrypt-on-write

With the MLK loaded from the key store, each write path emits `.sbe` when the flag
is on. All are fast (HKDF data-key derivation + AES-256-GCM frame streaming; no KDF):

| Path | Method (BackupService) | Change |
|---|---|---|
| Local auto + manual "Backup now" | `_performBackupInto` (L149) | After the plaintext snapshot, if enabled, encrypt to `.sbe`, store the `.sbe` in history, drop the plaintext temp. Serves both scheduled `performBackup(isAutomatic:true)` and manual. |
| Cloud upload | `_uploadToCloud` (L893) | **If the local file is already encrypted (`isEncryptedBackup`), upload as-is** (decorator exempts it). Else keep existing #520 behavior: encrypt under the sync key when sync-encryption is on, else plaintext. |
| Save to File | `exportBackupToPath` (L216) | If enabled, encrypt to the chosen destination; filename `.sbe`. |
| Share | `exportBackupToTemp` (L251) | If enabled, encrypt the temp file; share the `.sbe`. |

**Cloud precedence rule** (backup-encryption wins for backup artifacts): because
`_performBackupInto` encrypts the local file first when backup-encryption is on,
`_uploadToCloud` sees an already-encrypted `.sbe` and passes it through. When
backup-encryption is off but sync-encryption is on, the local file is plaintext and
`_uploadToCloud` encrypts the cloud copy under the sync key exactly as today. No
double encryption; no #520 behavior regression.

### Restore

`_materializeForRestore` (L956) gains one branch (try the stored backup key by
key-ID before prompting):

```
artifactKeyId = BackupCrypto.libraryKeyIdOf(sourcePath)
if syncKey?.libraryKeyId   == artifactKeyId -> decryptFileWithKey(syncKey)   // #520, unchanged
else if backupKey?.libraryKeyId == artifactKeyId -> decryptFileWithKey(backupKey)  // NEW: silent
else if encryptionSecret != null -> decryptFile(secret)   // password OR recovery code
else throw BackupEncryptedException()                     // UI prompts, retries with secret
```

Already built and reused unchanged:
- The UI catch of `BackupEncryptedException` →
  `showEncryptionPassphraseDialog` → retry with `encryptionSecret`
  (`backup_settings_page.dart`), covering fresh-device restore (no stored key).
- `BackupCrypto.decryptFile(secret:)` tries every embedded keyslot and applies
  `RecoveryCode.normalize` to recovery entry, so the same prompt accepts either the
  password or the recovery code.
- `validateBackupFile` (L278) already admits `.sbe`.

### Post-enable cleanup (Re-encrypt / Not now)

Immediately after a successful enable, a dialog offers:

- **Re-encrypt existing backups in-place** — `reencryptExistingBackups()`:
  iterate the backup history; **skip** anything already encrypted
  (`BackupCrypto.isEncryptedBackup` / `.sbe`); for each plaintext file, encrypt to
  a temp then atomically replace, and update the history record's filename + size.
  For cloud copies: upload the new `.sbe`, then delete the old plaintext object.
  Best-effort per file (continue on error; report a summary). **Idempotent**:
  because `.sbe` self-identifies via the `SBE1` magic, a re-run distinguishes
  done-from-todo with no external progress bookkeeping, so an interrupted run is
  safe to resume.
- **Not now** — leave existing plaintext backups; they roll off naturally as new
  encrypted auto-backups accumulate.

### Disable

Clears the session key + the `backupEncryptionEnabled` flag. **Keeps the stored key**
so older encrypted backups still restore silently. New backups become plaintext.
(Matches #520's disable semantics: disable reverts new writes to plaintext but
retains the key for old artifacts.)

## Key management details

- **Master key (MLK):** random 32 bytes, generated at enable, never derived from
  the password. Wrapped by two keyslots (passphrase, recovery).
- **KDF:** default `KdfParams` (Argon2id, m=65536 KiB = 64 MiB, t=3, p=1), same as
  #520. Runs only at enable / change / regenerate / unlock / password-restore —
  never per backup.
- **Data key:** `Keyslots.deriveDataKey(mlk)` (HKDF-SHA256, info `sbe:v1:data`),
  identical to the existing backup/sync artifacts.
- **Secure storage keys:** distinct from the sync store to avoid collision (e.g.
  `backup_encryption_mlk`, `backup_encryption_keyslots`). The keyslot mirror is
  stored because the passphrase is never retained; `selfHealMirror()` re-persists
  it if missing.
- **Embedded keyslots:** every `.sbe` embeds its own `KeyslotFile`, so an artifact is
  self-decrypting with just the password or recovery code on any device.

## UI surface

In `backup_settings_page.dart`, a new **Backup encryption** section. Unlike #520's
`EncryptionSettingsSection` it has **only two states** — the MLK lives unwrapped in
secure storage (local-only), so there is never a "locked" state to unlock:

- **Off** → *Enable* (two-phase dialog: password + confirm → recovery-code reveal
  behind "I've saved it" gate) → post-enable cleanup dialog.
- **On** → *Change password*, *Regenerate recovery code*, *Turn off*.

Reuses `showEncryptionPassphraseDialog` and the recovery-confirm gate. Export bottom
sheet: default filename `submersion_backup_YYYY-MM-DD.sbe` when enabled; FilePicker
`allowedExtensions` include `sbe`; import continues to accept `db`/`sqlite`/`sbe`.

## Localization

New keys for the section title/subtitle, enable/unlock/change/regenerate/disable
dialogs, recovery-code copy, post-enable cleanup dialog, and error/snackbar strings.
Added to EN and all 10 non-en locales, then regenerated (whole-locale rule).

## Testing

- **Crypto KATs already cover the bytes** — `.sbe` is produced by the same
  `BackupCrypto`/`Keyslots` that #520's `test/fixtures/crypto/crypto_vectors.json`
  pins. No new vectors.
- **Service:** `BackupEncryptionService` enable/unlock/disable/change/regenerate;
  wrong password → `WrongPassphraseException`; recovery-code unlock; self-heal mirror.
- **Round-trip per write path:** export, share, auto-backup, cloud → restore silently
  with a stored key, and via password/recovery against a fresh
  `BackupEncryptionKeyStore` (simulating another device).
- **Cloud precedence:** backup-encryption on → cloud object is the pass-through
  `.sbe`; backup-encryption off + sync-encryption on → unchanged #520 behavior (no
  double encryption).
- **Re-encrypt migration:** idempotency (skips `.sbe`), partial-failure continues,
  history records updated (filename/size), cloud old-object deletion.
- **Restore precedence:** silent via backup key; falls through to prompt when key
  absent; recovery code accepted at the prompt.
- **Widget:** section two states (Off / On), enable + recovery gate, post-enable dialog,
  restore prompt. Reuse #520 widget-test gotchas: mock `PackageInfo`, override
  `syncRepositoryProvider` + SharedPreferences, and fake the service to avoid running
  64 MiB Argon2id through the UI (the real service is covered by service +
  round-trip tests).

## Edge cases & risks

- **Both features on (sync + backup encryption):** two keys, two passwords. Each
  artifact self-identifies by `libraryKeyId`, so restore silently picks the right
  stored key; cross-device restore prompts. Cloud precedence rule prevents double
  encryption.
- **Legacy `.sbe` from #520:** still validates and restores (magic-based detection;
  extension unchanged).
- **Forgotten password + lost recovery code:** unrecoverable by design; surfaced
  with a stern warning at enable and at the recovery-code gate.
- **Re-encrypt interrupted:** safe; idempotent re-run resumes.
- **Background auto-backup:** the key store holds the MLK unwrapped-at-rest in secure
  storage (no password needed at backup time), so background/scheduled backups encrypt
  without a prompt. There is no "locked" state to wait on — the mobile scheduled path
  injects `BackupEncryptionKeyStore()` so it can read the key directly.

## Out of scope / future

- Unifying backup + sync passwords into a single app encryption identity.
- Re-encrypting under a *changed* password (change-password rewraps the keyslots but
  does not rewrite existing artifacts; old artifacts still open with the old password
  via their embedded slots — acceptable, and matches #520).
- Per-export ad-hoc passwords (distinct from the app-wide setting).

## File-by-file change list (for planning)

**New**
- `lib/features/backup/data/services/backup_encryption_key_store.dart`
- `lib/features/backup/data/services/backup_encryption_service.dart`
- `lib/features/backup/presentation/providers/backup_encryption_providers.dart`
- `lib/features/backup/presentation/widgets/backup_encryption_section.dart`
- Tests mirroring the above + round-trip/migration/widget suites.

**Edited**
- `lib/features/backup/data/services/backup_service.dart` (4 write injections +
  restore branch + `reencryptExistingBackups()`)
- `lib/features/backup/data/repositories/backup_preferences.dart` +
  `lib/features/backup/domain/entities/backup_settings.dart` (flag)
- `lib/features/backup/presentation/providers/backup_providers.dart` (wiring)
- `lib/features/backup/presentation/pages/backup_settings_page.dart` (section,
  filename/extension, cleanup dialog)
- `lib/features/backup/presentation/widgets/export_bottom_sheet.dart` (only if the
  subtitle needs an "(encrypted)" hint; otherwise unchanged)
- `lib/l10n/app_en.arb` + 10 locales

**Not touched (verification only)**
- `lib/core/services/cloud_storage/encrypting_cloud_storage_provider.dart`
- `lib/core/services/sync/crypto/sync_encryption_service.dart`
- `lib/core/services/sync/crypto/encryption_key_store.dart`
