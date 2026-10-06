# Issue #652 Reset/Rebuild UX Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the four remaining user-facing items of issue #652 - the reset dialog understating its scope, the missing "replace cloud library from this device" action, an undiscoverable replace path at first contact, and skipped sync peers reported as a bare count.

**Architecture:** Three copies of "device identity for a marker" collapse into one `SyncDeviceMetadata` resolver, which then also feeds a new `deviceName` field on `SyncManifest`. A new `LibraryReplaceIntent` service mints the pending-replace marker so both `BackupService` and `SyncNotifier` can arm a replace; the existing `_runEpochGate` already executes it, so the new Settings action is mint-then-sync with no new protocol. Skipped peers reach the UI as structured state rendered by a localized banner, mirroring the existing newer-schema banner.

**Tech Stack:** Flutter 3.x, Riverpod, Drift, `flutter_test`, ARB localization via `flutter gen-l10n`.

## Global Constraints

- Work in the worktree `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/issue-652-reset-rebuild-ux` on branch `worktree-issue-652-reset-rebuild-ux`. Use absolute paths under that root for all Read/Edit/Write; prefix Bash commands with `cd "$WT" &&` because the shell cwd can silently revert to the main checkout between turns.
- Never loosen the library-epoch fence. `_runEpochGate` and `ChangesetReader`'s skip decision keep their current semantics; this work only collects names alongside them.
- Every new ARB key must be added to all 11 locale files (`app_en.arb` plus `ar, de, es, fr, he, hu, it, nl, pt, zh`). `test/l10n/arb_parity_test.dart` enforces this.
- No emojis in code, comments, or documentation.
- Run `dart format .` before every commit; the pre-push hook runs `dart format --set-exit-if-changed`, `flutter analyze`, and `flutter test`.
- Baseline at plan start: 903 tests pass in `test/core/services/sync` and `test/features/backup`.
- Spec: `docs/superpowers/specs/2026-08-11-652-reset-rebuild-ux-design.md`.

---

## File Structure

**Create:**
- `lib/core/services/sync/sync_device_metadata.dart` - resolves (id, name, appVersion) with sanitization
- `lib/core/services/sync/library_replace_intent.dart` - mints and persists the pending-replace marker
- `lib/features/settings/presentation/widgets/replace_cloud_library_dialog.dart` - type-to-confirm dialog plus the backup-then-replace call
- `test/core/services/sync/sync_device_metadata_test.dart`
- `test/core/services/sync/library_replace_intent_test.dart`
- `test/features/settings/presentation/widgets/replace_cloud_library_dialog_test.dart`
- `test/features/settings/presentation/skipped_peer_banner_test.dart`

**Modify:**
- `lib/features/backup/data/services/backup_service.dart` - `_mintPendingReplace` delegates
- `lib/features/settings/presentation/providers/sync_providers.dart` - `_deviceMetadata` delegates; new preflight + replace methods; `SyncState.skippedPeerLabels`
- `lib/core/services/sync/changeset_log/sync_manifest.dart` - `deviceName` field
- `lib/core/services/sync/changeset_log/changeset_writer.dart` - `deviceName` param, 4 construction sites
- `lib/core/services/sync/changeset_log/changeset_reader.dart` - collect skipped peer names
- `lib/core/services/sync/sync_service.dart` - pass `deviceName`; carry names on `SyncResult`; trim `pullResultMessages`
- `lib/features/settings/presentation/pages/cloud_sync_page.dart` - danger-zone tile, first-contact hint, skipped-peer banner
- `lib/l10n/arb/app_*.arb` (11 files)

---

## Task 1: SyncDeviceMetadata

**Files:**
- Create: `lib/core/services/sync/sync_device_metadata.dart`
- Create: `test/core/services/sync/sync_device_metadata_test.dart`

**Interfaces:**
- Consumes: `SyncRepository.getDeviceId()`
- Produces: `SyncDeviceMetadata(SyncRepository)` with
  `Future<({String id, String? name, String? appVersion})> resolve()` and
  the static `String? sanitizeDeviceName(String? raw)`.

- [ ] **Step 1: Write the failing test**

Create `test/core/services/sync/sync_device_metadata_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/sync_device_metadata.dart';

void main() {
  group('sanitizeDeviceName', () {
    test('keeps a real hostname', () {
      expect(SyncDeviceMetadata.sanitizeDeviceName('Erics-MacBook-Pro'),
          'Erics-MacBook-Pro');
    });

    test('trims surrounding whitespace', () {
      expect(SyncDeviceMetadata.sanitizeDeviceName('  Erics-iPhone  '),
          'Erics-iPhone');
    });

    test('treats null, empty and whitespace as absent', () {
      expect(SyncDeviceMetadata.sanitizeDeviceName(null), isNull);
      expect(SyncDeviceMetadata.sanitizeDeviceName(''), isNull);
      expect(SyncDeviceMetadata.sanitizeDeviceName('   '), isNull);
    });

    test('treats localhost as absent regardless of case', () {
      // Android commonly reports 'localhost'; every device claiming the same
      // name is worse than falling back to the device id.
      expect(SyncDeviceMetadata.sanitizeDeviceName('localhost'), isNull);
      expect(SyncDeviceMetadata.sanitizeDeviceName('LocalHost'), isNull);
      expect(SyncDeviceMetadata.sanitizeDeviceName(' localhost '), isNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd "$WT" && flutter test test/core/services/sync/sync_device_metadata_test.dart`
Expected: FAIL - `Target of URI doesn't exist: 'package:submersion/core/services/sync/sync_device_metadata.dart'`

- [ ] **Step 3: Write minimal implementation**

Create `lib/core/services/sync/sync_device_metadata.dart`:

