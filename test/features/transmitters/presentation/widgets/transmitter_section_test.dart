import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/transmitters/data/repositories/transmitter_repository.dart';
import 'package:submersion/features/transmitters/data/services/transmitter_slot_backfill.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter_slot_preview.dart';
import 'package:submersion/features/transmitters/presentation/providers/transmitter_providers.dart';
import 'package:submersion/features/transmitters/presentation/widgets/transmitter_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Answers the apply preview with fixed counts and records each key applied;
/// [failApply] makes the write fail, as a closed database would.
class _FakeApplyRepository extends TransmitterRepository {
  _FakeApplyRepository({
    required this.preview,
    this.failApply = false,
    this.slots = TransmitterSlotPreview.empty,
  });

  final ApplyToExistingResult preview;
  final bool failApply;
  final TransmitterSlotPreview slots;
  final applied = <String>[];
  final slotTankIdsApplied = <Set<String>>[];

  var serialLookups = 0;
  final serialLookupDivers = <String?>[];
  final previewComputerIds = <Set<String>?>[];

  /// Answers the serial lookup in place of the slot candidates' computers.
  Set<String> Function()? computers;

  /// Holds lookups open until completed, as a slow database would.
  Completer<void>? gate;

  @override
  Future<Set<String>> computersForSerial(
    String serial, {
    String? diverId,
  }) async {
    serialLookups++;
    serialLookupDivers.add(diverId);
    await gate?.future;
    return computers?.call() ??
        {for (final c in slots.candidates) c.computerId};
  }

  @override
  Future<TransmitterSlotPreview> previewSlotMatches(
    Transmitter t, {
    Set<String>? computerIds,
  }) async {
    previewComputerIds.add(computerIds);
    return slots;
  }

  @override
  Future<ApplyToExistingResult> previewApplyToExistingDives(
    Transmitter t,
  ) async => preview;

  @override
  Future<ApplyToExistingResult> applyToExistingDives(
    Transmitter t, {
    Set<String> slotTankIds = const {},
  }) async {
    if (failApply) throw StateError('database closed');
    applied.add(t.id);
    slotTankIdsApplied.add(slotTankIds);
    return preview;
  }
}

/// Records the computers the Apply flow backfills, and writes nothing.
class _FakeBackfill extends TransmitterSlotBackfill {
  _FakeBackfill({this.pending = 1, this.dbComputers = const {}, this.error})
    : super(parseRaw: (v, p, m, raw) => throw UnimplementedError());

  final int pending;
  final Set<String> dbComputers;

  /// Thrown by [run] when set, as a failed backfill would.
  final Object? error;
  final runs = <Set<String>>[];
  final divers = <String?>[];

  /// Holds [run] open until completed, so its progress dialog can be seen.
  Completer<void>? gate;

  @override
  Future<Set<String>> dbImportComputers({String? diverId}) async {
    divers.add(diverId);
    return dbComputers;
  }

  @override
  Future<int> pendingCount(Set<String> computerIds, {String? diverId}) async {
    divers.add(diverId);
    return pending;
  }

  @override
  Future<int> run(
    Set<String> computerIds, {
    void Function(int done, int total)? onProgress,
    String? diverId,
  }) async {
    runs.add(computerIds);
    divers.add(diverId);
    onProgress?.call(1, 2);
    await gate?.future;
    if (error case final e?) throw e;
    return 0;
  }
}

