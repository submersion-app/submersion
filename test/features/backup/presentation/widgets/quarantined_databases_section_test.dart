import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/backup/data/services/quarantined_database_service.dart';
import 'package:submersion/features/backup/domain/entities/quarantined_database.dart';
import 'package:submersion/features/backup/domain/entities/restore_mode.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/backup/presentation/providers/quarantined_database_providers.dart';
import 'package:submersion/features/backup/presentation/widgets/quarantined_databases_section.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _NoopAdapter implements BackupDatabaseAdapter {
  @override
  Future<void> backup(String destinationPath) async {}

  @override
  Future<void> restore(
    String backupPath, {
    void Function(int, int)? onMigrationProgress,
  }) async {}

  @override
  Future<String> get databasePath async => '/db/submersion.db';

  @override
  AppDatabase get database => throw UnimplementedError();

  @override
  String? get databaseKeyHex => null;
}

/// Records database-copy restores, then fails them so the test never runs
/// the post-restore fix-ups (which need a real database).
class _RecordingBackupService extends BackupService {
  _RecordingBackupService(BackupPreferences prefs)
    : super(dbAdapter: _NoopAdapter(), preferences: prefs);

  final restored = <(String, RestoreMode)>[];

  @override
  Future<void> restoreFromDatabaseCopy(
    String path, {
    RestoreMode mode = RestoreMode.merge,
    void Function(int currentStep, int totalSteps)? onMigrationProgress,
  }) async {
    restored.add((path, mode));
    throw const BackupException('stop here');
  }
}

class _FakeQuarantineService extends QuarantinedDatabaseService {
  _FakeQuarantineService(this.copies)
    : super(databasePath: () async => '/db/submersion.db', keyHex: () => null);

  final List<QuarantinedDatabase> copies;
  final deleted = <String>[];
  bool failDelete = false;

  @override
  Future<List<QuarantinedDatabase>> find() async => List.of(copies);

  @override
  Future<void> delete(QuarantinedDatabase copy) async {
    if (failDelete) throw StateError('locked');
    deleted.add(copy.path);
    copies.removeWhere((c) => c.path == copy.path);
  }
}

QuarantinedDatabase _copy({
  String stamp = '20260926T134501Z',
  QuarantineKind kind = QuarantineKind.preRestore,
  QuarantinedDatabaseStatus status = QuarantinedDatabaseStatus.restorable,
  int? schemaVersion = 70,
}) {
  final tag = kind == QuarantineKind.preRestore
      ? 'pre-restore'
      : 'restore-rejected';
  final path = '/db/submersion.db.$tag.$stamp';
  return QuarantinedDatabase(
    path: path,
    kind: kind,
    quarantinedAt: DateTime.utc(2026, 9, 26, 13, 45, 1),
    files: [path],
    sizeBytes: 2048,
    status: status,
    schemaVersion: schemaVersion,
  );
}

void main() {
  late SharedPreferences prefs;
  late _RecordingBackupService backupService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    backupService = _RecordingBackupService(BackupPreferences(prefs));
  });

  Future<void> pump(
    WidgetTester tester,
    QuarantinedDatabaseService service, {
    Future<List<QuarantinedDatabase>> Function()? load,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localeProvider.overrideWithValue('en'),
          sharedPreferencesProvider.overrideWithValue(prefs),
          backupServiceProvider.overrideWithValue(backupService),
          cloudStorageProviderProvider.overrideWithValue(null),
          quarantinedDatabaseServiceProvider.overrideWithValue(service),
          if (load != null)
            quarantinedDatabasesProvider.overrideWith((ref) => load()),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(child: QuarantinedDatabasesSection()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
  }

  testWidgets('renders nothing when no copy was set aside', (tester) async {
    await pump(tester, _FakeQuarantineService([]));

    expect(find.text('Set-aside databases'), findsNothing);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('lists a restorable copy with its size and version', (
    tester,
  ) async {
    await pump(tester, _FakeQuarantineService([_copy()]));

    expect(find.text('Set-aside databases'), findsOneWidget);
    expect(find.text('Dive log from before a restore'), findsOneWidget);
    expect(find.textContaining('2.0 KB'), findsOneWidget);
    expect(find.textContaining('database v70'), findsOneWidget);

    await openMenu(tester);
    expect(find.text('Restore'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('offers only delete for a copy this build cannot open', (
    tester,
  ) async {
    await pump(
      tester,
      _FakeQuarantineService([
        _copy(
          kind: QuarantineKind.restoreRejected,
          status: QuarantinedDatabaseStatus.unreadable,
          schemaVersion: null,
        ),
      ]),
    );

    expect(find.text('Dive log replaced during a recovery'), findsOneWidget);
    expect(find.textContaining('Cannot be opened here'), findsOneWidget);
    expect(find.textContaining('database v'), findsNothing);

    await openMenu(tester);
    expect(find.text('Restore'), findsNothing);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('names a newer-build copy and a journal-only copy', (
    tester,
  ) async {
    await pump(
      tester,
      _FakeQuarantineService([
        _copy(
          status: QuarantinedDatabaseStatus.needsNewerApp,
          schemaVersion: 999,
        ),
        _copy(
          stamp: '20260101T000000Z',
          status: QuarantinedDatabaseStatus.incomplete,
          schemaVersion: null,
        ),
      ]),
    );

    expect(find.text('Needs a newer version of Submersion'), findsOneWidget);
    expect(find.textContaining('Only journal files remain'), findsOneWidget);
  });

  testWidgets('restores a copy through the confirmation dialog', (
    tester,
  ) async {
    final copy = _copy();
    await pump(tester, _FakeQuarantineService([copy]));

    await openMenu(tester);
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();
    expect(find.text('Restore Backup'), findsOneWidget);

    await tester.tap(find.text('Restore').last);
    await tester.pumpAndSettle();

    expect(backupService.restored, [(copy.path, RestoreMode.merge)]);
  });

  testWidgets('re-reads the list after a restore attempt', (tester) async {
    final service = _FakeQuarantineService([_copy()]);
    await pump(tester, service);
    // What the folder holds once the attempt has touched the copy.
    service.copies[0] = _copy().copyWith(sizeBytes: 5 * 1024);

    await openMenu(tester);
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('5.0 KB'), findsOneWidget);
  });

  testWidgets('deletes a copy after confirmation and refreshes the list', (
    tester,
  ) async {
    final service = _FakeQuarantineService([_copy()]);
    await pump(tester, service);

    await openMenu(tester);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this database copy?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(service.deleted, [_copy().path]);
    expect(find.text('Database copy deleted'), findsOneWidget);
    expect(find.text('Set-aside databases'), findsNothing);
  });

  testWidgets('keeps the copy when the diver cancels', (tester) async {
    final service = _FakeQuarantineService([_copy()]);
    await pump(tester, service);

    await openMenu(tester);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(service.deleted, isEmpty);
    expect(find.text('Dive log from before a restore'), findsOneWidget);
  });

  testWidgets('reports a failed delete', (tester) async {
    final service = _FakeQuarantineService([_copy()])..failDelete = true;
    await pump(tester, service);

    await openMenu(tester);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Could not delete the database copy.'), findsOneWidget);
    expect(find.text('Dive log from before a restore'), findsOneWidget);
  });

  testWidgets('says so when the folder cannot be read', (tester) async {
    await pump(
      tester,
      _FakeQuarantineService([]),
      load: () async => throw StateError('no folder'),
    );

    expect(find.text('Set-aside databases'), findsOneWidget);
    expect(
      find.text('Could not check the database folder for set-aside copies.'),
      findsOneWidget,
    );
  });
}