```dart
import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';

/// Who this device is, for anything that stamps an identity into the cloud:
/// library epoch markers, library moved markers, and per-device sync
/// manifests. One resolver so the three cannot drift apart.
class SyncDeviceMetadata {
  const SyncDeviceMetadata(this._syncRepository);

  final SyncRepository _syncRepository;

  /// Hostnames that identify nothing. Android routinely reports 'localhost',
  /// which would make every Android peer display under the same name; an
  /// absent name falls back to the device id, which is at least unique.
  static const _uselessNames = {'localhost'};

  /// Normalises a raw hostname, returning null when it identifies nothing.
  static String? sanitizeDeviceName(String? raw) {
    final trimmed = raw?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    if (_uselessNames.contains(trimmed.toLowerCase())) return null;
    return trimmed;
  }

  /// Each piece degrades independently to a safe default: markers are shown
  /// in banners and dialogs, so the origin must always be displayable.
  Future<({String id, String? name, String? appVersion})> resolve() async {
    String id;
    try {
      id = await _syncRepository.getDeviceId();
    } catch (_) {
      id = 'unknown';
    }
    String? name;
    try {
      name = sanitizeDeviceName(Platform.localHostname);
    } catch (_) {
      name = null;
    }
    String? appVersion;
    try {
      appVersion = (await PackageInfo.fromPlatform()).version;
    } catch (_) {
      appVersion = null;
    }
    return (id: id, name: name, appVersion: appVersion);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd "$WT" && flutter test test/core/services/sync/sync_device_metadata_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 5: Commit**

```bash
cd "$WT" && dart format . && git add lib/core/services/sync/sync_device_metadata.dart test/core/services/sync/sync_device_metadata_test.dart && git commit -m "Add SyncDeviceMetadata with hostname sanitization"
```

---

## Task 2: LibraryReplaceIntent, and collapse the duplicate copies

**Files:**
- Create: `lib/core/services/sync/library_replace_intent.dart`
- Create: `test/core/services/sync/library_replace_intent_test.dart`
- Modify: `lib/features/backup/data/services/backup_service.dart` (`_mintPendingReplace`)
- Modify: `lib/features/settings/presentation/providers/sync_providers.dart` (`_deviceMetadata`)

**Interfaces:**
- Consumes: `SyncDeviceMetadata.resolve()` from Task 1; `LibraryEpochStore.setPendingReplace(LibraryEpochMarker)`
- Produces: `LibraryReplaceIntent(SyncDeviceMetadata, LibraryEpochStore)` with `Future<LibraryEpochMarker> mint()`

- [ ] **Step 1: Write the failing test**

Create `test/core/services/sync/library_replace_intent_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/services/sync/library_epoch_store.dart';
import 'package:submersion/core/services/sync/library_replace_intent.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('mint persists a pending replace marker the gate can read', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = LibraryEpochStore(prefs);
    final intent = LibraryReplaceIntent.forTest(
      store: store,
      id: 'device-1',
      name: 'Erics-MacBook-Pro',
      appVersion: '1.2.3',
    );

    final marker = await intent.mint();

    expect(marker.epochId, isNotEmpty);
    expect(marker.deviceId, 'device-1');
    expect(marker.deviceName, 'Erics-MacBook-Pro');
    expect(marker.appVersion, '1.2.3');
    expect(marker.replacedAt, greaterThan(0));
    expect(store.pendingReplace?.epochId, marker.epochId);
  });

  test('each mint produces a distinct epoch id', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = LibraryEpochStore(prefs);
    final intent = LibraryReplaceIntent.forTest(store: store, id: 'device-1');

    final first = await intent.mint();
    final second = await intent.mint();

    expect(first.epochId, isNot(second.epochId));
  });

  test('an absent device name still mints a displayable marker', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = LibraryEpochStore(prefs);
    final intent = LibraryReplaceIntent.forTest(
      store: store,
      id: 'device-1',
      name: null,
    );

    final marker = await intent.mint();

    expect(marker.deviceName, isNull);
    expect(marker.displayName, 'device-1');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd "$WT" && flutter test test/core/services/sync/library_replace_intent_test.dart`
Expected: FAIL - `Target of URI doesn't exist: '.../library_replace_intent.dart'`

- [ ] **Step 3: Write minimal implementation**

Create `lib/core/services/sync/library_replace_intent.dart`:

```dart
import 'package:uuid/uuid.dart';

import 'package:submersion/core/services/sync/library_epoch.dart';
import 'package:submersion/core/services/sync/library_epoch_store.dart';
import 'package:submersion/core/services/sync/sync_device_metadata.dart';

/// Arms a library replacement: mints the epoch marker and persists it as the
/// pending intent. The cloud side is executed by SyncService's epoch gate on
/// the next sync, which is also what makes an interrupted replace resumable.
class LibraryReplaceIntent {
  LibraryReplaceIntent(this._metadata, this._store);

  /// Test seam: fixes the identity that [resolve] would otherwise read from
  /// the platform, so minting can be tested without a device id or hostname.
  factory LibraryReplaceIntent.forTest({
    required LibraryEpochStore store,
    required String id,
    String? name,
    String? appVersion,
  }) = _FixedIdentityReplaceIntent;

  final SyncDeviceMetadata? _metadata;
  final LibraryEpochStore _store;

  static const _uuid = Uuid();

  Future<({String id, String? name, String? appVersion})> _identity() =>
      _metadata!.resolve();

  Future<LibraryEpochMarker> mint() async {
    final identity = await _identity();
    final marker = LibraryEpochMarker(
      epochId: _uuid.v4(),
      replacedAt: DateTime.now().millisecondsSinceEpoch,
      deviceId: identity.id,
      deviceName: identity.name,
      appVersion: identity.appVersion,
    );
    await _store.setPendingReplace(marker);
    return marker;
  }
}

class _FixedIdentityReplaceIntent extends LibraryReplaceIntent {
  _FixedIdentityReplaceIntent({
    required LibraryEpochStore store,
    required this.id,
    this.name,
    this.appVersion,
  }) : super(null, store);

  final String id;
  final String? name;
  final String? appVersion;

  @override
  Future<({String id, String? name, String? appVersion})> _identity() async =>
      (id: id, name: name, appVersion: appVersion);
}
```

Note: `_identity` is private, so the subclass must live in this same file for the override to bind. That is why the test seam is a factory here rather than a public mock.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd "$WT" && flutter test test/core/services/sync/library_replace_intent_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: Delegate BackupService to the new service**

In `lib/features/backup/data/services/backup_service.dart`, replace the body of `_mintPendingReplace` (which currently inlines uuid, device id, hostname, and PackageInfo) with:

```dart
  /// Mint and persist the pending-replace intent. The cloud side executes on
  /// the next sync (typically the post-restart launch sync); until it lands,
  /// the intent fences off merging.
  Future<void> _mintPendingReplace() async {
    final store = _epochStore;
    if (store == null) {
      _log.warning('Replace mode requested but no epoch store is configured');
      return;
    }
    final marker = await LibraryReplaceIntent(
      SyncDeviceMetadata(_syncRepository),
      store,
    ).mint();
    _log.info('Minted pending library replace (epoch ${marker.epochId})');
  }
```

Add imports for `library_replace_intent.dart` and `sync_device_metadata.dart`. Remove any now-unused imports (`package_info_plus`, `uuid`, `dart:io`) **only if** nothing else in the file uses them - check with `grep -n "PackageInfo\|Uuid\|Platform\." lib/features/backup/data/services/backup_service.dart`.

- [ ] **Step 6: Delegate SyncNotifier to the new resolver**

In `lib/features/settings/presentation/providers/sync_providers.dart`, replace the body of `_deviceMetadata` with a delegation that preserves its existing record shape (positional, used by existing callers):

```dart
  /// Device identity for a marker: (deviceId, deviceName, appVersion). Each
  /// piece degrades to a safe default; markers are shown in banners so the
  /// origin must always be displayable.
  Future<(String, String?, String?)> _deviceMetadata() async {
    final identity = await SyncDeviceMetadata(_syncRepository).resolve();
    return (identity.id, identity.name, identity.appVersion);
  }
```

Add the `sync_device_metadata.dart` import.

- [ ] **Step 7: Run the regression net**

Run: `cd "$WT" && flutter test test/core/services/sync test/features/backup`
Expected: PASS, at least 903 + 7 tests, 0 failures. The existing replace-restore tests are the regression net for the delegation.

- [ ] **Step 8: Commit**

```bash
cd "$WT" && dart format . && git add -A && git commit -m "Extract LibraryReplaceIntent and collapse duplicate device-metadata copies"
```

---

## Task 3: SyncNotifier replace preflight and action

**Files:**
- Modify: `lib/features/settings/presentation/providers/sync_providers.dart`
- Test: `test/features/settings/presentation/providers/sync_replace_action_test.dart` (create)

**Interfaces:**
- Consumes: `LibraryReplaceIntent.mint()` (Task 2); `LibraryEpochStore.pendingReplace`
- Produces: on `SyncNotifier`:
  - `Future<ReplacePreflight> replacePreflight()`
  - `Future<void> replaceCloudLibraryFromThisDevice()`
  - class `ReplacePreflight { final int localDiveCount; final int? peerFileCount; }` where a null `peerFileCount` means the peer listing failed or timed out.

- [ ] **Step 1: Write the failing test**

Create `test/features/settings/presentation/providers/sync_replace_action_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

void main() {
  group('ReplacePreflight', () {
    test('a null peer count means the listing did not succeed', () {
      const preflight = ReplacePreflight(localDiveCount: 1247);

      expect(preflight.localDiveCount, 1247);
      expect(preflight.peerFileCount, isNull);
      expect(preflight.hasPeerCount, isFalse);
    });

    test('a known peer count is reported', () {
      const preflight =
          ReplacePreflight(localDiveCount: 1247, peerFileCount: 2);

      expect(preflight.peerFileCount, 2);
      expect(preflight.hasPeerCount, isTrue);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd "$WT" && flutter test test/features/settings/presentation/providers/sync_replace_action_test.dart`
Expected: FAIL - `Undefined class 'ReplacePreflight'`

- [ ] **Step 3: Add ReplacePreflight**

In `lib/features/settings/presentation/providers/sync_providers.dart`, next to `FirstSyncMergeInfo`:

```dart
/// Blast radius for the Replace confirmation: how much of this device's
/// library will become authoritative, and how many peers will be asked to
/// adopt. [peerFileCount] is null when the peer listing failed or timed out;
/// the dialog then falls back to a count-less string rather than blocking.
class ReplacePreflight {
  const ReplacePreflight({required this.localDiveCount, this.peerFileCount});

  final int localDiveCount;
  final int? peerFileCount;

  bool get hasPeerCount => peerFileCount != null;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd "$WT" && flutter test test/features/settings/presentation/providers/sync_replace_action_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: Add the notifier methods**

In `SyncNotifier`, after `libraryReplaceInfo()`:

```dart
  /// Blast radius for the Replace confirmation. Never throws: a failed or slow
  /// peer listing degrades to a null count, because a pre-check must not gate
  /// the escape hatch it is describing.
  Future<ReplacePreflight> replacePreflight() async {
    final localDives = await _ref.read(diveRepositoryProvider).getDiveCount();
    final provider = _ref.read(cloudStorageProviderProvider);
    if (provider == null) {
      return ReplacePreflight(localDiveCount: localDives);
    }
    try {
      final peers = await _ref
          .read(syncInitializerProvider)
          .peerSyncFiles(provider)
          .timeout(const Duration(seconds: 8));
      return ReplacePreflight(
        localDiveCount: localDives,
        peerFileCount: peers.length,
      );
    } catch (e) {
      _log.warning('Replace preflight peer listing failed: $e');
      return ReplacePreflight(localDiveCount: localDives);
    }
  }

  /// Make this device's library the one every device uses. Arms the replace
  /// intent, then syncs: the epoch gate checks pendingReplace BEFORE reading
  /// the cloud marker, so this also works on a device currently fenced off
  /// awaiting someone else's adoption. The CALLER is responsible for the
  /// safety backup (cloud_sync_page runs it via backupServiceProvider to
  /// avoid a provider import cycle), matching adoptReplacedLibrary.
  Future<void> replaceCloudLibraryFromThisDevice() async {
    final provider = _ref.read(cloudStorageProviderProvider);
    if (provider == null) {
      state = state.copyWith(
        status: SyncStatus.error,
        message: 'No cloud provider configured',
      );
      return;
    }
    final store = _ref.read(libraryEpochStoreProvider);
    // Already armed (a previous attempt failed mid-flight): do not mint a
    // second epoch, just drive the pending one to completion.
    if (store.pendingReplace == null) {
      await LibraryReplaceIntent(
        SyncDeviceMetadata(_syncRepository),
        store,
      ).mint();
    }
    await performSync();
  }
```

Add imports for `library_replace_intent.dart`.

- [ ] **Step 6: Verify analysis and the sync suite**

Run: `cd "$WT" && flutter analyze lib/features/settings/presentation/providers/sync_providers.dart && flutter test test/features/settings`
Expected: analyze clean; settings tests pass.

- [ ] **Step 7: Commit**

```bash
cd "$WT" && dart format . && git add -A && git commit -m "Add replace preflight and replace-from-this-device action"
```

---

## Task 4: Replace dialog, danger-zone tile, and its strings

**Files:**
- Create: `lib/features/settings/presentation/widgets/replace_cloud_library_dialog.dart`
- Create: `test/features/settings/presentation/widgets/replace_cloud_library_dialog_test.dart`
- Modify: `lib/features/settings/presentation/pages/cloud_sync_page.dart` (Sign Out tile area)
- Modify: `lib/l10n/arb/app_*.arb` (11 files)

**Interfaces:**
- Consumes: `SyncNotifier.replacePreflight()`, `SyncNotifier.replaceCloudLibraryFromThisDevice()` (Task 3); `backupServiceProvider.performBackup(isAutomatic: true)`
- Produces: `Future<void> showReplaceCloudLibraryDialog(BuildContext, WidgetRef, ReplacePreflight)`

- [ ] **Step 1: Add the English strings**

In `lib/l10n/arb/app_en.arb`, add (keep the file's existing alphabetical grouping near the other `settings_cloudSync_` keys):

```json
  "settings_cloudSync_replaceLibrary_tile": "Replace cloud library",
  "settings_cloudSync_replaceLibrary_tileSubtitle": "Make this device's library the one every device uses",
  "settings_cloudSync_replaceLibrary_dialogTitle": "Replace Cloud Library?",
  "settings_cloudSync_replaceLibrary_dialogBody": "{diveCount, plural, =1{The cloud library is erased and replaced with this device's 1 dive.} other{The cloud library is erased and replaced with this device's {diveCount} dives.}}",
  "settings_cloudSync_replaceLibrary_peers": "{peerCount, plural, =1{1 other device will be asked to adopt it; until it does, its changes are not merged.} other{{peerCount} other devices will be asked to adopt it; until they do, their changes are not merged.}}",
  "settings_cloudSync_replaceLibrary_peersUnknown": "Every other device will be asked to adopt it; until they do, their changes are not merged.",
  "settings_cloudSync_replaceLibrary_backupNote": "A backup of this device is created first. This cannot be undone.",
  "settings_cloudSync_replaceLibrary_confirmHint": "Type \"Replace\" to confirm",
  "settings_cloudSync_replaceLibrary_confirm": "Replace",
  "settings_cloudSync_dangerZone": "Danger Zone",
```

- [ ] **Step 2: Run the parity test to verify it fails**

Run: `cd "$WT" && flutter test test/l10n/arb_parity_test.dart`
Expected: FAIL - "every locale defines every English key" lists the 10 new keys as missing from each of the 10 non-English locales.

- [ ] **Step 3: Translate into the other ten locales**

Add the same 10 keys, translated, to each of `app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb`. Preserve the ICU plural structure and the `{diveCount}` / `{peerCount}` placeholder names exactly; translate only the prose. Match each file's existing key ordering convention.

- [ ] **Step 4: Run the parity test to verify it passes, and regenerate**

Run: `cd "$WT" && flutter test test/l10n/arb_parity_test.dart && flutter gen-l10n`
Expected: PASS; `lib/l10n/arb/app_localizations*.dart` regenerated with the new getters.

- [ ] **Step 5: Write the failing dialog test**

Create `test/features/settings/presentation/widgets/replace_cloud_library_dialog_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:submersion/features/settings/presentation/widgets/replace_cloud_library_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Widget host(Widget child) => MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: child,
    );

