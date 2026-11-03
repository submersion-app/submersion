# Web App Plan 5: Restore and the Sample Logbook

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, in this session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The browser restores a backup file (plain or encrypted) and opens the sample logbook, from the same entry points as the desktop app.

**Architecture:** One new seam, `BackgroundDatabaseConnection.installImage`, creates a browser database from bytes through drift's `initializeDatabase`. Restore installs the image under a new name and repoints the browser at it only after it opens; the sample logbook installs as `submersion_demo`. The build ships the published sample package inside the bundle, since a page cannot read GitHub release files. Demo state and its preferences snapshot move behind the store, which keeps files on native and local storage in a browser.

**Tech Stack:** drift `WasmDatabase.open(initializeDatabase:)`, `package:cryptography` (Web Crypto AES-GCM in a browser), the compute worker's Argon2id job, `file_picker` with `withData`, Python 3 standard library for the build-time fetch, Playwright for the smoke run.

**Spec:** `docs/design/specs/2026-11-02-web-app-design.md`, section "Restore and the sample logbook" and decisions 14 to 17.

## Global Constraints

- Everything in Plan 1's Global Constraints.
- Native behaviour does not change. Every new branch is guarded by `HostPlatform.isWeb` or a conditional import, and the existing native tests pass unchanged except where a moved file access is now reached through the store.
- The live library is never deleted before its replacement opens.
- A newer-schema backup, a wrong passphrase and a non-SQLite file are refused before the safety copy downloads.
- New strings go in all 11 ARB files.

## Review Focus

1. A tab closed mid-restore. The preference flips only after the new database opens, so a relaunch opens the old library. Pinned by the browser test that installs, fails the open, and checks the pointer.
2. A backup taken from a WAL-mode database. The header's journal mode is set to rollback before install. Pinned by a VM test on the header and the browser install test using a WAL-flagged image.
3. A second tab still writing the old library after a restore or a demo switch. Both announce a reload on the site's channel. Pinned by the announcement test.
4. A build where the sample package cannot be fetched. The build fails unless `SUBMERSION_WEB_SAMPLE_LOGBOOK=0`, and a bundle without `demo/` hides sample mode. Pinned by the fetch script's tests and the client test for a missing index.
5. An older backup that needs the upgrade ladder in a browser. The smoke run restores the bundle's own sample database, which is several schema versions old.

---

### Task 1: Install a database image

- `lib/core/database/database_image_header.dart`: `isSqliteImage`, `sqliteImageUserVersion`, `withRollbackJournal` (a copy; bytes 18 and 19 become 1 when they are 2). VM test.
- `BackgroundDatabaseConnection.installImage(path, bytes)` (web: delete a stored copy, open with `initializeDatabase` and migrations off, check `sqlite_master`, close; native: unsupported). Browser test.

### Task 2: Restore in a browser

- The web library path is a preference (`web_library_database_path`), default `kWebDatabasePath`; `DatabaseLocationService` reads it.
- `DatabaseService.restoreImage(bytes)`: install under `submersion_<millis>`, reopen there, then write the preference; on a failed open reopen the previous path and delete the new one.
- A launch sweep deletes stored `submersion*` databases other than the active one, the local cache and the demo one, best effort.
- Forget deletes every stored database.
- `BackupCryptoImage`: decrypt SBE1 bytes with a key or a secret, sharing the frame rules with `BackupCrypto`. VM test against an artifact `BackupCrypto.encryptFile` wrote.
- `BackupService.restoreFromImage(bytes, mode, encryptionSecret, safetyCopy)`: decrypt, validate, safety copy, swap, re-baseline, arm the post-restore sync. VM tests with the fake adapter.
- `BackupOperationNotifier.restoreFromImage` and a browser safety copy (`readDatabaseImage` and `FileSaver`, skipped with no dives).

### Task 3: Restore entry points

- `DeviceCapabilities.web.backupRestore` true. The picker returns bytes on the web; the Backups page, the wizard restore step and Set up this device restore from them, with the passphrase retry.
- After a restore the other tabs reload.
- Widget tests with the web capabilities.

### Task 4: Ship the sample logbook

- `scripts/web/fetch_sample_logbook.py` with `_test.py`: newest package at or below `AppDatabase.currentSchemaVersion`, SHA-256 and size checked, only the database and `photos/` images unpacked, `demo/demo.json` written.
- `scripts/build_web.sh` runs it unless `SUBMERSION_WEB_SAMPLE_LOGBOOK=0`; `check_web_bundle.py` checks the index and its files when present.
- `HOSTING.md` says what `demo/` is.

### Task 5: Sample mode in a browser

- The demo client reads `demo/demo.json` from the site.
- `DemoStateStore` gains the snapshot, database and photo operations; native keeps files, the web keeps local storage.
- The browser installer fetches the database, checks its hash and installs it at the demo path.
- The preparer goes through the zlib seam and, given a photo URL base, turns sample photos into network links.
- Demo paths come from `AppDirectories`; the web bootstrap passes them; `DeviceCapabilities.web.demoMode` true.
- Entering and leaving reload the other tabs.

### Task 6: Proof in browsers

- Browser tests for the install, the restore pointer and the web demo store.
- The smoke run enters the sample logbook in each browser, and restores the bundle's sample database as a backup file.

### Task 7: Documentation

- `docs/developer/web.md`, `docs/user/web-app.md`, the rulings record and the PR body.
