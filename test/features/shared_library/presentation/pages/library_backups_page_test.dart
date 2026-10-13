import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';
import 'package:submersion/core/services/export/shared/file_export_utils.dart';
import 'package:submersion/core/services/shared_library/backup/library_backup_archive.dart';
import 'package:submersion/core/services/shared_library/backup/library_backup_record.dart';
import 'package:submersion/core/services/shared_library/backup/library_backup_service.dart';
import 'package:submersion/core/services/shared_library/backup/library_restore_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_membership_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/shared_library/presentation/pages/library_backups_page.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_sync_notifier.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

import '../../../../helpers/global_test_defaults.dart';
import '../../../../helpers/mock_file_picker_platform.dart';
import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

final _manual = LibraryBackupRecord(
  backupId: 'b1',
  libraryId: 'L',
  fileName: 'submersion-sites-site-sync-2026-10-01-100000.zip',
  createdAt: DateTime.utc(2026, 10, 1, 10),
  note: 'Before the survey',
  siteCount: 12,
  sizeBytes: 2048,
  localPath: p.join(Directory.systemTemp.path, 'b1.zip'),
  inStorage: true,
);

final _auto = LibraryBackupRecord(
  backupId: 'b2',
  libraryId: 'L',
  fileName: 'submersion-sites-site-sync-2026-10-02-100000.zip',
  createdAt: DateTime.utc(2026, 10, 2, 10),
  automatic: true,
  pinned: true,
  siteCount: 13,
  sizeBytes: 4096,
  inStorage: true,
);

SharedLibraryMembershipService _noMemberships() =>
    SharedLibraryMembershipService(
      store: SharedLibraryStore(),
      transportFor: ({required account, required prefix}) =>
          throw UnimplementedError(),
    );

/// Records each action instead of touching storage.
class _FakeBackups extends LibraryBackupService {
  _FakeBackups(this.records, {this.copies})
    : super(
        store: SharedLibraryStore(),
        memberships: _noMemberships(),
        backupsDirectory: () async => '',
      );

  List<LibraryBackupRecord> records;

  /// Where [localCopy] says the zips are.
  final String? copies;
  final calls = <String>[];
  bool refuseImport = false;
  List<int>? importedBytes;

  @override
  Future<List<LibraryBackupRecord>> list({required String libraryId}) async =>
      records;

  @override
  Future<void> setPinned(
    String backupId, {
    required String libraryId,
    required String diverId,
    required bool pinned,
  }) async {
    calls.add('pin:$backupId:$pinned');
    records = [
      for (final r in records)
        r.backupId == backupId ? r.copyWith(pinned: pinned) : r,
    ];
  }

  @override
  Future<void> delete(
    String backupId, {
    required String libraryId,
    required String diverId,
    required bool fromDevice,
    required bool fromStorage,
  }) async => calls.add('delete:$backupId:$fromDevice:$fromStorage');

  @override
  Future<LibraryBackupRecord> backUp({
    required String libraryId,
    required String diverId,
    String note = '',
    bool automatic = false,
    bool beforeRestore = false,
  }) async {
    calls.add('backUp:$note');
    return _manual;
  }

  @override
  Future<String> localCopy(
    String backupId, {
    required String libraryId,
  }) async => p.join(copies ?? Directory.systemTemp.path, '$backupId.zip');

  @override
  Future<LibraryBackupRecord> import({
    required String libraryId,
    required String path,
  }) async {
    if (refuseImport) throw const BackupRefusedError('otherLibrary');
    calls.add('import:$path');
    importedBytes = File(path).existsSync()
        ? File(path).readAsBytesSync()
        : null;
    return _manual;
  }
}

class _FakeRestore extends LibraryRestoreService {
  _FakeRestore({this.oldKeyId})
    : super(
        store: SharedLibraryStore(),
        memberships: _noMemberships(),
        backups: _FakeBackups(const []),
      );

  /// When set, a restore without the old secret asks for it.
  final String? oldKeyId;
  final calls = <String>[];

  @override
  Future<void> restore({
    required String libraryId,
    required String diverId,
    required String backupId,
    String? oldSecret,
  }) async {
    if (oldKeyId != null && oldSecret == null) {
      throw BackupNeedsOldKeyError(oldKeyId!);
    }
    calls.add('restore:$backupId:${oldSecret ?? ''}');
  }
}

/// Records syncs instead of reaching storage.
class _FakeSync extends SharedLibrarySyncNotifier {
  _FakeSync(super.ref);

  static final synced = <String>[];

  @override
  Future<SharedLibrarySyncResult> syncOne(String libraryId) async {
    synced.add(libraryId);
    return const SharedLibrarySyncResult(
      status: SharedLibrarySyncStatus.success,
    );
  }
}

class _FakeShare extends SharePlatform with MockPlatformInterfaceMixin {
  final calls = <ShareParams>[];