void main() {
  testWidgets('Replace stays disabled until the word is typed', (tester) async {
    await tester.pumpWidget(host(
      const Scaffold(body: ReplaceCloudLibraryDialogBody(
        localDiveCount: 1247,
        peerFileCount: 2,
      )),
    ));

    final button = () => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Replace'));

    expect(button().onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'replace');
    await tester.pump();
    expect(button().onPressed, isNull,
        reason: 'confirmation is case-sensitive');

    await tester.enterText(find.byType(TextField), 'Replace');
    await tester.pump();
    expect(button().onPressed, isNotNull);
  });

  testWidgets('names the blast radius when the peer count is known',
      (tester) async {
    await tester.pumpWidget(host(
      const Scaffold(body: ReplaceCloudLibraryDialogBody(
        localDiveCount: 1247,
        peerFileCount: 2,
      )),
    ));

    expect(find.textContaining('1247 dives'), findsOneWidget);
    expect(find.textContaining('2 other devices'), findsOneWidget);
  });

  testWidgets('falls back to a count-less line when preflight failed',
      (tester) async {
    await tester.pumpWidget(host(
      const Scaffold(body: ReplaceCloudLibraryDialogBody(
        localDiveCount: 1247,
        peerFileCount: null,
      )),
    ));

    expect(find.textContaining('Every other device'), findsOneWidget);
  });
}
```

- [ ] **Step 6: Run test to verify it fails**

Run: `cd "$WT" && flutter test test/features/settings/presentation/widgets/replace_cloud_library_dialog_test.dart`
Expected: FAIL - `Target of URI doesn't exist: '.../replace_cloud_library_dialog.dart'`

