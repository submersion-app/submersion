import 'package:flutter/material.dart';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/backup/presentation/widgets/backup_actions.dart';
import 'package:submersion/features/backup/presentation/widgets/backup_download_tile.dart';

import '../../../../helpers/test_app.dart';

class _IdleBackupOp extends StateNotifier<BackupOperationState>
    implements BackupOperationNotifier {
  _IdleBackupOp() : super(const BackupOperationState());
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Restoring from a file swaps the database for one the user picked, which
/// a browser cannot do (issue #4121): the tile is not offered there.
void main() {
  Future<void> pump(WidgetTester tester, {bool browser = false}) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          backupOperationProvider.overrideWith((ref) => _IdleBackupOp()),
          if (browser)
            deviceCapabilitiesProvider.overrideWithValue(
              DeviceCapabilities.web,
            ),
        ],
        child: const RestoreFromFileTile(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('natively offers to restore from a file', (tester) async {
    await pump(tester);
    expect(find.text('Restore from a file'), findsOneWidget);
  });

  testWidgets('a browser has no file to restore from', (tester) async {
    await pump(tester, browser: true);
    expect(find.text('Restore from a file'), findsNothing);
    expect(find.byType(ListTile), findsNothing);
  });

  group('Download a backup (#4121)', () {
    final header = Uint8List.fromList([
      ...'SQLite format 3'.codeUnits,
      0,
      ...List.filled(4080, 7),
    ]);

    Future<List<(Uint8List, String)>> pumpTile(
      WidgetTester tester, {
      bool browser = true,
    }) async {
      final saved = <(Uint8List, String)>[];
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: [
            if (browser)
              deviceCapabilitiesProvider.overrideWithValue(
                DeviceCapabilities.web,
              ),
          ],
          child: BackupDownloadTile(
            readImage: () async => header,
            save: (bytes, name) async => saved.add((bytes, name)),
            clock: () => DateTime(2026, 11, 2, 14, 5),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return saved;
    }

    testWidgets('natively there is no download tile', (tester) async {
      await pumpTile(tester, browser: false);
      expect(find.byType(ListTile), findsNothing);
    });

    testWidgets('a browser downloads the database image, dated', (
      tester,
    ) async {
      final saved = await pumpTile(tester);
      expect(find.text('Download a backup'), findsOneWidget);
      await tester.tap(find.text('Download a backup'));
      await tester.pumpAndSettle();
      expect(saved, hasLength(1));
      expect(
        String.fromCharCodes(saved.single.$1.sublist(0, 16)),
        'SQLite format 3\x00',
      );
      expect(saved.single.$2, 'submersion-backup-20261102-1405.db');
    });

    test('the file name carries the date and minute', () {
      expect(
        BackupDownloadTile.fileNameFor(DateTime(2026, 1, 9, 8, 3)),
        'submersion-backup-20260109-0803.db',
      );
    });
  });
}