  @override
  Future<ShareResult> share(ShareParams params) async {
    calls.add(params);
    return const ShareResult('ok', ShareResultStatus.success);
  }
}

Future<Widget> _page({
  required _FakeBackups backups,
  _FakeRestore? restore,
  SharedLibraryRole role = SharedLibraryRole.owner,
}) async => testApp(
  overrides: [
    ...await getBaseOverrides(),
    libraryRoleProvider('L').overrideWith((ref) async => role),
    currentMembershipProvider('L').overrideWith(
      (ref) async => const SharedLibraryMembership(
        id: 'ms',
        diverId: 'd',
        libraryId: 'L',
        memberId: 'me',
        displayName: 'Ann',
        libraryName: 'Reef Survey',
        backendKind: 's3',
      ),
    ),
    libraryBackupServiceProvider.overrideWithValue(backups),
    sharedLibrarySyncProvider.overrideWith(_FakeSync.new),
    libraryRestoreServiceProvider.overrideWithValue(restore ?? _FakeRestore()),
  ],
  locale: const Locale('en'),
  child: const LibraryBackupsPage(libraryId: 'L'),
);

Future<void> _openMenu(WidgetTester tester, int index, String item) async {
  await tester.tap(find.byType(PopupMenuButton<String>).at(index));
  await tester.pumpAndSettle();
  await tester.tap(find.text(item).last);
  await tester.pumpAndSettle();
}