- [ ] **Step 7: Implement the dialog**

Create `lib/features/settings/presentation/widgets/replace_cloud_library_dialog.dart`. `ReplaceCloudLibraryDialogBody` is public and provider-free so the confirmation logic is testable without a ProviderScope:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The confirmation content: blast radius plus a type-to-confirm gate.
/// Separated from the dialog shell so it can be widget-tested without
/// providers. Calls [onConfirmedChanged] whenever the gate flips.
class ReplaceCloudLibraryDialogBody extends StatefulWidget {
  const ReplaceCloudLibraryDialogBody({
    super.key,
    required this.localDiveCount,
    required this.peerFileCount,
    this.onConfirmedChanged,
  });

  final int localDiveCount;
  final int? peerFileCount;
  final ValueChanged<bool>? onConfirmedChanged;

  @override
  State<ReplaceCloudLibraryDialogBody> createState() =>
      _ReplaceCloudLibraryDialogBodyState();
}

class _ReplaceCloudLibraryDialogBodyState
    extends State<ReplaceCloudLibraryDialogBody> {
  final _controller = TextEditingController();
  bool _isConfirmed = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final confirmed = _controller.text.trim() == 'Replace';
    if (confirmed != _isConfirmed) {
      setState(() => _isConfirmed = confirmed);
      widget.onConfirmedChanged?.call(confirmed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final peers = widget.peerFileCount;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.settings_cloudSync_replaceLibrary_dialogBody(
            widget.localDiveCount,
          ),
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        Text(
          peers == null
              ? l10n.settings_cloudSync_replaceLibrary_peersUnknown
              : l10n.settings_cloudSync_replaceLibrary_peers(peers),
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        Text(
          l10n.settings_cloudSync_replaceLibrary_backupNote,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            hintText: l10n.settings_cloudSync_replaceLibrary_confirmHint,
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        const SizedBox(height: 8),
        // The enabled state the shell mirrors; kept here so the body alone is
        // testable for the gate behaviour.
        FilledButton(
          onPressed: _isConfirmed ? () => Navigator.pop(context, true) : null,
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
          ),
          child: Text(l10n.settings_cloudSync_replaceLibrary_confirm),
        ),
      ],
    );
  }
}

