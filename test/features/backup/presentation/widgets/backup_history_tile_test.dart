import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/domain/entities/backup_type.dart';
import 'package:submersion/features/backup/presentation/widgets/backup_history_tile.dart';
import 'package:submersion/features/backup/presentation/widgets/pre_migration_badge.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

BackupRecord _manual({
  bool pinned = false,
  bool isAutomatic = false,
  int? diveCount = 5,
  int? siteCount = 3,
}) {
  return BackupRecord(
    id: 'm',
    filename: 'manual.db',
    timestamp: DateTime(2026, 4, 12, 8, 12),
    sizeBytes: 2048,
    location: BackupLocation.local,
    localPath: '/tmp/manual.db',
    pinned: pinned,
    isAutomatic: isAutomatic,
    diveCount: diveCount,
    siteCount: siteCount,
  );
}

BackupRecord _preMigration({
  int? fromVersion = 63,
  int? toVersion = 64,
  bool pinned = false,
}) {
  return BackupRecord(
    id: 'pre',
    filename: 'pre.db',
    timestamp: DateTime(2026, 4, 12, 8, 12),
    sizeBytes: 4096,
    location: BackupLocation.local,
    localPath: '/tmp/pre.db',
    type: BackupType.preMigration,
    appVersion: '1.5.9.1000',
    fromSchemaVersion: fromVersion,
    toSchemaVersion: toVersion,
    pinned: pinned,
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
  group('BackupHistoryTile rendering', () {
    testWidgets('manual record shows dive/site counts + optional (auto)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          BackupHistoryTile(
            record: _manual(isAutomatic: true),
            leadingIcon: Icons.phone_android,
            onPinToggle: () {},
            onRestore: () {},
            onDelete: () {},
          ),
        ),
      );
      expect(find.textContaining('5 dives, 3 sites'), findsOneWidget);
      expect(find.textContaining(' (auto)'), findsOneWidget);
      expect(find.byIcon(Icons.phone_android), findsOneWidget);
    });

    testWidgets('manual record without isAutomatic omits (auto) suffix', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          BackupHistoryTile(
            record: _manual(isAutomatic: false),
            leadingIcon: Icons.phone_android,
            onPinToggle: () {},
            onRestore: () {},
            onDelete: () {},
          ),
        ),
      );
      expect(find.textContaining(' (auto)'), findsNothing);
    });

    testWidgets('manual record null counts render as 0 dives, 0 sites', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          BackupHistoryTile(
            record: _manual(diveCount: null, siteCount: null),
            leadingIcon: Icons.phone_android,
            onPinToggle: () {},
            onRestore: () {},
            onDelete: () {},
          ),
        ),
      );
      expect(find.textContaining('0 dives, 0 sites'), findsOneWidget);
    });

    testWidgets(
      'preMigration record shows badge + pre-migration subtitle copy',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            BackupHistoryTile(
              record: _preMigration(),
              leadingIcon: Icons.phone_android,
              onPinToggle: () {},
              onRestore: () {},
              onDelete: () {},
            ),
          ),
        );
        expect(find.byType(PreMigrationBadge), findsOneWidget);
        expect(find.text('v63 \u2192 v64'), findsOneWidget);
        expect(find.textContaining('Pre-migration backup'), findsOneWidget);
      },
    );

    testWidgets(
      'preMigration record with null schema versions hides the badge',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            BackupHistoryTile(
              record: _preMigration(fromVersion: null, toVersion: null),
              leadingIcon: Icons.phone_android,
              onPinToggle: () {},
              onRestore: () {},
              onDelete: () {},
            ),
          ),
        );
        expect(find.byType(PreMigrationBadge), findsNothing);
        expect(find.textContaining('Pre-migration backup'), findsOneWidget);
      },
    );

    testWidgets('cloud leading icon is rendered', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BackupHistoryTile(
            record: _manual(),
            leadingIcon: Icons.cloud,
            onPinToggle: () {},
            onRestore: () {},
            onDelete: () {},
          ),
        ),
      );
      expect(find.byIcon(Icons.cloud), findsOneWidget);
    });
  });

  group('BackupHistoryTile pin control', () {
    testWidgets('unpinned record shows outlined pin icon + Pin tooltip', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          BackupHistoryTile(
            record: _manual(),
            leadingIcon: Icons.phone_android,
            onPinToggle: () {},
            onRestore: () {},
            onDelete: () {},
          ),
        ),
      );
      expect(
        find.widgetWithIcon(IconButton, Icons.push_pin_outlined),
        findsOneWidget,
      );
      final button = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.push_pin_outlined),
      );
      expect(button.tooltip, 'Pin backup');
    });

    testWidgets('pinned record shows filled pin icon + Unpin tooltip', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          BackupHistoryTile(
            record: _manual(pinned: true),
            leadingIcon: Icons.phone_android,
            onPinToggle: () {},
            onRestore: () {},
            onDelete: () {},
          ),
        ),
      );
      final button = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.push_pin),
      );
      expect(button.tooltip, 'Unpin backup');
    });

    testWidgets('tapping pin icon invokes onPinToggle', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          BackupHistoryTile(
            record: _manual(),
            leadingIcon: Icons.phone_android,
            onPinToggle: () => taps++,
            onRestore: () {},
            onDelete: () {},
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.push_pin_outlined));
      await tester.pump();
      expect(taps, 1);
    });
  });

  group('BackupHistoryTile popup menu', () {
    testWidgets('Restore menu item invokes onRestore', (tester) async {
      var restores = 0;
      await tester.pumpWidget(
        _wrap(
          BackupHistoryTile(
            record: _manual(),
            leadingIcon: Icons.phone_android,
            onPinToggle: () {},
            onRestore: () => restores++,
            onDelete: () {},
          ),
        ),
      );
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.restore));
      await tester.pumpAndSettle();
      expect(restores, 1);
    });

    testWidgets('Delete menu item invokes onDelete', (tester) async {
      var deletes = 0;
      await tester.pumpWidget(
        _wrap(
          BackupHistoryTile(
            record: _manual(),
            leadingIcon: Icons.phone_android,
            onPinToggle: () {},
            onRestore: () {},
            onDelete: () => deletes++,
          ),
        ),
      );
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.delete));
      await tester.pumpAndSettle();
      expect(deletes, 1);
    });
  });
}
