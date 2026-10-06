# Decouple App Lock from Database Encryption Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow database encryption to be enabled and remain enabled without automatically enabling App Lock.

**Architecture:** Keep the existing shared master key, password keyslot, recovery keyslot, and secure-storage cache. Separate credential creation from the `app_lock_enabled` preference, expose an explicit App Lock state transition, and make the settings UI handle all four App Lock/encryption combinations. When the last tier is disabled, remove the now-unused sidecar and cached key.

**Tech Stack:** Flutter, Dart, SharedPreferences, SQLCipher orchestration, Flutter widget tests

## Global Constraints

- Database Encryption remains at-rest encryption of `submersion.db`; App Lock remains a UI gate.
- Both tiers continue sharing one password, recovery code, master key, and keyslot sidecar.
- Encryption-only startup reads the cached master key silently and prompts only when that key is unavailable.
- Existing unrelated worktree changes must remain untouched.

---

### Task 1: Separate credential creation from App Lock state

**Files:**
- Modify: `lib/core/services/security/database_security_service.dart`
- Test: `test/core/services/security/database_security_service_test.dart`

**Interfaces:**
- Produces: `enableSecurity(...)` creates and caches credentials without changing `app_lock_enabled`.
- Produces: `setAppLockEnabled(bool enabled)` changes only the App Lock preference and requires an unlocked credential when enabling.
- Consumes: Existing `SecurityPreferences.setAppLockEnabled(bool)`.

- [x] **Step 1: Write failing service tests**

Change the existing setup test to assert that `enableSecurity(...)` writes the sidecar and caches the key while leaving App Lock off. Add a test that `setAppLockEnabled(true)` turns on App Lock after credential setup and that `setAppLockEnabled(false)` turns it off without deleting the sidecar or clearing the cached key.

```dart
test('enableSecurity creates credentials without enabling app lock', () async {
  await svc.enableSecurity(password: 'hunter2', dbPath: dbPath, kdf: testKdf);
  expect(svc.appLockEnabled, false);
  expect(svc.isUnlocked, true);
  expect(File('${tmp.path}/submersion.keys').existsSync(), true);
});

test('setAppLockEnabled changes only the UI gate', () async {
  await svc.enableSecurity(password: 'pw', dbPath: dbPath, kdf: testKdf);
  await svc.setAppLockEnabled(true);
  expect(svc.appLockEnabled, true);
  await svc.setAppLockEnabled(false);
  expect(svc.appLockEnabled, false);
  expect(svc.isUnlocked, true);
  expect(File('${tmp.path}/submersion.keys').existsSync(), true);
});
```

- [x] **Step 2: Run the service tests and verify RED**

Run: `flutter test test/core/services/security/database_security_service_test.dart`

Expected: the credential test reports App Lock is unexpectedly true and `setAppLockEnabled` is undefined.

- [x] **Step 3: Implement the explicit state transition**

Remove the App Lock preference write from `enableSecurity(...)` and add:

```dart
Future<void> setAppLockEnabled(bool enabled) async {
  if (enabled && _mlk == null) {
    throw StateError('Cannot enable App Lock without an unlocked credential');
  }
  await _p.setAppLockEnabled(enabled);
}
```

Update tests and non-UI setup call sites that specifically require App Lock to call `setAppLockEnabled(true)` explicitly.

- [x] **Step 4: Run the service and startup tests and verify GREEN**

Run: `flutter test test/core/services/security/database_security_service_test.dart test/core/presentation/pages/startup_lock_gate_test.dart`

Expected: PASS.

---

### Task 2: Support all four settings combinations

**Files:**
- Modify: `lib/features/settings/presentation/pages/security_settings_page.dart`
- Test: `test/features/settings/presentation/pages/security_settings_page_test.dart`

**Interfaces:**
- Consumes: `DatabaseSecurityService.setAppLockEnabled(bool)` from Task 1.
- Produces: encryption setup creates credentials without changing App Lock.
- Produces: disabling App Lock while encryption is active retains encryption credentials.
- Produces: disabling the final enabled tier removes unused security credentials.

- [x] **Step 1: Write failing widget tests**

Add tests proving:

```dart
testWidgets('encryption setup leaves app lock off', (tester) async {
  // Complete the password/recovery flow from the Encrypt database switch.
  // Assert appLockEnabled is false before confirming the migration.
});

testWidgets('encryption-only state renders the encryption switch on', (tester) async {
  await configure({'db_encryption_enabled': true});
  await pumpPage(tester);
  final encryptionSwitch = tester.widget<SwitchListTile>(
    find.widgetWithText(SwitchListTile, 'Encrypt database'),
  );
  expect(encryptionSwitch.value, true);
});

testWidgets('app lock can be turned off while encryption remains on', (tester) async {
  // Configure a real shared credential with both flags on, complete password
  // confirmation, then assert App Lock is false, encryption is true, and the
  // sidecar still exists.
});
```

- [x] **Step 2: Run the widget tests and verify RED**

Run: `flutter test test/features/settings/presentation/pages/security_settings_page_test.dart`

Expected: encryption setup enables App Lock, the encryption-only switch renders off, and disabling App Lock is blocked.

- [x] **Step 3: Implement independent settings transitions**

Refactor the page so:

- App Lock setup creates credentials if neither tier exists, then explicitly enables App Lock.
- Enabling App Lock while encryption is already active only calls `setAppLockEnabled(true)`.
- Encryption setup creates credentials but never calls `setAppLockEnabled(true)`.
- Password/recovery management is visible when either tier is active.
- Biometrics and auto-lock remain visible only while App Lock is active.
- The encryption switch always reflects `encryptionEnabled`.
- Disabling App Lock while encryption is active calls `setAppLockEnabled(false)` after password confirmation and retains the sidecar.
- Disabling encryption while App Lock is inactive decrypts first, then calls `disableSecurity(...)` to remove the unused credential.

- [x] **Step 4: Run the widget tests and verify GREEN**

Run: `flutter test test/features/settings/presentation/pages/security_settings_page_test.dart`

Expected: PASS.

---

### Task 3: Preserve reset cleanup and verify regressions

**Files:**
- Modify: `lib/core/services/security/database_security_service.dart`
- Test: existing security, startup, App Lock provider, lock barrier, and settings coverage

**Interfaces:**
- Consumes: `disableEncryption(...)` and `disableSecurity(...)`.
- Produces: database reset clears shared security credentials even when encryption was the only enabled tier.

- [x] **Step 1: Clean up credentials when encryption was the final tier**

After decryption succeeds and the encryption preference is cleared, remove the shared credential only when App Lock is already off. This keeps reset behavior safe without duplicating cleanup in the storage page:

```dart
await _p.setEncryptionEnabled(false);
await refreshKeyStatus(dbPath: dbPath);
if (!appLockEnabled) {
  await disableSecurity(dbPath: dbPath);
}
```

- [x] **Step 2: Format and run focused regression tests**

Run: `dart format lib/core/services/security/database_security_service.dart lib/features/settings/presentation/pages/security_settings_page.dart test/core/services/security/database_security_service_test.dart test/core/presentation/pages/startup_lock_gate_test.dart test/features/settings/presentation/pages/security_settings_page_test.dart`

Run: `flutter test test/core/services/security test/core/presentation/pages/startup_lock_gate_test.dart test/core/presentation/providers/app_lock_provider_test.dart test/core/presentation/widgets/lock_barrier_test.dart test/features/settings/presentation/pages/security_settings_page_test.dart`

Expected: PASS.

- [x] **Step 3: Run static analysis for changed Dart files**

Run: `flutter analyze lib/core/services/security/database_security_service.dart lib/features/settings/presentation/pages/security_settings_page.dart test/core/services/security/database_security_service_test.dart test/core/presentation/pages/startup_lock_gate_test.dart test/features/settings/presentation/pages/security_settings_page_test.dart`

Expected: no issues.

- [x] **Step 4: Review the final diff**

Run: `git diff --check` and `git diff -- lib/core/services/security/database_security_service.dart lib/features/settings/presentation/pages/security_settings_page.dart test/core/services/security/database_security_service_test.dart test/core/presentation/pages/startup_lock_gate_test.dart test/features/settings/presentation/pages/security_settings_page_test.dart docs/superpowers/plans/2026-08-11-decouple-app-lock-database-encryption.md`

Expected: no whitespace errors; only the planned behavior and tests are present.
