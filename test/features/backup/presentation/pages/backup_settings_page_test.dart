import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/domain/entities/backup_type.dart';
import 'package:submersion/features/backup/presentation/pages/backup_settings_page.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/backup/presentation/widgets/backup_history_tile.dart';
import 'package:submersion/features/backup/presentation/widgets/pre_migration_badge.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  // ---------------------------------------------------------------------------
  // PreMigrationBadge widget tests
  // ---------------------------------------------------------------------------
  group('PreMigrationBadge', () {
    testWidgets('shows v63 → v64 text for schema versions 63 and 64', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PreMigrationBadge(fromVersion: 63, toVersion: 64),
          ),
        ),
      );

      // The badge renders "v63 → v64" (arrow is U+2192)
      expect(find.text('v63 \u2192 v64'), findsOneWidget);
    });

    testWidgets('shows correct versions for different schema pair', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PreMigrationBadge(fromVersion: 10, toVersion: 11),
          ),
        ),
      );

      expect(find.text('v10 \u2192 v11'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Pin icon rendering tests — pump minimal widgets that mirror the tile logic
  // ---------------------------------------------------------------------------
  group('Pin icon rendering', () {
    /// Builds a widget that renders the pin icon the same way _buildHistoryTile
    /// does, so we can assert filled vs outlined.
    Widget buildPinIcon(bool pinned) {
      return MaterialApp(
        home: Scaffold(
          body: Icon(pinned ? Icons.push_pin : Icons.push_pin_outlined),
        ),
      );
    }

    testWidgets('pinned record shows filled push_pin icon', (tester) async {
      await tester.pumpWidget(buildPinIcon(true));

      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, Icons.push_pin);
    });

    testWidgets('unpinned record shows push_pin_outlined icon', (tester) async {
      await tester.pumpWidget(buildPinIcon(false));

      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, Icons.push_pin_outlined);
    });
  });

  // ---------------------------------------------------------------------------
  // BackupRecord entity tests — badge visibility logic
  // ---------------------------------------------------------------------------
  group('BackupRecord badge visibility', () {
    test('preMigration record has correct type and schema versions', () {
      final record = BackupRecord(
        id: 'pre-1',
        filename: 'pre_migration.db',
        timestamp: _kNow,
        sizeBytes: 1024,
        location: BackupLocation.local,
        type: BackupType.preMigration,
        fromSchemaVersion: 63,
        toSchemaVersion: 64,
        pinned: true,
      );

      expect(record.type, BackupType.preMigration);
      expect(record.fromSchemaVersion, 63);
      expect(record.toSchemaVersion, 64);
      expect(record.pinned, isTrue);
    });

    test('manual record has type manual and no schema versions', () {
      final record = BackupRecord(
        id: 'manual-1',
        filename: 'manual.db',
        timestamp: _kNow,
        sizeBytes: 2048,
        location: BackupLocation.local,
        pinned: false,
      );

      expect(record.type, BackupType.manual);
      expect(record.fromSchemaVersion, isNull);
      expect(record.toSchemaVersion, isNull);
      expect(record.pinned, isFalse);
    });

    test('only preMigration type triggers badge condition', () {
      final preMig = BackupRecord(
        id: 'pre-1',
        filename: 'pre.db',
        timestamp: _kNow,
        sizeBytes: 512,
        location: BackupLocation.local,
        type: BackupType.preMigration,
        fromSchemaVersion: 63,
        toSchemaVersion: 64,
      );

      final manual = BackupRecord(
        id: 'man-1',
        filename: 'man.db',
        timestamp: _kNow,
        sizeBytes: 512,
        location: BackupLocation.local,
      );

      // The page shows the badge when type == BackupType.preMigration
      expect(preMig.type == BackupType.preMigration, isTrue);
      expect(manual.type == BackupType.preMigration, isFalse);
    });

    test(
      'preMigration record without schema versions fails badge render gate',
      () {
        final incomplete = BackupRecord(
          id: 'pre-incomplete',
          filename: 'pre.db',
          timestamp: _kNow,
          sizeBytes: 512,
          location: BackupLocation.local,
          type: BackupType.preMigration,
        );

        // Badge is rendered only when all three conditions hold:
        //   type == preMigration AND fromSchemaVersion != null AND
        //   toSchemaVersion != null.
        final shouldRenderBadge =
            incomplete.type == BackupType.preMigration &&
            incomplete.fromSchemaVersion != null &&
            incomplete.toSchemaVersion != null;
        expect(shouldRenderBadge, isFalse);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // BackupSettingsPage integration — pin toggle success + error paths
  // ---------------------------------------------------------------------------
  group('BackupSettingsPage pin toggle', () {
    late Directory tempDir;
    late SharedPreferences prefs;
    late BackupPreferences backupPrefs;
    late BackupRecord seededRecord;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('bsp_test_');
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      backupPrefs = BackupPreferences(prefs);
      seededRecord = BackupRecord(
        id: 'rec-1',
        filename: 'manual.db',
        timestamp: _kNow,
        sizeBytes: 2048,
        location: BackupLocation.local,
        localPath: '${tempDir.path}/manual.db',
        diveCount: 0,
        siteCount: 0,
      );
      await backupPrefs.addRecord(seededRecord);
    });

    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    Widget buildApp(BackupService service) {
      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          backupServiceProvider.overrideWithValue(service),
          cloudStorageProviderProvider.overrideWithValue(null),
          backupHistoryProvider.overrideWith(
            (ref) async => backupPrefs.getHistory(),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BackupSettingsPage(),
        ),
      );
    }

    testWidgets('tapping outlined pin flips record to pinned', (tester) async {
      final service = BackupService(
        dbAdapter: _FakeBackupDatabaseAdapter(),
        preferences: backupPrefs,
        cloudProvider: null,
      );

      await tester.pumpWidget(buildApp(service));
      await tester.pumpAndSettle();

      expect(find.byType(BackupHistoryTile), findsOneWidget);
      await tester.tap(find.byIcon(Icons.push_pin_outlined));
      await tester.pumpAndSettle();

      expect(backupPrefs.getHistory().single.pinned, isTrue);
    });

    testWidgets('tapping filled pin flips pinned record back to unpinned', (
      tester,
    ) async {
      // Seed as already pinned
      await backupPrefs.updateRecord(seededRecord.copyWith(pinned: true));

      final service = BackupService(
        dbAdapter: _FakeBackupDatabaseAdapter(),
        preferences: backupPrefs,
        cloudProvider: null,
      );

      await tester.pumpWidget(buildApp(service));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.push_pin));
      await tester.pumpAndSettle();

      expect(backupPrefs.getHistory().single.pinned, isFalse);
    });

    testWidgets('pin failure shows SnackBar with user-facing message', (
      tester,
    ) async {
      final service = _ThrowingPinBackupService(
        dbAdapter: _FakeBackupDatabaseAdapter(),
        preferences: backupPrefs,
      );

      await tester.pumpWidget(buildApp(service));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.push_pin_outlined));
      await tester.pump(); // let snackbar enter
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(SnackBar), findsOneWidget);
      // Pin state did not change: error path kept the record unpinned.
      expect(backupPrefs.getHistory().single.pinned, isFalse);
    });
  });
}

// Fixed timestamp used across tests.
final _kNow = DateTime(2024, 6, 1, 12, 0, 0);

/// Minimal BackupDatabaseAdapter fake — unused methods throw loud errors.
class _FakeBackupDatabaseAdapter implements BackupDatabaseAdapter {
  @override
  Future<void> backup(String destinationPath) async =>
      throw UnimplementedError('not used');

  @override
  Future<void> restore(String backupPath) async =>
      throw UnimplementedError('not used');

  @override
  Future<String> get databasePath async => '/fake/db/path';

  @override
  AppDatabase get database =>
      throw UnimplementedError('Fake does not support direct queries');
}

/// BackupService override that throws on pin/unpin to exercise the error path.
class _ThrowingPinBackupService extends BackupService {
  _ThrowingPinBackupService({
    required super.dbAdapter,
    required super.preferences,
  });

  @override
  Future<void> pinBackup(String id) async =>
      throw StateError('simulated pin failure');

  @override
  Future<void> unpinBackup(String id) async =>
      throw StateError('simulated unpin failure');
}