/// Confirm and run a library replacement from this device. The safety backup
/// runs here rather than in SyncNotifier because backup providers import sync
/// providers; this widget layer may import both. Mirrors
/// showAdoptReplacedLibraryDialog.
Future<void> showReplaceCloudLibraryDialog(
  BuildContext context,
  WidgetRef ref,
  ReplacePreflight preflight,
) async {
  final l10n = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.settings_cloudSync_replaceLibrary_dialogTitle),
      content: SingleChildScrollView(
        child: ReplaceCloudLibraryDialogBody(
          localDiveCount: preflight.localDiveCount,
          peerFileCount: preflight.peerFileCount,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  await ref.read(backupServiceProvider).performBackup(isAutomatic: true);
  await ref
      .read(syncStateProvider.notifier)
      .replaceCloudLibraryFromThisDevice();
}
```

- [ ] **Step 8: Run test to verify it passes**

Run: `cd "$WT" && flutter test test/features/settings/presentation/widgets/replace_cloud_library_dialog_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 9: Add the danger-zone tile to the Cloud Sync page**

In `lib/features/settings/presentation/pages/cloud_sync_page.dart`, find the `ListTile` with `Icons.logout` / `'Sign Out'` (near line 1328 in the current file; confirm with `grep -n "Sign Out" lib/features/settings/presentation/pages/cloud_sync_page.dart`). Insert immediately **before** it:

```dart
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            context.l10n.settings_cloudSync_dangerZone,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ListTile(
          leading: Icon(
            Icons.published_with_changes,
            color: Theme.of(context).colorScheme.error,
          ),
          title: Text(context.l10n.settings_cloudSync_replaceLibrary_tile),
          subtitle: Text(
            context.l10n.settings_cloudSync_replaceLibrary_tileSubtitle,
          ),
          onTap: () async {
            final notifier = ref.read(syncStateProvider.notifier);
            final preflight = await notifier.replacePreflight();
            if (!context.mounted) return;
            await showReplaceCloudLibraryDialog(context, ref, preflight);
          },
        ),
```

Add the import for `replace_cloud_library_dialog.dart`.

This block sits inside the branch that renders only for a connected provider (the same list that holds Sign Out), which satisfies the "tile not rendered when unauthenticated" rule without an extra guard. Verify that by confirming the Sign Out tile you inserted before is inside the connected-state builder.

- [ ] **Step 10: Verify and commit**

Run: `cd "$WT" && dart format . && flutter analyze lib/features/settings && flutter test test/features/settings test/l10n`
Expected: analyze clean, tests pass.

```bash
cd "$WT" && git add -A && git commit -m "Add Replace cloud library action to the Cloud Sync danger zone"
```

---

## Task 5: Reset flow copy

**Files:**
- Modify: `lib/l10n/arb/app_*.arb` (11 files)
- Test: `test/features/settings/presentation/widgets/reset_database_dialog_test.dart` (extend - this file already exists)

**Interfaces:**
- Consumes: nothing new
- Produces: no new symbols; three existing keys change meaning

- [ ] **Step 1: Write the failing test**

Create or extend the reset dialog test so it asserts the new promises are actually shown:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:submersion/features/settings/presentation/widgets/reset_database_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  testWidgets('reset dialog states the scope and the sync disconnect',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: const Scaffold(body: ResetDatabaseDialog()),
    ));

    // The reset is local-only: the cloud library and other devices survive.
    expect(find.textContaining('cloud library is not deleted'), findsOneWidget);
    expect(find.textContaining('other devices keep their data'),
        findsOneWidget);
    // And it silently signs out of sync, which the user must hear about.
    expect(find.textContaining('Cloud sync will be disconnected'),
        findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd "$WT" && flutter test test/features/settings/presentation/widgets/reset_database_dialog_test.dart`
Expected: FAIL - the three `textContaining` matchers find nothing, because the current body is "This will permanently delete all your data including dives, sites, gear, and settings. A backup will be created automatically before resetting."

- [ ] **Step 3: Rewrite the English strings**

In `lib/l10n/arb/app_en.arb`, replace the values of these three existing keys:

```json
  "settings_storage_resetDatabase_subtitle": "Delete all data on this device and start fresh",
  "settings_storage_resetDialog_body": "This permanently deletes all data on THIS device, including dives, sites, gear, and settings. A backup is created automatically before resetting.\n\nYour cloud library is not deleted, and other devices keep their data. Cloud sync will be disconnected so the reset is not undone; you can reconnect it in Settings > Cloud Sync.",
  "settings_storage_resetComplete_description": "This device's data has been cleared. Cloud sync is currently disconnected so the reset is not undone; you can reconnect it in Settings > Cloud Sync.",
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd "$WT" && flutter gen-l10n && flutter test test/features/settings/presentation/widgets/reset_database_dialog_test.dart`
Expected: PASS

- [ ] **Step 5: Update the other ten locales**

Rewrite the same three keys in each of `app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb` to match the new English meaning. These keys already exist in every locale, so `arb_parity_test` will not catch a missed file - check each one by hand with:

`cd "$WT" && grep -l "settings_storage_resetDialog_body" lib/l10n/arb/*.arb | xargs grep -c "Cloud sync\|cloud" `

then read each locale's value to confirm it carries the three new promises.

- [ ] **Step 6: Verify and commit**

Run: `cd "$WT" && dart format . && flutter gen-l10n && flutter test test/l10n test/features/settings`
Expected: PASS

```bash
cd "$WT" && git add -A && git commit -m "Say what Reset Database actually does, including the sync disconnect"
```

---

## Task 6: First-contact replace hint

**Files:**
- Modify: `lib/l10n/arb/app_*.arb` (11 files)
- Modify: `lib/features/settings/presentation/pages/cloud_sync_page.dart` (`_onSyncNowPressed`)
- Test: `test/features/settings/presentation/first_contact_hint_test.dart` (create)

**Interfaces:**
- Consumes: nothing new
- Produces: key `settings_cloudSync_firstSync_replaceHint`

- [ ] **Step 1: Add the English string and run parity**

Add to `lib/l10n/arb/app_en.arb`:

```json
  "settings_cloudSync_firstSync_replaceHint": "If instead this device's library should replace what is in the cloud, cancel and use Settings > Cloud Sync > Replace cloud library.",
```

Run: `cd "$WT" && flutter test test/l10n/arb_parity_test.dart`
Expected: FAIL - the key is missing from all 10 non-English locales.

- [ ] **Step 2: Translate into the other ten locales, then verify**

Add the translated key to each of the 10 non-English ARB files.

Run: `cd "$WT" && flutter test test/l10n/arb_parity_test.dart && flutter gen-l10n`
Expected: PASS

- [ ] **Step 3: Write the failing widget test**

Create `test/features/settings/presentation/first_contact_hint_test.dart`. Build only the dialog content that `_onSyncNowPressed` shows, to keep the test free of sync providers:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

void main() {
  testWidgets('first-contact dialog names the replace alternative',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Builder(
        builder: (context) => Scaffold(
          body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n
                  .settings_cloudSync_firstSync_dialogContent(2, 1247)),
              const SizedBox(height: 12),
              Text(context.l10n.settings_cloudSync_firstSync_replaceHint),
            ],
          ),
        ),
      ),
    ));

    expect(find.textContaining('Replace cloud library'), findsOneWidget);
  });
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd "$WT" && flutter test test/features/settings/presentation/first_contact_hint_test.dart`
Expected: PASS (this test guards the string exists and reads correctly; the wiring is asserted by analysis in the next step)

- [ ] **Step 5: Wire the hint into the real dialog**

In `_onSyncNowPressed` in `cloud_sync_page.dart`, replace the `content:` argument of the first-contact `AlertDialog` (currently a bare `Text(...)`) with:

```dart
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.settings_cloudSync_firstSync_dialogContent(
                info.peerFileCount,
                info.localDiveCount,
              ),
            ),
            const SizedBox(height: 12),
            Text(l10n.settings_cloudSync_firstSync_replaceHint),
          ],
        ),
```

- [ ] **Step 6: Verify and commit**

Run: `cd "$WT" && dart format . && flutter analyze lib/features/settings && flutter test test/features/settings test/l10n`
Expected: analyze clean, tests pass.

```bash
cd "$WT" && git add -A && git commit -m "Point the first-contact dialog at the replace alternative"
```

---

## Task 7: Manifest deviceName and writer plumbing

**Files:**
- Modify: `lib/core/services/sync/changeset_log/sync_manifest.dart`
- Modify: `lib/core/services/sync/changeset_log/changeset_writer.dart`
- Modify: `lib/core/services/sync/sync_service.dart` (two `publish(` call sites)
- Test: `test/core/services/sync/changeset_log/sync_manifest_test.dart` (extend)

**Interfaces:**
- Consumes: `SyncDeviceMetadata.resolve()` (Task 1)
- Produces: `SyncManifest.deviceName` (`String?`); `ChangesetWriter.publish({..., String? deviceName})`

- [ ] **Step 1: Write the failing test**

Append to `test/core/services/sync/changeset_log/sync_manifest_test.dart`, mirroring the existing `schemaVersion` pair:

```dart
  test('round-trips deviceName', () {
    const manifest = SyncManifest(
      deviceId: 'dev-1',
      provider: 'icloud',
      headSeq: 3,
      updatedAt: 1234,
      deviceName: 'Erics-MacBook-Pro',
    );

    final back = SyncManifest.fromJson(manifest.toJson());

    expect(back.deviceName, 'Erics-MacBook-Pro');
  });

  test('legacy manifest without deviceName parses as null', () {
    final back = SyncManifest.fromJson({
      'deviceId': 'dev-1',
      'provider': 'icloud',
      'headSeq': 3,
      'updatedAt': 1234,
    });

    expect(back.deviceName, isNull);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd "$WT" && flutter test test/core/services/sync/changeset_log/sync_manifest_test.dart`
Expected: FAIL - `No named parameter with the name 'deviceName'`

- [ ] **Step 3: Add the field**

In `sync_manifest.dart`:

1. Add to the constructor parameter list, next to `this.schemaVersion`: `this.deviceName,`
2. Add the field next to `schemaVersion`:

```dart
  /// Display name of the publishing device, used to name peers in the
  /// "still needs to adopt" banner. Null on manifests written before this
  /// field existed, and on devices whose hostname identifies nothing (see
  /// SyncDeviceMetadata.sanitizeDeviceName), so readers must fall back to
  /// the device id.
  final String? deviceName;
```

3. Add to `toJson()`: `'deviceName': deviceName,`
4. Add to `fromJson`: `deviceName: json['deviceName'] as String?,`

- [ ] **Step 4: Run test to verify it passes**

Run: `cd "$WT" && flutter test test/core/services/sync/changeset_log/sync_manifest_test.dart`
Expected: PASS

- [ ] **Step 5: Thread deviceName through the writer**

In `changeset_writer.dart`, add to `publish`'s named parameters, after `String? epochId,`:

```dart
    String? deviceName,
```

Then add `deviceName: deviceName,` to **all four** `SyncManifest(` construction sites in this file. Find them with:

`cd "$WT" && grep -n "SyncManifest(" lib/core/services/sync/changeset_log/changeset_writer.dart`

Expected: 4 sites (the base publish, the heartbeat, the changeset append, and the compaction rewrite). Missing one means a heartbeat or compaction silently drops the name and the peer reverts to an id label.

- [ ] **Step 6: Resolve and pass the name from SyncService**

In `sync_service.dart`, add a cached resolver field and use it at both `_changesetWriter.publish(` call sites (find them with `grep -n "_changesetWriter.publish(" lib/core/services/sync/sync_service.dart`; expect 2):

```dart
  String? _cachedDeviceName;
  bool _deviceNameResolved = false;

  /// Resolved once per service lifetime: the hostname does not change while
  /// the app runs, and publish is on the sync hot path.
  Future<String?> _deviceNameForManifest() async {
    if (_deviceNameResolved) return _cachedDeviceName;
    _cachedDeviceName = (await SyncDeviceMetadata(_syncRepository).resolve())
        .name;
    _deviceNameResolved = true;
    return _cachedDeviceName;
  }
```

At each call site add `deviceName: await _deviceNameForManifest(),`. Add the `sync_device_metadata.dart` import.

- [ ] **Step 7: Run the sync suite**

Run: `cd "$WT" && flutter test test/core/services/sync`
Expected: PASS, no regressions.

- [ ] **Step 8: Commit**

```bash
cd "$WT" && dart format . && git add -A && git commit -m "Publish a device name on the sync manifest"
```

---

## Task 8: Reader collects skipped peer names

**Files:**
- Modify: `lib/core/services/sync/changeset_log/changeset_reader.dart`
- Modify: `lib/core/services/sync/sync_service.dart` (`SyncResult`, and the two `SyncResult(` returns that pass `skippedPeerDeviceIds`)
- Test: `test/core/services/sync/changeset_log/changeset_reader_epoch_test.dart` (extend)

**Interfaces:**
- Consumes: `SyncManifest.deviceName` (Task 7)
- Produces: `ChangesetReadResult.skippedPeerNames` and `SyncResult.skippedPeerNames`, both `Map<String, String>` of peer device id to display name, containing **only** peers that had a non-null name.

- [ ] **Step 1: Write the failing test**

Add to `test/core/services/sync/changeset_log/changeset_reader_epoch_test.dart`. Follow the file's existing harness for staging peer manifests; the assertions are:

```dart
  test('collects names for skipped peers only', () async {
    // Stage two peers on a stale epoch (one named, one legacy/unnamed) and
    // one healthy peer on the current epoch, then pull.
    // ... existing harness setup, mirroring the surrounding tests ...

    final result = await reader.pull(/* ... current epoch ... */);

    expect(result.skippedPeerDeviceIds, {'stale-named', 'stale-unnamed'});
    // Named stale peer resolves; unnamed one is absent so the caller falls
    // back to an id label rather than inventing a name.
    expect(result.skippedPeerNames, {'stale-named': 'Erics-iPhone'});
    // A healthy peer is never listed, named or not.
    expect(result.skippedPeerNames.containsKey('healthy'), isFalse);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd "$WT" && flutter test test/core/services/sync/changeset_log/changeset_reader_epoch_test.dart`
Expected: FAIL - `The getter 'skippedPeerNames' isn't defined for the class 'ChangesetReadResult'`

