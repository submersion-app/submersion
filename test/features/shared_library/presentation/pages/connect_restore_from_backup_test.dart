import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/features/shared_library/presentation/widgets/library_location_fields.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/shared_library/backup/library_backup_archive.dart';
import 'package:submersion/core/services/shared_library/backup/library_backup_service.dart';
import 'package:submersion/core/services/shared_library/backup/library_restore_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_membership_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/shared_library/shared_library_transport.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/shared_library/presentation/pages/connect_shared_library_page.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_sync_notifier.dart';

import '../../../../helpers/fake_cloud_storage_provider.dart';
import '../../../../helpers/account_groups_fixture.dart';
import '../../../../helpers/mock_file_picker_platform.dart';
import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

SharedLibraryMembershipService _memberships() => SharedLibraryMembershipService(
  store: SharedLibraryStore(),
  transportFor: ({required account, required prefix}) async =>
      SharedLibraryTransport(FakeCloudStorageProvider(), prefix: prefix),
);

/// Probes find an empty folder.
class _EmptyFolders extends SharedLibraryMembershipService {
  _EmptyFolders()
    : super(
        store: SharedLibraryStore(),
        transportFor: ({required account, required prefix}) async =>
            SharedLibraryTransport(FakeCloudStorageProvider(), prefix: prefix),
      );

  @override
  Future<LibraryProbe> probe({
    required ConnectedAccount account,
    required String prefix,
  }) async => const LibraryProbe(exists: false);
}

/// Records each restore. [needsKey] asks for a secret until 'pw' is given;
/// [refuse] refuses the file; otherwise [oldStillThere] is reported.
class _FakeRestore extends LibraryRestoreService {
  _FakeRestore({
    this.needsKey = false,
    this.refuse = false,
    this.oldStillThere = false,
  }) : super(
         store: SharedLibraryStore(),
         memberships: _memberships(),
         backups: LibraryBackupService(
           store: SharedLibraryStore(),
           memberships: _memberships(),
           backupsDirectory: () async => '',
         ),
       );

  final bool needsKey;
  final bool refuse;
  final bool oldStillThere;
  final calls = <String>[];

  @override
  Future<RestoredLibrary> restoreInto({
    required ConnectedAccount account,
    required String prefix,
    required String diverId,
    required String displayName,
    required String path,
    String? secret,
  }) async {
    calls.add('$prefix|${p.basename(path)}|$displayName|${secret ?? ''}');
    if (refuse) throw const BackupRefusedError('signature');
    if (needsKey && secret != 'pw') throw const BackupNeedsOldKeyError('k');
    return RestoredLibrary(
      library: const SharedLibrary(
        id: 'L',
        name: 'Reef Survey',
        connectedAccountId: 'acc',
        prefix: 'moved',
      ),
      oldStillThere: oldStillThere,
    );
  }
}

/// Records syncs: a real one would outlive the test and hold the
/// process-wide SyncCoordinator for the next file in the bundle.
class _RecordingSync extends SharedLibrarySyncNotifier {
  _RecordingSync(super.ref);

  @override
  Future<SharedLibrarySyncResult> syncOne(String libraryId) async =>
      const SharedLibrarySyncResult(status: SharedLibrarySyncStatus.success);
}

ConnectedAccount _bucket() => ConnectedAccount(
  id: 'acc',
  kind: AccountKind.s3,
  label: 'Survey bucket',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  late Directory dir;
  late String backupPath;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('connect_restore_');
    backupPath = p.join(dir.path, 'backup.zip');
    File(backupPath).writeAsBytesSync([1, 2, 3]);
  });

  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> openEmptyFolder(
    WidgetTester tester,
    _FakeRestore restore,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 1400);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final original = FilePickerPlatform.instance;
    addTearDown(() => FilePickerPlatform.instance = original);
    FilePickerPlatform.instance = MockFilePickerPlatform()
      ..pickFilesResult = [FakePlatformFile(backupPath)];
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...await getBaseOverrides(),
          accountGroupsProvider.overrideWith(
            (ref) async => signedInGroupsOf([_bucket()]),
          ),
          accountGroupsOfKindsProvider(
            libraryKindsKey,
          ).overrideWith((ref) async => signedInGroupsOf([_bucket()])),
          sharedLibraryMembershipServiceProvider.overrideWithValue(
            _EmptyFolders(),
          ),
          libraryRestoreServiceProvider.overrideWithValue(restore),
          sharedLibrarySyncProvider.overrideWith(_RecordingSync.new),
          validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd'),
          currentDiverProvider.overrideWith(
            (ref) async => Diver(
              id: 'd',
              name: 'Ann',
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
            ),
          ),
        ],
        locale: const Locale('en'),
        child: const ConnectSharedLibraryPage(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('library-prefix')), 'moved');
    await tester.tap(find.text('Check location'));
    await tester.pumpAndSettle();
  }

  Future<void> restoreFromFile(WidgetTester tester) async {
    final button = find.text('Restore from a backup file');
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('an empty folder offers a restore from a backup file', (
    tester,
  ) async {
    final restore = _FakeRestore(oldStillThere: true);
    await openEmptyFolder(tester, restore);
    await restoreFromFile(tester);
    expect(restore.calls, ['moved|backup.zip|Ann|']);
    expect(find.textContaining('still in its old folder too'), findsOneWidget);
  });

  testWidgets('an encrypted backup asks for its passphrase and retries', (
    tester,
  ) async {
    final restore = _FakeRestore(needsKey: true);
    await openEmptyFolder(tester, restore);
    await restoreFromFile(tester);
    expect(
      find.text(
        'This backup is encrypted. Enter its passphrase or recovery code.',
      ),
      findsOneWidget,
    );
    await tester.enterText(find.byKey(const Key('secret-field')), 'pw');
    await tester.tap(find.widgetWithText(FilledButton, 'Unlock'));
    await tester.pumpAndSettle();
    expect(restore.calls, ['moved|backup.zip|Ann|', 'moved|backup.zip|Ann|pw']);
  });

  testWidgets('a file that is no owner-made backup says so', (tester) async {
    final restore = _FakeRestore(refuse: true);
    await openEmptyFolder(tester, restore);
    await restoreFromFile(tester);
    expect(
      find.text('That file is not a library backup made by an owner.'),
      findsOneWidget,
    );
  });
}
