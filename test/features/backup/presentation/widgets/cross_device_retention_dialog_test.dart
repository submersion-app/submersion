import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/features/backup/data/services/backup_attribution.dart';
import 'package:submersion/features/backup/data/services/cross_device_retention.dart';
import 'package:submersion/features/backup/presentation/widgets/cross_device_retention_dialog.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

RetentionCandidate _candidate(
  int day,
  BackupOwnership ownership, {
  int? size = 108 * 1024 * 1024,
}) {
  final at = DateTime(2026, 8, day, 9, 14);
  return RetentionCandidate(
    file: CloudFileInfo(
      id: 'f$day',
      name:
          'submersion_backup_2026-08-${day.toString().padLeft(2, '0')}_091400.db',
      modifiedTime: at,
      sizeBytes: size,
    ),
    timestamp: at,
    ownership: ownership,
  );
}

CrossDeviceRetentionPlan _plan({int pinnedKept = 4}) =>
    CrossDeviceRetentionPlan(
      keepCount: 10,
      toDelete: [
        _candidate(12, BackupOwnership.otherDevice),
        _candidate(9, BackupOwnership.thisDevice),
        _candidate(4, BackupOwnership.unattributed),
      ],
      orphanMarkers: const [],
      pinnedKept: pinnedKept,
    );

void main() {
  bool? result;

  Future<void> open(WidgetTester tester, CrossDeviceRetentionPlan plan) async {
    result = null;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  result = await showCrossDeviceRetentionDialog(context, plan),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('lists every backup that goes, with its source', (tester) async {
    await open(tester, _plan());
    expect(find.text('Remove 3 backups?'), findsOneWidget);
    expect(
      find.text(
        'Keeping the last 10 backups removes these from the cloud folder '
        '(324 MB in all).',
      ),
      findsOneWidget,
    );
    expect(find.text('4 pinned backups are kept.'), findsOneWidget);
    expect(find.text('Another device'), findsOneWidget);
    expect(find.text('This device'), findsOneWidget);
    expect(find.text('Unknown device'), findsOneWidget);
    expect(find.text('108 MB'), findsNWidgets(3));
  });

  testWidgets('says nothing about pins when none are kept', (tester) async {
    await open(tester, _plan(pinnedKept: 0));
    expect(find.textContaining('pinned'), findsNothing);
  });

  testWidgets('a backup whose size is unknown shows no size', (tester) async {
    await open(
      tester,
      CrossDeviceRetentionPlan(
        keepCount: 10,
        toDelete: [_candidate(12, BackupOwnership.otherDevice, size: null)],
        orphanMarkers: const [],
        pinnedKept: 0,
      ),
    );
    expect(find.text('0 B'), findsNothing);
  });

  testWidgets('Cancel returns false', (tester) async {
    await open(tester, _plan());
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  testWidgets('the remove button returns true', (tester) async {
    await open(tester, _plan());
    await tester.tap(find.text('Remove 3 backups'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}