- [ ] **Step 3: Add the field to ChangesetReadResult**

In `changeset_reader.dart`, add the constructor parameter `this.skippedPeerNames = const {},` and the field next to `skippedPeerDeviceIds`:

```dart
  /// Display names for the skipped peers that published one, keyed by device
  /// id. Peers on older manifests, or whose hostname identifies nothing, are
  /// simply absent; the UI falls back to an id label for those.
  final Map<String, String> skippedPeerNames;
```

- [ ] **Step 4: Populate it in the pull loop**

Next to `final skippedPeerDeviceIds = <String>{};` add:

```dart
    final skippedPeerNames = <String, String>{};
```

In the epoch-skip branch, extend it (do NOT change the skip condition itself):

```dart
        if (currentEpochId != null && manifest.epochId != currentEpochId) {
          skippedPeerDeviceIds.add(peerId);
          final name = manifest.deviceName;
          if (name != null && name.isNotEmpty) {
            skippedPeerNames[peerId] = name;
          }
          continue;
        }
```

Add `skippedPeerNames: skippedPeerNames,` to the `ChangesetReadResult(` return.

- [ ] **Step 5: Run test to verify it passes**

Run: `cd "$WT" && flutter test test/core/services/sync/changeset_log/changeset_reader_epoch_test.dart`
Expected: PASS

