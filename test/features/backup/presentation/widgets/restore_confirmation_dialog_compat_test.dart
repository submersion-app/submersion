import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/domain/entities/backup_type.dart';
import 'package:submersion/features/backup/presentation/widgets/restore_confirmation_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

BackupRecord _preMigration({
  required int fromVersion,
  required int toVersion,
  String appVersion = '1.5.9.1000',
}) {
  return BackupRecord(
    id: 'r',
    filename: 'pre.db',
    timestamp: DateTime(2026, 4, 12, 8, 12),
    sizeBytes: 1024,
    location: BackupLocation.local,
    localPath: '/tmp/pre.db',
    type: BackupType.preMigration,
    appVersion: appVersion,
    fromSchemaVersion: fromVersion,
    toSchemaVersion: toVersion,
  );
}

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('green path: current == from — Restore button, no warning text', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        RestoreConfirmationDialog(
          record: _preMigration(fromVersion: 63, toVersion: 64),
          currentSchemaVersion: 63,
        ),
      ),
    );
    expect(find.text('Restore'), findsOneWidget);
    expect(find.text('Restore anyway'), findsNothing);
    expect(find.textContaining('will re-run'), findsNothing);
    expect(find.textContaining('database schema matches'), findsOneWidget);
  });

  testWidgets('warning path: current > from — Restore anyway + warning text', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        RestoreConfirmationDialog(
          record: _preMigration(fromVersion: 63, toVersion: 64),
          currentSchemaVersion: 64,
        ),
      ),
    );
    expect(find.textContaining('will re-run'), findsOneWidget);
    expect(find.text('Restore anyway'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('hard block: current < from — only Cancel', (tester) async {
    await tester.pumpWidget(
      _wrap(
        RestoreConfirmationDialog(
          record: _preMigration(fromVersion: 65, toVersion: 66),
          currentSchemaVersion: 64,
        ),
      ),
    );
    expect(find.textContaining('newer than your app'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Restore'), findsNothing);
    expect(find.text('Restore anyway'), findsNothing);
  });

  testWidgets('metadata incomplete: null schema versions — only Cancel', (
    tester,
  ) async {
    final incomplete = BackupRecord(
      id: 'incomplete',
      filename: 'pre.db',
      timestamp: DateTime(2026, 4, 12, 8, 12),
      sizeBytes: 1024,
      location: BackupLocation.local,
      localPath: '/tmp/pre.db',
      type: BackupType.preMigration,
      appVersion: '1.5.9.1000',
    );
    await tester.pumpWidget(
      _wrap(
        RestoreConfirmationDialog(record: incomplete, currentSchemaVersion: 64),
      ),
    );
    expect(find.textContaining('metadata is incomplete'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Restore'), findsNothing);
    expect(find.text('Restore anyway'), findsNothing);
  });

  group('show() static + button dismissal', () {
    Future<bool?> openAndTap(
      WidgetTester tester,
      BackupRecord record,
      int currentSchemaVersion,
      String buttonText,
    ) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => TextButton(
                onPressed: () async {
                  result = await RestoreConfirmationDialog.show(
                    ctx,
                    record,
                    currentSchemaVersion: currentSchemaVersion,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(buttonText));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('green path Restore returns true', (tester) async {
      final result = await openAndTap(
        tester,
        _preMigration(fromVersion: 63, toVersion: 64),
        63,
        'Restore',
      );
      expect(result, isTrue);
    });

    testWidgets('green path Cancel returns false', (tester) async {
      final result = await openAndTap(
        tester,
        _preMigration(fromVersion: 63, toVersion: 64),
        63,
        'Cancel',
      );
      expect(result, isFalse);
    });

    testWidgets('warning path Restore anyway returns true', (tester) async {
      final result = await openAndTap(
        tester,
        _preMigration(fromVersion: 63, toVersion: 64),
        64,
        'Restore anyway',
      );
      expect(result, isTrue);
    });

    testWidgets('warning path Cancel returns false', (tester) async {
      final result = await openAndTap(
        tester,
        _preMigration(fromVersion: 63, toVersion: 64),
        64,
        'Cancel',
      );
      expect(result, isFalse);
    });

    testWidgets('hard-block path Cancel returns false', (tester) async {
      final result = await openAndTap(
        tester,
        _preMigration(fromVersion: 65, toVersion: 66),
        64,
        'Cancel',
      );
      expect(result, isFalse);
    });

    testWidgets('metadata-incomplete Cancel returns false', (tester) async {
      final incomplete = BackupRecord(
        id: 'inc',
        filename: 'pre.db',
        timestamp: DateTime(2026, 4, 12),
        sizeBytes: 1,
        location: BackupLocation.local,
        localPath: '/tmp/pre.db',
        type: BackupType.preMigration,
        appVersion: '1.0.0.0',
      );
      final result = await openAndTap(tester, incomplete, 64, 'Cancel');
      expect(result, isFalse);
    });
  });

  testWidgets('manual record uses existing l10n-based dialog behaviour', (
    tester,
  ) async {
    final manual = BackupRecord(
      id: 'm',
      filename: 'm.db',
      timestamp: DateTime(2026, 4, 12),
      sizeBytes: 1,
      location: BackupLocation.local,
      localPath: '/tmp/m.db',
      diveCount: 3,
      siteCount: 4,
    );
    await tester.pumpWidget(
      _wrap(
        RestoreConfirmationDialog(record: manual, currentSchemaVersion: 64),
      ),
    );
    expect(find.textContaining('will re-run'), findsNothing);
    expect(find.textContaining('newer than your app'), findsNothing);
  });
}
