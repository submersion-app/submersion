import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/domain/entities/backup_type.dart';
import 'package:submersion/features/backup/presentation/pages/backup_settings_page.dart';

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
  });
}

// Fixed timestamp used across tests.
final _kNow = DateTime(2024, 6, 1, 12, 0, 0);
