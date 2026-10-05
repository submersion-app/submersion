import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/conflict_reference.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/conflict_resolution_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Widget coverage for the Resolve Conflicts dialog (#1031, #694): it names
/// both devices, lists every field the versions disagree on, and says what
/// each choice keeps and discards.
void main() {
  final diveDate = DateTime(2026, 3, 28, 10, 0);

  Future<void> pumpDialog(
    WidgetTester tester,
    SyncConflict conflict, {
    Size size = const Size(600, 1200),
  }) async {
    final base = await getBaseOverrides();
    // The view, not the surface: MediaQuery reads the view's size, and the
    // dialog chooses full screen from MediaQuery.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          conflictsProvider.overrideWith((ref) async => [conflict]),
          peerDeviceNamesProvider.overrideWith(
            (ref) => Stream.value(const {'peer-id': 'Windows PC'}),
          ),
          conflictLocalDeviceProvider.overrideWith(
            (ref) async => (id: 'local-id', name: 'Pixel 8'),
          ),
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

  /// The dialog's card, not the Dialog widget, which fills the screen.
  Size cardSize(WidgetTester tester) => tester.getSize(
    find
        .descendant(of: find.byType(Dialog), matching: find.byType(Material))
        .first,
  );

  Future<void> expandUnchanged(WidgetTester tester) async {
    await tester.tap(find.textContaining('the same'));
    await tester.pumpAndSettle();
  }

  final diveConflict = SyncConflict(
    entityType: 'dives',
    recordId: 'd-1',
    localData: const {
      'id': 'd-1',
      'name': 'Blue Hole',
      'waterTemp': 26.0,
      'notes': 'Saw a turtle.',
      'hlc': '1786556582600:0:local-id',
    },
    remoteData: const {
      'id': 'd-1',
      'name': 'Blue Hole',
      'waterTemp': 27.0,
      'notes': 'Saw two turtles.',
      'hlc': '1786556582600:0:peer-id',
    },
    localModified: DateTime(2026, 3, 28),
    remoteModified: DateTime(2026, 3, 29),
  );

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

    expect(find.text('Tag'), findsOneWidget);
    expect(find.text('Wreck'), findsOneWidget);
    expect(find.text('Night dive'), findsOneWidget);
    // The dive is the same on both sides, so it is with the unchanged fields:
    // named by its site and dated.
    await expandUnchanged(tester);
    expect(find.textContaining('Blue Hole ('), findsOneWidget);
  });

  testWidgets('never shows a raw uuid or epoch millis', (tester) async {
    await pumpDialog(tester, diveTagConflict());
    await expandUnchanged(tester);

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
    // named it. The reference still exists, so the dialog must identify it
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

    expect(find.text('Blue Hole • Wreck'), findsOneWidget);
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
        remoteData: const {'id': 'd-1', 'maxDepth': 31.0},
        localModified: DateTime(2026, 3, 28),
        remoteModified: DateTime(2026, 3, 29),
      ),
    );

    // The mock settings default to metres, so the stored metres carry a unit
    // rather than printing as a bare number.
    expect(find.text('30.5m'), findsOneWidget);
    expect(find.text('31.0m'), findsOneWidget);
    expect(find.text('30.48'), findsNothing);
  });

  testWidgets('lists the differing column and keeps a duration readable', (
    tester,
  ) async {
    await pumpDialog(
      tester,
      SyncConflict(
        entityType: 'dives',
        recordId: 'd-1',
        localData: const {
          'id': 'd-1',
          'name': 'Blue Hole',
          'diveNumber': 12,
          'bottomTime': 2700,
          'createdAt': 1786556582600,
        },
        remoteData: const {
          'id': 'd-1',
          'name': 'Blue Hole',
          'diveNumber': 13,
          'bottomTime': 2700,
          'createdAt': 1786556582600,
        },
        localModified: DateTime(2026, 3, 28),
        remoteModified: DateTime(2026, 3, 29),
      ),
    );

    expect(find.text('What differs (1)'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('13'), findsOneWidget);
    await expandUnchanged(tester);
    expect(find.text('45min'), findsOneWidget);
    expect(find.textContaining('1786556582600'), findsNothing);
    expect(find.textContaining('2700'), findsNothing);
  });

  testWidgets('a local deletion is named and shows the remote record', (
    tester,
  ) async {
    await pumpDialog(
      tester,
      SyncConflict(
        entityType: 'diveSites',
        recordId: 's-1',
        localData: const {},
        remoteData: const {
          'id': 's-1',
          'name': 'The Arch',
          'hlc': '1786556582600:0:peer-id',
        },
        localModified: DateTime(2026, 3, 28),
        remoteModified: DateTime(2026, 3, 29),
      ),
    );

    expect(find.text('Pixel 8 deleted this record.'), findsOneWidget);
    // Once in the header, once in the values the other device still has.
    expect(find.text('The Arch'), findsNWidgets(2));
    expect(find.textContaining('diveSites #'), findsNothing);
    expect(find.text('Keep Both'), findsNothing);
  });

  testWidgets('renders a quality finding as its localized message', (
    tester,
  ) async {
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
          'params': '{"depth":42.0,"atSeconds":185}',
        },
        remoteData: const {
          'id': 'qf-1',
          'detectorId': 'depth_spike',
          'detectorVersion': 1,
          'category': 'profile',
          'severity': 'critical',
          'status': 'open',
          'params': '{"depth":42.0,"atSeconds":185}',
        },
        localModified: DateTime(2026, 3, 28),
        remoteModified: DateTime(2026, 3, 29),
      ),
    );
    await expandUnchanged(tester);

    expect(find.textContaining('Depth spike'), findsWidgets);
    expect(find.textContaining('params'), findsNothing);
    expect(find.textContaining('detectorId'), findsNothing);
  });

  testWidgets('chips name the devices and Keep both is offered', (
    tester,
  ) async {
    await pumpDialog(tester, diveConflict);

    expect(find.text('Keep Pixel 8'), findsOneWidget);
    expect(find.text('Keep Windows PC'), findsOneWidget);
    expect(find.text('Keep Both'), findsOneWidget);
    expect(find.text('Choose which version to keep.'), findsOneWidget);
  });

  testWidgets('picking a version states what it discards', (tester) async {
    await pumpDialog(tester, diveConflict);
    await tester.tap(find.text('Keep Pixel 8'));
    await tester.pumpAndSettle();

    expect(find.textContaining("Windows PC's values for"), findsOneWidget);
    expect(find.textContaining('are discarded'), findsOneWidget);
  });

  testWidgets('Keep both is hidden for a row with no id of its own', (
    tester,
  ) async {
    await pumpDialog(
      tester,
      SyncConflict(
        entityType: 'diveEquipment',
        recordId: 'd-1|e-1',
        localData: const {'diveId': 'd-1', 'equipmentId': 'e-1', 'notes': 'a'},
        remoteData: const {'diveId': 'd-1', 'equipmentId': 'e-1', 'notes': 'b'},
        localModified: DateTime(2026, 3, 28),
        remoteModified: DateTime(2026, 3, 29),
      ),
    );

    expect(find.text('Keep Both'), findsNothing);
  });

  testWidgets('a phone-width window gets a full-screen dialog', (tester) async {
    await pumpDialog(tester, diveConflict, size: const Size(390, 844));

    expect(cardSize(tester), const Size(390, 844));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the next conflict opens collapsed and at the top', (
    tester,
  ) async {
    SyncConflict site(String id, String name) => SyncConflict(
      entityType: 'diveSites',
      recordId: id,
      localData: {'id': id, 'name': name, 'country': 'Belize', 'notes': 'a'},
      remoteData: {'id': id, 'name': name, 'country': 'Belize', 'notes': 'b'},
      localModified: DateTime(2026, 3, 28),
      remoteModified: DateTime(2026, 3, 29),
    );
    final base = await getBaseOverrides();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          conflictsProvider.overrideWith(
            (ref) async => [site('s-1', 'Reef'), site('s-2', 'Wall')],
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ConflictResolutionDialog()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expandUnchanged(tester);
    expect(find.text('Belize'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(find.text('Wall'), findsWidgets);
    expect(find.text('Belize'), findsNothing);
  });

  testWidgets('the choices span the dialog width', (tester) async {
    await pumpDialog(tester, diveConflict, size: const Size(1280, 900));

    expect(
      tester
          .getSize(find.byKey(const Key('conflict-resolution-options')))
          .width,
      cardSize(tester).width,
    );
  });

  testWidgets('a wide window keeps a centred dialog up to 720 wide', (
    tester,
  ) async {
    await pumpDialog(tester, diveConflict, size: const Size(1280, 900));

    expect(cardSize(tester).width, lessThanOrEqualTo(720));
  });
}