- [ ] **Step 6: Carry the names on SyncResult**

In `sync_service.dart`, add to `SyncResult`:

```dart
  /// Display names for [skippedPeerDeviceIds] that published one. Absent
  /// entries mean the peer is on an older manifest; render its id instead.
  final Map<String, String> skippedPeerNames;
```

Add `this.skippedPeerNames = const {},` to the constructor, and `skippedPeerNames: pullResult.skippedPeerNames,` to both `SyncResult(` returns that already pass `skippedPeerDeviceIds` (find with `grep -n "skippedPeerDeviceIds: pullResult" lib/core/services/sync/sync_service.dart`; expect 2).

- [ ] **Step 7: Run the sync suite and commit**

Run: `cd "$WT" && dart format . && flutter test test/core/services/sync`
Expected: PASS

```bash
cd "$WT" && git add -A && git commit -m "Collect display names for epoch-skipped sync peers"
```

---

## Task 9: Skipped-peer banner and pullResultMessages cleanup

**Files:**
- Modify: `lib/features/settings/presentation/providers/sync_providers.dart` (`SyncState`, and where `newerSchemaPeerCount` is set from a result)
- Modify: `lib/core/services/sync/sync_service.dart` (`pullResultMessages`)
- Modify: `lib/features/settings/presentation/pages/cloud_sync_page.dart` (new banner)
- Modify: `lib/l10n/arb/app_*.arb` (11 files)
- Test: `test/core/services/sync/sync_result_messages_test.dart` (extend - this file exists and already covers `pullResultMessages`; its existing assertions about the two peer sentences must be updated, not left to fail)
- Test: `test/features/settings/presentation/skipped_peer_banner_test.dart` (create)

**Interfaces:**
- Consumes: `SyncResult.skippedPeerNames`, `SyncResult.skippedPeerDeviceIds` (Task 8)
- Produces: `SyncState.skippedPeerLabels` (`List<String>`); key `settings_cloudSync_peerNeedsAdopt_banner`

- [ ] **Step 1: Write the failing message test**

In the `pullResultMessages` test file, assert the peer sentences are gone and the rest survive:

```dart
  test('peer notices are left to their banners, not the message', () {
    final messages = SyncService.pullResultMessages(
      recordsFailed: 0,
      skippedPeerDeviceIds: {'a', 'b'},
      newerSchemaPeerDeviceIds: {'c'},
      adoptedFreshIdentity: false,
    );

    expect(messages, isEmpty);
  });

  test('record failures still surface, and suppress everything else', () {
    final messages = SyncService.pullResultMessages(
      recordsFailed: 2,
      skippedPeerDeviceIds: {'a'},
      newerSchemaPeerDeviceIds: {'c'},
      adoptedFreshIdentity: true,
    );

    expect(messages, ['2 records failed to apply']);
  });

  test('a fresh identity adoption still surfaces', () {
    final messages = SyncService.pullResultMessages(
      recordsFailed: 0,
      skippedPeerDeviceIds: const {},
      newerSchemaPeerDeviceIds: const {},
      adoptedFreshIdentity: true,
    );

    expect(messages, hasLength(1));
    expect(messages.single, contains('adopted a new identity'));
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd "$WT" && flutter test test/core/services/sync/sync_result_messages_test.dart`
Expected: FAIL - the first test gets the two peer sentences instead of an empty list.

- [ ] **Step 3: Trim pullResultMessages**

In `sync_service.dart`, delete the `skippedCount` block and the `newerCount` block from `pullResultMessages`, leaving the `recordsFailed` early return and the `adoptedFreshIdentity` block. Keep the parameters - callers still pass them and removing them would churn the call sites for no gain. Update the doc comment to say peer notices are rendered as banners from the structured fields.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd "$WT" && flutter test test/core/services/sync/sync_result_messages_test.dart`
Expected: PASS

- [ ] **Step 5: Add the banner string**

Add to `lib/l10n/arb/app_en.arb`:

```json
  "settings_cloudSync_peerNeedsAdopt_banner": "{deviceList} still has an older or unknown library version, so its changes were not merged. Open Submersion on it to adopt the current library.",
  "settings_cloudSync_peerNeedsAdopt_bannerPlural": "{deviceList} still have an older or unknown library version, so their changes were not merged. Open Submersion on them to adopt the current library.",
  "settings_cloudSync_peerNeedsAdopt_unnamedDevice": "device {shortId}",
```

Two keys rather than an ICU plural because the variable part is a joined device list, not a count.

Run: `cd "$WT" && flutter test test/l10n/arb_parity_test.dart`
Expected: FAIL - 3 keys missing from 10 locales.

- [ ] **Step 6: Translate, regenerate, verify**

Add the 3 translated keys to each of the 10 non-English ARB files, preserving `{deviceList}` and `{shortId}`.

Run: `cd "$WT" && flutter test test/l10n/arb_parity_test.dart && flutter gen-l10n`
Expected: PASS

- [ ] **Step 7: Add skippedPeerLabels to SyncState**

In `sync_providers.dart`:

1. Field, next to `newerSchemaPeerCount`:

```dart
  /// Display labels for peers held back by the library-epoch fence during the
  /// last pull. Drives the "needs to adopt" banner; cleared when a fresh sync
  /// starts. Named peers use their published name; the rest fall back to a
  /// short device id.
  final List<String> skippedPeerLabels;
```

2. Constructor: `this.skippedPeerLabels = const [],`
3. `copyWith` parameter: `List<String>? skippedPeerLabels,` and body line: `skippedPeerLabels: skippedPeerLabels ?? this.skippedPeerLabels,`
4. Where a sync starts and clears `newerSchemaPeerCount: 0`, also clear `skippedPeerLabels: const []`.
5. Where the result is applied (the line that sets `newerSchemaPeerCount: result.newerSchemaPeerDeviceIds.length`), add:

```dart
            skippedPeerLabels: _skippedPeerLabels(result),
```

6. Add the resolver method to `SyncNotifier`. It returns the raw pieces rather than finished strings, because the notifier has no `BuildContext` and so cannot localize the unnamed-device fallback; the page does that:

```dart
  /// (name, shortId) per skipped peer. A null name means the peer published
  /// no usable one; the page turns that into the localized "device <shortId>"
  /// label. Sorted so the banner text is stable across syncs rather than
  /// reordering on each pull.
  List<({String? name, String shortId})> _skippedPeerLabels(SyncResult result) {
    final entries = result.skippedPeerDeviceIds.map((id) {
      final name = result.skippedPeerNames[id];
      final shortId = id.length > 8 ? id.substring(0, 8) : id;
      return (
        name: (name != null && name.isNotEmpty) ? name : null,
        shortId: shortId,
      );
    }).toList()
      ..sort((a, b) => (a.name ?? a.shortId).compareTo(b.name ?? b.shortId));
    return entries;
  }
