import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/backup/data/services/backup_attribution.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/backup/presentation/widgets/backup_history_section.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

BackupRecord _cloudRow(String id, String filename) => BackupRecord(
  id: id,
  filename: filename,
  timestamp: DateTime(2026, 10, 27, 21, 2),
  sizeBytes: 2048,
  location: BackupLocation.cloud,
);

String _from(String deviceId) =>
    buildBackupFilename(timestamp: '2026-10-27_210200', deviceId: deviceId);

Future<void> _pump(
  WidgetTester tester, {
  required List<BackupRecord> history,
  required String? thisDeviceId,
  Map<String, String> peerNames = const {},
  Stream<Map<String, String>>? peerNameStream,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        backupHistoryProvider.overrideWith((ref) async => history),
        backupDeviceIdProvider.overrideWith((ref) async => thisDeviceId),
        peerDeviceNamesProvider.overrideWith(
          (ref) => peerNameStream ?? Stream.value(peerNames),
        ),
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
}

void main() {
  group('BackupHistorySection originating device (#3651)', () {
    testWidgets('names the device behind each row', (tester) async {
      await _pump(
        tester,
        history: [
          _cloudRow('cloud:mine', _from('phone-id')),
          _cloudRow('cloud:laptop', _from('laptop-id')),
          _cloudRow('cloud:tablet', _from('tablet-id')),
          _cloudRow('cloud:old', 'submersion_backup_2026-09-02_181500.db'),
        ],
        thisDeviceId: 'phone-id',
        peerNames: const {'laptop-id': "Eric's MacBook"},
      );

      expect(
        find.text('In cloud storage (2.0 KB) · This device'),
        findsOneWidget,
      );
      expect(
        find.text("In cloud storage (2.0 KB) · Eric's MacBook"),
        findsOneWidget,
      );
      expect(
        find.text('In cloud storage (2.0 KB) · Another device'),
        findsOneWidget,
      );
      // Made before backups recorded their device: nothing to say.
      expect(find.text('In cloud storage (2.0 KB)'), findsOneWidget);
    });

    testWidgets('a name sync learns later replaces Another device', (
      tester,
    ) async {
      final names = StreamController<Map<String, String>>();
      addTearDown(names.close);
      await _pump(
        tester,
        history: [_cloudRow('cloud:laptop', _from('laptop-id'))],
        thisDeviceId: 'phone-id',
        peerNameStream: names.stream,
      );
      names.add(const {});
      await tester.pumpAndSettle();
      expect(
        find.text('In cloud storage (2.0 KB) \u00b7 Another device'),
        findsOneWidget,
      );

      names.add(const {'laptop-id': "Eric's MacBook"});
      await tester.pumpAndSettle();
      expect(
        find.text("In cloud storage (2.0 KB) \u00b7 Eric's MacBook"),
        findsOneWidget,
      );
    });

    testWidgets('an unreadable device id never guesses Another device', (
      tester,
    ) async {
      await _pump(
        tester,
        history: [_cloudRow('cloud:mine', _from('phone-id'))],
        thisDeviceId: null,
      );

      expect(find.text('In cloud storage (2.0 KB)'), findsOneWidget);
      expect(find.textContaining('Another device'), findsNothing);
    });
  });
}
