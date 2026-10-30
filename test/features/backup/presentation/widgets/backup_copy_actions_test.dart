import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/backup/presentation/widgets/backup_copy_actions.dart';
import 'package:submersion/features/backup/presentation/widgets/backup_copy_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

class _NoopAdapter implements BackupDatabaseAdapter {
  @override
  Future<void> backup(String destinationPath, {String? note}) async {}

  @override
  Future<void> restore(
    String backupPath, {
    void Function(int, int)? onMigrationProgress,
  }) async {}

  @override
  Future<String> get databasePath async => '/noop';

  @override
  AppDatabase get database => throw UnimplementedError();

  @override
  String? get databaseKeyHex => null;
}

class _LockedService extends BackupService {
  _LockedService(
    BackupPreferences prefs, {
    required this.locked,
    this.probeFails = false,
  }) : super(dbAdapter: _NoopAdapter(), preferences: prefs);

  final bool locked;

  /// The header read fails, as when a security-scoped folder lost access.
  final bool probeFails;

  @override
  Future<bool> isDeviceLockedSafetyCopy(BackupRecord record) async {
    if (probeFails) {
      throw const FileSystemException('Operation not permitted');
    }
    return locked;
  }
}

final _record = BackupRecord(
  id: 'r1',
  filename: '20261012-081200000-v300-v301.db',
  timestamp: DateTime(2026, 10, 12, 8, 12),
  sizeBytes: 2048,
  location: BackupLocation.local,
  localPath: '/tmp/r1.db',
);

void main() {
  Future<void> openSheet(
    WidgetTester tester, {
    required bool locked,
    bool probeFails = false,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          backupServiceProvider.overrideWithValue(
            _LockedService(
              BackupPreferences(prefs),
              locked: locked,
              probeFails: probeFails,
            ),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => showBackupCopySheet(context, ref, _record),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('opens the sheet with the device-locked line for a locked copy', (
    tester,
  ) async {
    await openSheet(tester, locked: true);

    expect(find.byType(BackupCopySheet), findsOneWidget);
    expect(
      find.textContaining('can only be restored on this device'),
      findsOneWidget,
    );
  });

  testWidgets('opens the sheet without the line for an ordinary backup', (
    tester,
  ) async {
    await openSheet(tester, locked: false);

    expect(find.byType(BackupCopySheet), findsOneWidget);
    expect(
      find.textContaining('can only be restored on this device'),
      findsNothing,
    );
  });

  testWidgets('still opens the sheet when the safety-copy probe fails', (
    tester,
  ) async {
    await openSheet(tester, locked: true, probeFails: true);

    expect(find.byType(BackupCopySheet), findsOneWidget);
    expect(
      find.textContaining('can only be restored on this device'),
      findsNothing,
    );
  });
}