```

- [ ] **Step 8: Write the failing banner test**

Create `test/features/settings/presentation/skipped_peer_banner_test.dart`, testing the label-to-text composition the page performs:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:submersion/features/settings/presentation/pages/cloud_sync_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(body: child),
      );

  testWidgets('names a single skipped peer', (tester) async {
    await tester.pumpWidget(host(const SkippedPeerBanner(
      peers: [(name: 'Erics-iPhone', shortId: 'a1b2c3d4')],
    )));

    expect(find.textContaining('Erics-iPhone still has'), findsOneWidget);
  });

  testWidgets('falls back to a short id for an unnamed peer', (tester) async {
    await tester.pumpWidget(host(const SkippedPeerBanner(
      peers: [(name: null, shortId: 'a1b2c3d4')],
    )));

    expect(find.textContaining('device a1b2c3d4'), findsOneWidget);
  });

  testWidgets('joins several peers and uses the plural form', (tester) async {
    await tester.pumpWidget(host(const SkippedPeerBanner(
      peers: [
        (name: 'Erics-iPhone', shortId: 'a1b2c3d4'),
        (name: null, shortId: 'e5f6a7b8'),
      ],
    )));

    expect(find.textContaining('Erics-iPhone and device e5f6a7b8'),
        findsOneWidget);
    expect(find.textContaining('still have'), findsOneWidget);
  });

  testWidgets('renders nothing when no peer was skipped', (tester) async {
    await tester.pumpWidget(host(const SkippedPeerBanner(peers: [])));

    expect(find.byType(Card), findsNothing);
  });
}
```

- [ ] **Step 9: Run test to verify it fails**

Run: `cd "$WT" && flutter test test/features/settings/presentation/skipped_peer_banner_test.dart`
Expected: FAIL - `Undefined class 'SkippedPeerBanner'`

- [ ] **Step 10: Implement the banner**

In `cloud_sync_page.dart`, add a public widget (public so the test can build it directly, mirroring how the page's other extracted pieces are tested):

```dart
/// Names the devices held back by the library-epoch fence on the last pull.
/// Mirrors the newer-schema banner: a conditional card with a zero-noise
/// resting state, rather than a standing device list.
class SkippedPeerBanner extends StatelessWidget {
  const SkippedPeerBanner({super.key, required this.peers});

  final List<({String? name, String shortId})> peers;

  @override
  Widget build(BuildContext context) {
    if (peers.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final labels = peers
        .map((p) =>
            p.name ??
            l10n.settings_cloudSync_peerNeedsAdopt_unnamedDevice(p.shortId))
        .toList();
    final list = labels.length == 1
        ? labels.single
        : '${labels.sublist(0, labels.length - 1).join(', ')} and ${labels.last}';
    final text = labels.length == 1
        ? l10n.settings_cloudSync_peerNeedsAdopt_banner(list)
        : l10n.settings_cloudSync_peerNeedsAdopt_bannerPlural(list);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        color: scheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.sync_problem, color: scheme.onSecondaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  // Card is secondaryContainer, and Material does not
                  // re-derive text colour from its background.
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSecondaryContainer,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

The English "and" joiner is a known simplification; the localized sentence carries the meaning and the joiner is not worth an ICU list format for two-to-three devices. Note this in the PR description.

- [ ] **Step 11: Mount the banner**

Immediately before the `if (syncState.newerSchemaPeerCount > 0)` block in the page's column, add:

```dart
          SkippedPeerBanner(peers: syncState.skippedPeerLabels),
```

- [ ] **Step 12: Run tests to verify they pass**

Run: `cd "$WT" && flutter test test/features/settings/presentation/skipped_peer_banner_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 13: Full verification and commit**

Run: `cd "$WT" && dart format . && flutter analyze && flutter test`
Expected: analyze clean; full suite green.

```bash
cd "$WT" && git add -A && git commit -m "Name the devices that still need to adopt the current library"
```

---

## Task 10: Final verification and PR

- [ ] **Step 1: Confirm the whole suite and formatting**

Run: `cd "$WT" && dart format --set-exit-if-changed . && flutter analyze && flutter test`
Expected: no formatting changes, analyze clean, full suite green.

- [ ] **Step 2: Confirm the four items by hand against the spec**

Re-read `docs/superpowers/specs/2026-08-11-652-reset-rebuild-ux-design.md` and confirm each of items 1-4 has landed, including the deliberate behavior change (sanitization now applies to epoch markers).

- [ ] **Step 3: Push and open the PR**

```bash
cd "$WT" && git push -u origin worktree-issue-652-reset-rebuild-ux
```

PR description must summarize: the four items, the `SyncManifest.deviceName` additive protocol field and its null-tolerant read, the epoch-marker sanitization behavior change, the `pullResultMessages` trim (and that it fixes an existing double-render), and the English "and" joiner simplification. Per CLAUDE.md, include no Claude Code attribution line and no session URL. Reference `Closes #652`.

---

## Self-Review

**Spec coverage:**

| Spec item | Task |
| --- | --- |
| Item 1 reset copy, 3 keys, 11 locales | 5 |
| Item 1 caveat (best-effort disconnect) documented | recorded in spec; no code change by design |
| Item 2 `SyncDeviceMetadata` + sanitization | 1 |
| Item 2 `LibraryReplaceIntent` + collapse 3 copies | 2 |
| Item 2 preflight, mint-then-sync, already-armed guard, no-provider error | 3 |
| Item 2 type-to-confirm dialog, safety backup, danger-zone tile | 4 |
| Item 3 first-contact hint, separate key | 6 |
| Item 4 manifest field + writer + service wiring | 7 |
| Item 4 reader name collection | 8 |
| Item 4 `SyncState` + banner + `pullResultMessages` trim | 9 |
| Epoch-marker sanitization behavior change covered by test | 1, 2 |

**Type consistency:** `SyncDeviceMetadata.resolve()` returns the named record `({String id, String? name, String? appVersion})` in Tasks 1, 2, 3, and 7. `skippedPeerNames` is `Map<String, String>` in both `ChangesetReadResult` (Task 8) and `SyncResult` (Task 8) and is read as such in Task 9. `SyncState.skippedPeerLabels` is `List<({String? name, String shortId})>` in Task 9 and `SkippedPeerBanner.peers` takes the same type.

**Path corrections applied during review:** the `pullResultMessages` tests live in `test/core/services/sync/sync_result_messages_test.dart` (Task 9 extends it, and must update its existing assertions about the two peer sentences rather than leaving them to fail), and `test/features/settings/presentation/widgets/reset_database_dialog_test.dart` already exists, so Task 5 extends it rather than creating it.