/// A transmitter's setup lives on its Equipment page (issue #3676).
void main() {
  Transmitter key({
    String id = 'k1',
    bool configured = true,
    String? cylinder,
    double? volume,
    String? diverId,
  }) => Transmitter(
    id: id,
    diverId: diverId,
    transmitterSerial: '4A21F',
    label: 'Back gas tx',
    role: TankRole.stage,
    equipmentId: cylinder,
    volumeL: volume,
    isConfigured: configured,
    transmitterEquipmentId: 'tx-gear',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  Future<void> pump(
    WidgetTester tester,
    List<Transmitter> keys, {
    TransmitterRepository? repository,
    TransmitterSlotBackfill? backfill,
  }) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // One ShellRoute, as the app has (issue #4347): a dialog the flow
    // shows lives on the root navigator, not the page's.
    final router = GoRouter(
      initialLocation: '/equipment/tx-gear',
      routes: [
        ShellRoute(
          builder: (_, _, child) => child,
          routes: [
            GoRoute(
              path: '/equipment/cyl',
              builder: (_, _) => const Scaffold(body: Text('CYLINDER PAGE')),
            ),
            GoRoute(
              path: '/equipment/:id',
              builder: (_, s) => Scaffold(
                body: SingleChildScrollView(
                  child: TransmitterSection(
                    equipmentId: s.pathParameters['id']!,
                  ),
                ),
              ),
              routes: [
                GoRoute(
                  path: 'transmitter',
                  builder: (_, _) => const Scaffold(body: Text('ADD KEY')),
                  routes: [
                    GoRoute(
                      path: ':k',
                      builder: (_, s) =>
                          Scaffold(body: Text('EDIT ${s.pathParameters['k']}')),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          transmittersForEquipmentProvider(
            'tx-gear',
          ).overrideWith((ref) async => keys),
          if (repository != null)
            transmitterRepositoryProvider.overrideWithValue(repository),
          transmitterSlotBackfillProvider.overrideWithValue(
            backfill ?? _FakeBackfill(),
          ),
          equipmentItemProvider('cyl').overrideWith(
            (ref) async => const EquipmentItem(
              id: 'cyl',
              name: 'Blue AL80',
              type: EquipmentType.tank,
            ),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('an auto-created transmitter says no cylinder is set up', (
    tester,
  ) async {
    await pump(tester, [key(configured: false)]);

    expect(find.text('No cylinder set up'), findsOneWidget);
    expect(find.text('Transmitter 4A21F'), findsOneWidget);
  });

  testWidgets('a set-up transmitter names its cylinder and role', (
    tester,
  ) async {
    await pump(tester, [key(cylinder: 'cyl')]);

    expect(find.text('No cylinder set up'), findsNothing);
    expect(find.text('Blue AL80'), findsOneWidget);
    expect(find.textContaining('Stage'), findsOneWidget);
  });

  testWidgets('Set up opens the key in the setup editor', (tester) async {
    await pump(tester, [key(configured: false)]);

    await tester.tap(find.text('Set up'));
    await tester.pumpAndSettle();

    expect(find.text('EDIT k1'), findsOneWidget);
  });

  testWidgets('a hand-added transmitter with no key offers to add one', (
    tester,
  ) async {
    await pump(tester, const []);

    await tester.tap(find.text('Add serial or channel'));
    await tester.pumpAndSettle();

    expect(find.text('ADD KEY'), findsOneWidget);
  });

  testWidgets('tapping a key opens it in the setup editor', (tester) async {
    await pump(tester, [key(id: 'k7', cylinder: 'cyl')]);

    await tester.tap(find.text('Transmitter 4A21F'));
    await tester.pumpAndSettle();

    expect(find.text('EDIT k7'), findsOneWidget);
  });

  testWidgets('the cylinder row opens the cylinder', (tester) async {
    await pump(tester, [key(cylinder: 'cyl')]);

    await tester.tap(find.text('Blue AL80'));
    await tester.pumpAndSettle();

    expect(find.text('CYLINDER PAGE'), findsOneWidget);
  });

  group('Apply to existing dives', () {
    testWidgets('says so when no cylinder carries the transmitter', (
      tester,
    ) async {
      final repo = _FakeApplyRepository(
        preview: (tanksUpdated: 0, divesUpdated: 0, mixesKept: 0),
      );
      await pump(tester, [key(cylinder: 'cyl')], repository: repo);

      await tester.tap(find.text('Apply to existing dives'));
      await tester.pumpAndSettle();

      expect(find.text('No cylinders carry this transmitter'), findsOneWidget);
      expect(repo.applied, isEmpty);
    });

    testWidgets('applies every key once confirmed', (tester) async {
      final repo = _FakeApplyRepository(
        preview: (tanksUpdated: 2, divesUpdated: 2, mixesKept: 0),
      );
      await pump(tester, [
        key(id: 'k1', cylinder: 'cyl'),
        key(id: 'k2', cylinder: 'cyl'),
      ], repository: repo);

      await tester.tap(find.text('Apply to existing dives'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('4 cylinders on 4 dives carry this transmitter'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
      await tester.pumpAndSettle();

      expect(repo.applied, ['k1', 'k2']);
      expect(find.text('Updated 4 cylinders on 4 dives'), findsOneWidget);
    });

    testWidgets('cancelling applies nothing', (tester) async {
      final repo = _FakeApplyRepository(
        preview: (tanksUpdated: 2, divesUpdated: 2, mixesKept: 0),
      );
      await pump(tester, [key(cylinder: 'cyl')], repository: repo);

      await tester.tap(find.text('Apply to existing dives'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(repo.applied, isEmpty);
    });

    testWidgets('slot matches are backfilled first and applied as the dialog '
        'showed them (#4347)', (tester) async {
      final repo = _FakeApplyRepository(
        preview: (tanksUpdated: 1, divesUpdated: 1, mixesKept: 0),
        slots: TransmitterSlotPreview(
          candidates: [
            const SlotCandidate(tankId: 'a-t', diveId: 'a', computerId: 'pd'),
            SlotCandidate(
              tankId: 'b-t',
              diveId: 'b',
              computerId: 'pd',
              olderThanFirstDownload: true,
              firstDownload: DateTime.utc(2026, 3, 12),
            ),
          ],
          computerNames: const {'pd': 'Perdix 2'},
        ),
      );
      final backfill = _FakeBackfill();
      await pump(
        tester,
        [key(cylinder: 'cyl')],
        repository: repo,
        backfill: backfill,
      );

      await tester.tap(find.text('Apply to existing dives'));
      await tester.pumpAndSettle();
      expect(backfill.runs, [
        {'pd'},
      ]);
      expect(find.text('2 dives by slot on Perdix 2'), findsOneWidget);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
      await tester.pumpAndSettle();

      expect(repo.slotTankIdsApplied, [
        {'a-t'},
      ]);
      expect(find.text('Updated 1 cylinders on 1 dives'), findsOneWidget);
    });

    testWidgets('nothing left to learn runs no backfill and shows no '
        'progress', (tester) async {
      final repo = _FakeApplyRepository(
        preview: (tanksUpdated: 1, divesUpdated: 1, mixesKept: 0),
        slots: const TransmitterSlotPreview(
          candidates: [
            SlotCandidate(tankId: 'a-t', diveId: 'a', computerId: 'pd'),
          ],
        ),
      );
      final backfill = _FakeBackfill(pending: 0);
      await pump(
        tester,
        [key(cylinder: 'cyl')],
        repository: repo,
        backfill: backfill,
      );

      await tester.tap(find.text('Apply to existing dives'));
      await tester.pump();
      expect(
        find.text('Reading transmitter slots from your dives'),
        findsNothing,
      );
      await tester.pumpAndSettle();
      expect(backfill.runs, isEmpty);
      expect(find.text('Apply to existing dives?'), findsOneWidget);
    });

    testWidgets('a second tap while the first is running starts nothing', (
      tester,
    ) async {
      final repo = _FakeApplyRepository(
        preview: (tanksUpdated: 1, divesUpdated: 1, mixesKept: 0),
        slots: const TransmitterSlotPreview(
          candidates: [
            SlotCandidate(tankId: 'a-t', diveId: 'a', computerId: 'pd'),
          ],
        ),
      );
      final backfill = _FakeBackfill();
      repo.gate = Completer<void>();
      await pump(
        tester,
        [key(cylinder: 'cyl')],
        repository: repo,
        backfill: backfill,
      );

      await tester.tap(find.text('Apply to existing dives'));
      await tester.pump();
      await tester.tap(find.text('Apply to existing dives'));
      await tester.pump();
      repo.gate!.complete();
      await tester.pumpAndSettle();
      // One flow looks the serial up before the backfill and again after it.
      expect(repo.serialLookups, 2);
      expect(backfill.runs, hasLength(1));
      expect(find.text('Apply to existing dives?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('a Cloud database computer is backfilled before any of its '
        'tanks carries the serial', (tester) async {
      final repo = _FakeApplyRepository(
        preview: (tanksUpdated: 1, divesUpdated: 1, mixesKept: 0),
      );
      final backfill = _FakeBackfill(dbComputers: const {'teric'});
      await pump(
        tester,
        [key(cylinder: 'cyl')],
        repository: repo,
        backfill: backfill,
      );

      await tester.tap(find.text('Apply to existing dives'));
      await tester.pumpAndSettle();
      expect(backfill.runs, [
        {'teric'},
      ]);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('the slot preview sees the computers the backfill gave the '
        'serial, scoped to the key\'s diver', (tester) async {
      final repo = _FakeApplyRepository(
        preview: (tanksUpdated: 1, divesUpdated: 1, mixesKept: 0),
      );
      final backfill = _FakeBackfill(dbComputers: const {'teric'});
      // No tank carries the serial until the backfill writes it.
      repo.computers = () => backfill.runs.isEmpty ? <String>{} : {'teric'};
      await pump(
        tester,
        [key(cylinder: 'cyl', diverId: 'diver-1')],
        repository: repo,
        backfill: backfill,
      );

      await tester.tap(find.text('Apply to existing dives'));
      await tester.pumpAndSettle();
      expect(repo.previewComputerIds, [
        {'teric'},
      ]);
      expect(repo.serialLookupDivers.toSet(), {'diver-1'});
      expect(backfill.divers.toSet(), {'diver-1'});
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('a progress dialog shows while the slots are read, then the '
        'Apply dialog', (tester) async {
      final repo = _FakeApplyRepository(
        preview: (tanksUpdated: 1, divesUpdated: 1, mixesKept: 0),
      );
      final backfill = _FakeBackfill()..gate = Completer<void>();
      await pump(
        tester,
        [key(cylinder: 'cyl')],
        repository: repo,
        backfill: backfill,
      );

      await tester.tap(find.text('Apply to existing dives'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Reading transmitter slots from your dives'), findsOne);
      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, 0.5);

      backfill.gate!.complete();
      await tester.pumpAndSettle();
      expect(
        find.text('Reading transmitter slots from your dives'),
        findsNothing,
      );
      expect(find.text('Apply to existing dives?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('a failed backfill closes its dialog and still offers the '
        'apply', (tester) async {
      final repo = _FakeApplyRepository(
        preview: (tanksUpdated: 1, divesUpdated: 1, mixesKept: 0),
      );
      final backfill = _FakeBackfill(error: StateError('database closed'));
      await pump(
        tester,
        [key(cylinder: 'cyl')],
        repository: repo,
        backfill: backfill,
      );

      await tester.tap(find.text('Apply to existing dives'));
      await tester.pumpAndSettle();
      expect(
        find.text('Reading transmitter slots from your dives'),
        findsNothing,
      );
      expect(find.text('Apply to existing dives?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('a failed apply says so', (tester) async {
      final repo = _FakeApplyRepository(
        preview: (tanksUpdated: 2, divesUpdated: 2, mixesKept: 0),
        failApply: true,
      );
      await pump(tester, [key(cylinder: 'cyl')], repository: repo);

      await tester.tap(find.text('Apply to existing dives'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
      await tester.pumpAndSettle();

      expect(find.textContaining('database closed'), findsOneWidget);
    });
  });
}
