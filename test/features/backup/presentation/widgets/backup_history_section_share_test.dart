// Share on a history row opens Save and Share for that backup (issue #3650).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/backup/presentation/widgets/backup_copy_sheet.dart';
import 'package:submersion/features/backup/presentation/widgets/backup_history_section.dart';
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

final _record = BackupRecord(
  id: 'r1',
  filename: 'submersion_backup_2026-10-27.db',
  timestamp: DateTime(2026, 10, 27, 19, 42),
  sizeBytes: 2048,
  location: BackupLocation.local,
  localPath: '/tmp/r1.db',
  diveCount: 4,
  siteCount: 2,
);

void main() {
  // The sheet's title is a date formatted against this process global.
  String? previousLocale;

  setUp(() {
    previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en';
  });

  tearDown(() => Intl.defaultLocale = previousLocale);

  testWidgets('Share on a row opens the copy sheet for that backup', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          backupServiceProvider.overrideWithValue(
            BackupService(
              dbAdapter: _NoopAdapter(),
              preferences: BackupPreferences(prefs),
            ),
          ),
          backupHistoryProvider.overrideWith((ref) async => [_record]),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(child: BackupHistorySection()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    // By value, not icon: on Windows and Linux (CI) the item reads "Save a
    // copy" with a save icon.
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is PopupMenuItem<String> && w.value == 'share',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BackupCopySheet), findsOneWidget);
    expect(find.textContaining('Backup from Oct 27, 2026'), findsOneWidget);
  });
}