void main() {
  setUp(_FakeSync.synced.clear);

  testWidgets('rows show the date, note, sites, size, kind and place', (
    tester,
  ) async {
    await tester.pumpWidget(
      await _page(backups: _FakeBackups([_auto, _manual])),
    );
    await tester.pumpAndSettle();
    const units = UnitFormatter(AppSettings());
    final l10n = AppLocalizationsEn();
    expect(
      find.text(units.formatDateTime(_manual.createdAt.toLocal(), l10n: l10n)),
      findsOneWidget,
    );
    expect(find.text('Before the survey'), findsOneWidget);
    expect(find.text('Sites: 12 · 2.0 KB'), findsOneWidget);
    expect(find.text('Automatic'), findsOneWidget);
    expect(find.text('On this device and in storage'), findsOneWidget);
    expect(find.text('In storage'), findsOneWidget);
    expect(find.byIcon(Icons.push_pin), findsOneWidget);
    expect(find.byIcon(Icons.push_pin_outlined), findsOneWidget);
  });

  testWidgets('the pin toggles', (tester) async {
    final backups = _FakeBackups([_manual]);
    await tester.pumpWidget(await _page(backups: backups));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.push_pin_outlined));
    await tester.pumpAndSettle();
    expect(backups.calls, ['pin:b1:true']);
    expect(find.byIcon(Icons.push_pin), findsOneWidget);
  });

  testWidgets('deleting a backup kept in both places asks where', (
    tester,
  ) async {
    final backups = _FakeBackups([_manual]);
    await tester.pumpWidget(await _page(backups: backups));
    await tester.pumpAndSettle();
    await _openMenu(tester, 0, 'Delete');
    expect(find.text('Delete this backup from where?'), findsOneWidget);
    await tester.tap(find.text('In storage').last);
    await tester.pumpAndSettle();
    expect(backups.calls, ['delete:b1:false:true']);
  });

  testWidgets('deleting a backup kept in one place asks to confirm', (
    tester,
  ) async {
    final backups = _FakeBackups([_auto]);
    await tester.pumpWidget(await _page(backups: backups));
    await tester.pumpAndSettle();
    await _openMenu(tester, 0, 'Delete');
    expect(find.text('Delete this backup?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(backups.calls, ['delete:b2:false:true']);
  });

  testWidgets('restore asks first, naming the date, then restores', (
    tester,
  ) async {
    final restore = _FakeRestore();
    await tester.pumpWidget(
      await _page(backups: _FakeBackups([_manual]), restore: restore),
    );
    await tester.pumpAndSettle();
    await _openMenu(tester, 0, 'Restore');
    final date = const UnitFormatter(
      AppSettings(),
    ).formatDateTime(_manual.createdAt.toLocal(), l10n: AppLocalizationsEn());
    expect(find.textContaining(date), findsWidgets);
    expect(restore.calls, isEmpty);
    await tester.tap(find.widgetWithText(FilledButton, 'Restore'));
    await tester.pumpAndSettle();
    expect(restore.calls, ['restore:b1:']);
    expect(_FakeSync.synced, ['L']);
    expect(find.text('Library restored'), findsOneWidget);
  });

  testWidgets('a backup under an earlier key asks for it and retries', (
    tester,
  ) async {
    final restore = _FakeRestore(oldKeyId: 'k0');
    await tester.pumpWidget(
      await _page(backups: _FakeBackups([_manual]), restore: restore),
    );
    await tester.pumpAndSettle();
    await _openMenu(tester, 0, 'Restore');
    await tester.tap(find.widgetWithText(FilledButton, 'Restore'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('secret-field')), 'old words');
    await tester.tap(find.widgetWithText(FilledButton, 'Unlock'));
    await tester.pumpAndSettle();
    expect(restore.calls, ['restore:b1:old words']);
  });

  testWidgets('back up now takes a note', (tester) async {
    final backups = _FakeBackups([]);
    await tester.pumpWidget(await _page(backups: backups));
    await tester.pumpAndSettle();
    expect(find.textContaining('No backups yet'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Back up now'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('backup-note')), 'Season end');
    await tester.tap(find.widgetWithText(FilledButton, 'Back up now').last);
    await tester.pumpAndSettle();
    expect(backups.calls, ['backUp:Season end']);
  });

  testWidgets('import adds a picked file', (tester) async {
    final original = FilePickerPlatform.instance;
    addTearDown(() => FilePickerPlatform.instance = original);
    FilePickerPlatform.instance = MockFilePickerPlatform()
      ..pickFilesResult = [
        FakePlatformFile(p.join(Directory.systemTemp.path, 'backup.zip')),
      ];
    final backups = _FakeBackups([]);
    await tester.pumpWidget(await _page(backups: backups));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Import a backup'));
    await tester.pumpAndSettle();
    expect(backups.calls, [
      'import:${p.join(Directory.systemTemp.path, 'backup.zip')}',
    ]);
  });

  testWidgets('a picked file with no path is imported from its bytes', (
    tester,
  ) async {
    final original = FilePickerPlatform.instance;
    addTearDown(() => FilePickerPlatform.instance = original);
    FilePickerPlatform.instance = MockFilePickerPlatform()
      ..pickFilesResult = [
        FakePlatformFile.contentUri(
          Uri.parse('content://downloads/backup.zip'),
          name: 'backup.zip',
          bytes: Uint8List.fromList([1, 2, 3]),
        ),
      ];
    final backups = _FakeBackups([]);
    await tester.pumpWidget(await _page(backups: backups));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Import a backup'));
    // The temporary copy is written with real dart:io: give it the real
    // event loop until the import lands.
    for (var i = 0; i < 50 && backups.calls.isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(backups.calls.single, endsWith('backup.zip'));
    expect(backups.importedBytes, [1, 2, 3]);
  });

  testWidgets('an import that is no backup of the library says so', (
    tester,
  ) async {
    final original = FilePickerPlatform.instance;
    addTearDown(() => FilePickerPlatform.instance = original);
    FilePickerPlatform.instance = MockFilePickerPlatform()
      ..pickFilesResult = [
        FakePlatformFile(p.join(Directory.systemTemp.path, 'other.zip')),
      ];
    final backups = _FakeBackups([])..refuseImport = true;
    await tester.pumpWidget(await _page(backups: backups));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Import a backup'));
    await tester.pumpAndSettle();
    expect(
      find.text('That file is not a backup of this library.'),
      findsOneWidget,
    );
  });

  testWidgets('export shares the backup file', (tester) async {
    final original = SharePlatform.instance;
    addTearDown(() => SharePlatform.instance = original);
    final share = _FakeShare();
    SharePlatform.instance = share;
    await tester.pumpWidget(await _page(backups: _FakeBackups([_manual])));
    await tester.pumpAndSettle();
    await _openMenu(tester, 0, 'Export');
    expect(
      share.calls.single.files!.single.path,
      p.join(Directory.systemTemp.path, 'b1.zip'),
    );
  });

  testWidgets('without a file share sheet export saves through a dialog', (
    tester,
  ) async {
    debugCanShareFiles = false;
    addTearDown(applyGlobalTestDefaults);
    final originalPicker = FilePickerPlatform.instance;
    addTearDown(() => FilePickerPlatform.instance = originalPicker);
    final picker = MockFilePickerPlatform();
    FilePickerPlatform.instance = picker;
    final dir = Directory.systemTemp.createTempSync('backup_export_');
    addTearDown(() => dir.deleteSync(recursive: true));
    File(p.join(dir.path, 'b1.zip')).writeAsBytesSync([1, 2, 3]);
    await tester.pumpWidget(
      await _page(backups: _FakeBackups([_manual], copies: dir.path)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export').last);
    // The zip is read from disk: real time for it.
    for (var i = 0; i < 50 && picker.lastSavedFileName == null; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(picker.lastSavedFileName, 'b1.zip');
    expect(picker.lastSavedBytes, [1, 2, 3]);
  });

  testWidgets('a reader sees only that owners manage backups', (tester) async {
    await tester.pumpWidget(
      await _page(
        backups: _FakeBackups([_manual]),
        role: SharedLibraryRole.reader,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Only owners manage backups.'), findsOneWidget);
    expect(find.text('Before the survey'), findsNothing);
    expect(find.text('Back up now'), findsNothing);
  });
}
