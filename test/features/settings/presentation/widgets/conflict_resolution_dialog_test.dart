import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/conflict_reference.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/conflict_resolution_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Widget coverage for the Resolve Conflicts dialog's data preview (#1031).
/// Junction and relation entities carry nothing but foreign keys, so the
/// preview has to lead with the resolved references; showing raw UUIDs and an
/// epoch timestamp gives the user nothing to decide with.
void main() {
  final diveDate = DateTime(2026, 3, 28, 10, 0);

  Future<void> pumpDialog(WidgetTester tester, SyncConflict conflict) async {
    final base = await getBaseOverrides();
    await tester.binding.setSurfaceSize(const Size(600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          conflictsProvider.overrideWith((ref) async => [conflict]),
        ],
        child: const MaterialApp(
          // Pinned so the English literals asserted below cannot depend on
          // the host's default locale.
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ConflictResolutionDialog()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  SyncConflict diveTagConflict({
    String localTagName = 'Wreck',
    bool tagMissing = false,
  }) => SyncConflict(
    entityType: 'diveTags',
    recordId: '7600a6e8-42b8-4375-b71b-e492b9406adb',
    localData: {
      'id': '7600a6e8-42b8-4375-b71b-e492b9406adb',
      'diveId': '889cb873-5517-41dc-8545-4bdb59307c38',
      'tagId': 'a7136f77-5628-4d6c-abaf-eed97f618cc8',
      'createdAt': 1786556582600,
    },
    remoteData: {
      'id': '7600a6e8-42b8-4375-b71b-e492b9406adb',
      'diveId': '889cb873-5517-41dc-8545-4bdb59307c38',
      'tagId': 'b1234567-5628-4d6c-abaf-eed97f618cc8',
      'createdAt': 1786556582600,
    },
    localModified: DateTime(2026, 3, 28),
    remoteModified: DateTime(2026, 3, 29),
    localReferences: [
      ConflictReference(
        field: 'diveId',
        targetType: 'dives',
        recordId: '889cb873-5517-41dc-8545-4bdb59307c38',
        name: 'Blue Hole',
        timestamp: diveDate,
      ),
      ConflictReference(
        field: 'tagId',
        targetType: 'tags',
        recordId: 'a7136f77-5628-4d6c-abaf-eed97f618cc8',
        exists: !tagMissing,
        name: tagMissing ? null : localTagName,
      ),
    ],
    remoteReferences: [
      ConflictReference(
        field: 'diveId',
        targetType: 'dives',
        recordId: '889cb873-5517-41dc-8545-4bdb59307c38',
        name: 'Blue Hole',
        timestamp: diveDate,
      ),
      const ConflictReference(
        field: 'tagId',
        targetType: 'tags',
        recordId: 'b1234567-5628-4d6c-abaf-eed97f618cc8',
        name: 'Night dive',
      ),
    ],
  );

  testWidgets('names the tag and the dive instead of printing their ids', (
    tester,
  ) async {
    await pumpDialog(tester, diveTagConflict());

    expect(find.text('Tag:'), findsNWidgets(2));
    expect(find.text('Dive:'), findsNWidgets(2));
    expect(find.text('Wreck'), findsOneWidget);
    expect(find.text('Night dive'), findsOneWidget);
    // "Blue Hole (28/03/2026)": the dive is named by its site and dated.
    // Both sides render one, on top of the composed header title.
    expect(find.textContaining('Blue Hole ('), findsNWidgets(2));
  });

  testWidgets('never shows a raw uuid or epoch millis in the preview', (
    tester,
  ) async {
    await pumpDialog(tester, diveTagConflict());

    expect(find.textContaining('a7136f77'), findsNothing);
    expect(find.textContaining('889cb873'), findsNothing);
    expect(find.textContaining('1786556582600'), findsNothing);
  });

  testWidgets('says so when a referenced record is gone locally', (
    tester,
  ) async {
    await pumpDialog(tester, diveTagConflict(tagMissing: true));

    expect(find.text('No longer in this library'), findsOneWidget);
  });

  testWidgets('falls back to a short id for a nameless record that exists', (
    tester,
  ) async {
    // A dive tank carries no name, date, or any other anchor unless the diver
    // named it. The reference still exists, so the preview must identify it
    // rather than claim it was deleted.
    await pumpDialog(
      tester,
      SyncConflict(
        entityType: 'gasSwitches',
        recordId: 'gs-1',
        localData: const {'id': 'gs-1', 'tankId': 'aabbccdd-1111-2222'},
        remoteData: const {'id': 'gs-1', 'tankId': 'eeff0011-3333-4444'},
        localModified: DateTime(2026, 3, 28),
        remoteModified: DateTime(2026, 3, 29),
        localReferences: const [
          ConflictReference(
            field: 'tankId',
            targetType: 'diveTanks',
            recordId: 'aabbccdd-1111-2222',
          ),
        ],
        remoteReferences: const [
          ConflictReference(
            field: 'tankId',
            targetType: 'diveTanks',
            recordId: 'eeff0011-3333-4444',
          ),
        ],
      ),
    );

    expect(find.text('#aabbccdd'), findsOneWidget);
    expect(find.text('#eeff0011'), findsOneWidget);
    expect(find.text('No longer in this library'), findsNothing);
  });

  testWidgets('describes the conflicting record in the header', (tester) async {
    await pumpDialog(tester, diveTagConflict());

    expect(find.text('Blue Hole \u2022 Wreck'), findsOneWidget);
    expect(find.text('Dive Tags'), findsOneWidget);
    expect(find.textContaining('7600a6e8'), findsNothing);
  });

  testWidgets('shows the entity icon for a sync entity type', (tester) async {
    // The sync entity types are camelCase plurals ('diveSites'), which the
    // icon lookup lowercases; matching only 'divesite'/'dive_sites' left
    // sites and gear on the generic document icon.
    await pumpDialog(
      tester,
      SyncConflict(
        entityType: 'diveSites',
        recordId: 's-1',
        localData: const {'id': 's-1', 'name': 'Blue Hole'},
        remoteData: const {'id': 's-1', 'name': 'The Blue Hole'},
        localModified: DateTime(2026, 3, 28),
        remoteModified: DateTime(2026, 3, 29),
      ),
    );

    expect(find.byIcon(Icons.place), findsOneWidget);
  });

  testWidgets("renders a depth in the diver's configured unit", (tester) async {
    await pumpDialog(
      tester,
      SyncConflict(
        entityType: 'dives',
        recordId: 'd-1',
        localData: const {'id': 'd-1', 'maxDepth': 30.48},
        remoteData: const {'id': 'd-1', 'maxDepth': 30.48},
        localModified: DateTime(2026, 3, 28),
        remoteModified: DateTime(2026, 3, 29),
      ),
    );

    // The mock settings default to metres, so the stored metres carry a unit
    // rather than printing as a bare number.
    expect(find.text('30.5m'), findsNWidgets(2));
    expect(find.text('30.48'), findsNothing);
  });

  testWidgets('dates an epoch column but leaves a duration alone', (
    tester,
  ) async {
    // bottomTime and createdAt both end in a time-ish word, but bottomTime is
    // seconds and createdAt is Unix millis. Only the magnitude tells them
    // apart, so a naive name-only rule would date a 45-minute bottom time to
    // 1970.
    await pumpDialog(
      tester,
      SyncConflict(
        entityType: 'dives',
        recordId: 'd-1',
        localData: const {
          'id': 'd-1',
          'diveNumber': 12,
          'bottomTime': 2700,
          'createdAt': 1786556582600,
        },
        remoteData: const {
          'id': 'd-1',
          'diveNumber': 13,
          'bottomTime': 2700,
          'createdAt': 1786556582600,
        },
        localModified: DateTime(2026, 3, 28),
        remoteModified: DateTime(2026, 3, 29),
      ),
    );

    expect(find.text('45min'), findsNWidgets(2));
    expect(find.textContaining('1786556582600'), findsNothing);
    expect(find.textContaining('2700'), findsNothing);
  });

  testWidgets('shows nothing at all for a side with no data', (tester) async {
    await pumpDialog(
      tester,
      SyncConflict(
        entityType: 'diveTags',
        recordId: 'dt-1',
        localData: const {},
        remoteData: const {'id': 'dt-1', 'tagId': 't-1'},
        localModified: DateTime(2026, 3, 28),
        remoteModified: DateTime(2026, 3, 29),
      ),
    );

    expect(find.text('No data available'), findsOneWidget);
  });

  testWidgets('falls back to raw columns when a finding cannot be read', (
    tester,
  ) async {
    // params is not valid JSON, so the localized sentence cannot be built.
    // Hiding detectorId and params only makes sense when the sentence
    // replaced them; without it the user would be left with nothing at all.
    await pumpDialog(
      tester,
      SyncConflict(
        entityType: 'qualityFindings',
        recordId: 'qf-1',
        localData: const {
          'id': 'qf-1',
          'detectorId': 'depth_spike',
          'detectorVersion': 1,
          'category': 'profile',
          'severity': 'warning',
          'status': 'open',
          'params': 'not json at all',
          'createdAt': 1786556582600,
        },
        remoteData: const {
          'id': 'qf-1',
          'detectorId': 'depth_spike',
          'detectorVersion': 1,
          'category': 'profile',
          'severity': 'critical',
          'status': 'open',
          'params': 'not json at all',
          'createdAt': 1786556582600,
        },
        localModified: DateTime(2026, 3, 28),
        remoteModified: DateTime(2026, 3, 29),
      ),
    );

    expect(find.text('Finding:'), findsNothing);
    expect(find.text('detectorId:'), findsNWidgets(2));
    expect(find.text('depth_spike'), findsNWidgets(2));
  });

  testWidgets('falls back to raw columns for an unreadable finding category', (
    tester,
  ) async {
    // A category written by a newer schema is not a value this build knows.
    await pumpDialog(
      tester,
      SyncConflict(
        entityType: 'qualityFindings',
        recordId: 'qf-2',
        localData: const {
          'id': 'qf-2',
          'detectorId': 'depth_spike',
          'category': 'somethingNewer',
          'severity': 'warning',
          'status': 'open',
          'params': '{}',
        },
        remoteData: const {
          'id': 'qf-2',
          'detectorId': 'depth_spike',
          'category': 'somethingNewer',
          'severity': 'critical',
          'status': 'open',
          'params': '{}',
        },
        localModified: DateTime(2026, 3, 28),
        remoteModified: DateTime(2026, 3, 29),
      ),
    );

    expect(find.text('Finding:'), findsNothing);
    expect(find.text('detectorId:'), findsNWidgets(2));
  });

  testWidgets('shows the column that actually differs between the sides', (
    tester,
  ) async {
    // The whole point of the dialog is choosing between two versions. A
    // record with a recognizable field must not hide the column the two sides
    // disagree about just because that column is not on the preferred list.
    await pumpDialog(
      tester,
      SyncConflict(
        entityType: 'dives',
        recordId: 'd-1',
        localData: const {'id': 'd-1', 'name': 'Blue Hole', 'diveNumber': 12},
        remoteData: const {'id': 'd-1', 'name': 'Blue Hole', 'diveNumber': 13},
        localModified: DateTime(2026, 3, 28),
        remoteModified: DateTime(2026, 3, 29),
      ),
    );

    expect(find.text('diveNumber:'), findsNWidgets(2));
    expect(find.text('12'), findsOneWidget);
    expect(find.text('13'), findsOneWidget);
  });

  testWidgets('names a conflict from the remote side when the local row is '
      'gone', (tester) async {
    await pumpDialog(
      tester,
      SyncConflict(
        entityType: 'diveSites',
        recordId: 's-1',
        localData: const {},
        remoteData: const {'id': 's-1', 'name': 'The Arch'},
        localModified: DateTime(2026, 3, 28),
        remoteModified: DateTime(2026, 3, 29),
      ),
    );

    // Once in the header, once in the remote preview.
    expect(find.text('The Arch'), findsNWidgets(2));
    expect(find.textContaining('diveSites #'), findsNothing);
  });

  testWidgets('renders a detector that dates its finding', (tester) async {
    // A second detector, to show the preview inherits every detector's copy
    // from the data-quality renderer rather than special-casing depth spikes.
    // clock_offset formats its stored epoch through the diver's date format.
    await pumpDialog(
      tester,
      SyncConflict(
        entityType: 'qualityFindings',
        recordId: 'qf-clock',
        localData: const {
          'id': 'qf-clock',
          'detectorId': 'clock_offset',
          'detectorVersion': 1,
          'category': 'time',
          'severity': 'warning',
          'status': 'open',
          'params': '{"entryTimeMs":-2208988800000}',
        },
        remoteData: const {
          'id': 'qf-clock',
          'detectorId': 'clock_offset',
          'detectorVersion': 1,
          'category': 'time',
          'severity': 'critical',
          'status': 'open',
          'params': '{"entryTimeMs":-2208988800000}',
        },
        localModified: DateTime(2026, 3, 28),
        remoteModified: DateTime(2026, 3, 29),
      ),
    );

    expect(find.textContaining('Clock & timezone'), findsNWidgets(2));
    expect(find.textContaining('dated before 1950'), findsNWidgets(2));
    expect(find.textContaining('1900'), findsNWidgets(2));
  });

  testWidgets('falls back to raw columns for a finding missing a column', (
    tester,
  ) async {
    // A row that reached this device without a category at all. Without the
    // guard the cast throws and takes the whole dialog down with it, leaving
    // the conflict unresolvable.
    await pumpDialog(
      tester,
      SyncConflict(
        entityType: 'qualityFindings',
        recordId: 'qf-3',
        localData: const {
          'id': 'qf-3',
          'detectorId': 'depth_spike',
          'severity': 'warning',
          'status': 'open',
          'params': '{}',
        },
        remoteData: const {
          'id': 'qf-3',
          'detectorId': 'depth_spike',
          'severity': 'critical',
          'status': 'open',
          'params': '{}',
        },
        localModified: DateTime(2026, 3, 28),
        remoteModified: DateTime(2026, 3, 29),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Finding:'), findsNothing);
    expect(find.text('detectorId:'), findsNWidgets(2));
  });

  testWidgets('renders a quality finding as its localized message', (
    tester,
  ) async {
    final finding = SyncConflict(
      entityType: 'qualityFindings',
      recordId: 'qf-1',
      localData: const {
        'id': 'qf-1',
        'diveId': '889cb873-5517-41dc-8545-4bdb59307c38',
        'detectorId': 'depth_spike',
        'detectorVersion': 1,
        'category': 'profile',
        'severity': 'warning',
        'status': 'open',
        'params': '{"depth":42.0,"atSeconds":185}',
        'createdAt': 1786556582600,
        'updatedAt': 1786556582600,
      },
      remoteData: const {
        'id': 'qf-1',
        'diveId': '889cb873-5517-41dc-8545-4bdb59307c38',
        'detectorId': 'depth_spike',
        'detectorVersion': 1,
        'category': 'profile',
        'severity': 'critical',
        'status': 'open',
        'params': '{"depth":42.0,"atSeconds":185}',
        'createdAt': 1786556582600,
        'updatedAt': 1786556582600,
      },
      localModified: DateTime(2026, 3, 28),
      remoteModified: DateTime(2026, 3, 29),
      localReferences: [
        ConflictReference(
          field: 'diveId',
          targetType: 'dives',
          recordId: '889cb873-5517-41dc-8545-4bdb59307c38',
          name: 'Blue Hole',
          timestamp: diveDate,
        ),
      ],
      remoteReferences: [
        ConflictReference(
          field: 'diveId',
          targetType: 'dives',
          recordId: '889cb873-5517-41dc-8545-4bdb59307c38',
          name: 'Blue Hole',
          timestamp: diveDate,
        ),
      ],
    );

    await pumpDialog(tester, finding);

    expect(find.textContaining('Depth spike'), findsWidgets);
    expect(find.textContaining('params'), findsNothing);
    expect(find.textContaining('detectorId'), findsNothing);
  });
}
