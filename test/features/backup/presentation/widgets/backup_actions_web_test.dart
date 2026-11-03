import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/backup/domain/entities/restore_mode.dart';
import 'package:submersion/features/backup/domain/exceptions/backup_encrypted_exception.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/backup/presentation/widgets/backup_actions.dart';
import 'package:submersion/features/backup/presentation/widgets/backup_download_tile.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

import '../../../../helpers/mock_file_picker_platform.dart';
import '../../../../helpers/test_app.dart';

class _IdleBackupOp extends StateNotifier<BackupOperationState>
    implements BackupOperationNotifier {
  _IdleBackupOp() : super(const BackupOperationState());

  final restored = <(Uint8List, RestoreMode, String?)>[];

  /// Throws [BackupEncryptedException] until a secret is given.
  bool encrypted = false;

  @override
  Future<void> restoreFromImage(
    Uint8List bytes, {
    RestoreMode mode = RestoreMode.merge,
    String? encryptionSecret,
  }) async {
    if (encrypted && encryptionSecret == null) {
      throw const BackupEncryptedException();
    }
    restored.add((bytes, mode, encryptionSecret));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Restoring from a file swaps the database for one the user picked; a
/// browser reads the file through its picker (issue #4121).
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

  testWidgets('a browser restores from a file it reads', (tester) async {
    await pump(tester, browser: true);
    expect(find.text('Restore from a file'), findsOneWidget);
  });

  group('Restore from a file in a browser (#4121)', () {
    late _IdleBackupOp op;

    Future<void> pumpRestore(WidgetTester tester, Uint8List bytes) async {
      op = _IdleBackupOp();
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            cloudStorageProviderProvider.overrideWithValue(null),
            backupOperationProvider.overrideWith((ref) => op),
            deviceCapabilitiesProvider.overrideWithValue(
              DeviceCapabilities.web,
            ),
          ],
          child: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => restoreFromFile(
                context,
                ref,
                pick: () async => FakePlatformFile.contentUri(
                  Uri.parse('blob:my-backup'),
                  name: 'my-backup.db',
                  bytes: bytes,
                ),
              ),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
    }

    testWidgets('confirms by file name and restores the bytes it read', (
      tester,
    ) async {
      final bytes = Uint8List.fromList(List.filled(64, 1));
      await pumpRestore(tester, bytes);

      expect(find.text('Restore Backup'), findsOneWidget);
      expect(find.text('my-backup.db'), findsOneWidget);
      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();

      expect(op.restored.single.$1, bytes);
      expect(op.restored.single.$2, RestoreMode.merge);
    });

    testWidgets('an encrypted backup asks for its passphrase', (tester) async {
      final bytes = Uint8List.fromList(List.filled(64, 2));
      op = _IdleBackupOp();
      await pumpRestore(tester, bytes);
      op.encrypted = true;
      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();

      expect(find.text('Unlock encrypted backup'), findsOneWidget);
    });
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
