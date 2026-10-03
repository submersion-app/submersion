import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/nav_track/data/repositories/nav_track_repository.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/nav_track_fixtures.dart';
import '../../../../helpers/test_database.dart';

/// Links fail on Save; everything else is the real database.
class _FailingLinkRepository extends NavTrackRepository {
  @override
  Future<bool> link(
    String routeId,
    String diveId, {
    required NavTrackLinkMode linkMode,
  }) async => throw StateError('disk full');
}

/// The Dive Edit page stages underwater route links and writes them only on
/// Save (spec 2026-10-02-underwater-route-entry-points-design.md, section
/// 1). Driven against a real database so the assertions are on stored rows.
void main() {
  late DiveRepository dives;
  late NavTrackRepository routes;

  setUp(() async {
    await setUpTestDatabase();
    dives = DiveRepository();
    routes = NavTrackRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  final routeRow = find.byKey(const ValueKey('dive-edit-route-row'));
  final plannedSwitch = find.byKey(const Key('dive_edit_planned_switch'));

  Future<String> insertRoute({String? diveId}) => routes.insertImportedRoute(
    points: kTestNavTrackPoints,
    source: NavTrackSource.seacraftEnc,
    sourceRef: 'wreck.csv',
    name: 'Wreck tour',
    diveId: diveId,
  );

  Future<Dive> insertDive({bool isPlanned = false}) => dives.createDive(
    Dive(
      id: 'dive-route',
      dateTime: DateTime.utc(2025, 8, 22, 10),
      maxDepth: 20.0,
      isPlanned: isPlanned,
    ),
  );

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  // Bounded pumps: the new-dive path starts a GPS capture and the save path
  // shows a snackbar, so pumpAndSettle never returns (see
  // dive_edit_planned_switch_test.dart).
  Future<void> pumpSteps(WidgetTester tester, [int steps = 20]) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pumpEditor(
    WidgetTester tester, {
    String? diveId,
    List<String>? bulkDiveIds,
    VoidCallback? onCancel,
    void Function(String)? onSaved,
    List<Override> extraOverrides = const [],
  }) async {
    tester.platformDispatcher.localesTestValue = const [
      Locale('fr'),
      Locale('en'),
    ];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    tester.view.physicalSize = const Size(950, 8000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides.cast<Override>(),
          diveRepositoryProvider.overrideWithValue(dives),
          diveListNotifierProvider.overrideWith(
            (ref) => DiveListNotifier(dives, ref),
          ),
          customTankPresetsProvider.overrideWith((ref) async => []),
          ...extraOverrides,
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DiveEditPage(
              diveId: diveId,
              bulkDiveIds: bulkDiveIds,
              embedded: true,
              onCancel: onCancel,
              onSaved: onSaved,
            ),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> linkWreckTour(WidgetTester tester) async {
    await tester.ensureVisible(routeRow);
    await tester.tap(routeRow);
    await pumpSteps(tester);
    await tester.tap(find.byKey(const ValueKey('route-sheet-link-button')));
    await pumpSteps(tester);
    await tester.tap(find.text('Wreck tour').last);
    await pumpSteps(tester);
    // Close the route sheet by tapping its barrier.
    await tester.tapAt(const Offset(5, 5));
    await pumpSteps(tester);
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('Save'));
    await pumpSteps(tester, 40);
  }

  testWidgets('linking in the sheet writes nothing until Save, then links', (
    tester,
  ) async {
    final dive = await insertDive();
    final routeId = await insertRoute();
    await pumpEditor(tester, diveId: dive.id);

    await linkWreckTour(tester);
    expect(find.text('Wreck tour'), findsOneWidget);
    expect(await routes.getForDive(dive.id), isEmpty);

    await save(tester);

    final linked = await routes.getForDive(dive.id);
    expect(linked.map((r) => r.id), [routeId]);
    expect(linked.single.linkMode, NavTrackLinkMode.manual);
  });

  testWidgets('removing a linked route unlinks it on Save', (tester) async {
    final dive = await insertDive();
    final routeId = await insertRoute(diveId: dive.id);
    await pumpEditor(tester, diveId: dive.id);
    expect(find.text('Wreck tour'), findsOneWidget);

    await tester.ensureVisible(routeRow);
    await tester.tap(routeRow);
    await pumpSteps(tester);
    await tester.tap(find.byKey(ValueKey('route-sheet-remove-$routeId')));
    await pumpSteps(tester);
    await tester.tapAt(const Offset(5, 5));
    await pumpSteps(tester);
    await save(tester);

    expect(await routes.getForDive(dive.id), isEmpty);
  });

  testWidgets('a new dive gets its staged route once it has an id', (
    tester,
  ) async {
    final routeId = await insertRoute();
    await pumpEditor(tester);

    await linkWreckTour(tester);
    await save(tester);

    final saved = (await dives.getAllDives()).single;
    expect((await routes.getForDive(saved.id)).map((r) => r.id), [routeId]);
  });

  testWidgets('a staged link marks the form unsaved', (tester) async {
    final dive = await insertDive();
    await insertRoute();
    var cancelled = 0;
    await pumpEditor(tester, diveId: dive.id, onCancel: () => cancelled++);

    await linkWreckTour(tester);
    await tester.tap(find.text('Cancel'));
    await pumpSteps(tester);

    // The discard guard asks first instead of cancelling straight away.
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(cancelled, 0);
  });

  testWidgets('discarding the edit after linking writes no link', (
    tester,
  ) async {
    final dive = await insertDive();
    final routeId = await insertRoute();
    var cancelled = 0;
    await pumpEditor(tester, diveId: dive.id, onCancel: () => cancelled++);

    await linkWreckTour(tester);
    await tester.tap(find.text('Cancel'));
    await pumpSteps(tester);
    await tester.tap(find.text('Discard'));
    await pumpSteps(tester);

    expect(cancelled, 1);
    expect(await routes.getForDive(dive.id), isEmpty);
    final route = await routes.getById(routeId, includePoints: false);
    expect(route!.diveId, isNull);
  });

  testWidgets('a link that fails on Save is reported, and the dive still '
      'saves', (tester) async {
    final dive = await insertDive();
    await insertRoute();
    String? savedId;
    await pumpEditor(
      tester,
      diveId: dive.id,
      onSaved: (id) => savedId = id,
      extraOverrides: [
        navTrackRepositoryProvider.overrideWithValue(_FailingLinkRepository()),
      ],
    );

    await linkWreckTour(tester);
    await save(tester);

    expect(savedId, dive.id);
    expect(
      find.textContaining("Could not update this dive's underwater tracks"),
      findsOneWidget,
    );
  });

  testWidgets('a route something else linked before Save is left where it '
      'is, and the dive still saves without an error', (tester) async {
    final dive = await insertDive();
    final other = await dives.createDive(
      Dive(id: 'dive-other', dateTime: DateTime.utc(2025, 8, 21, 10)),
    );
    final routeId = await insertRoute();
    String? savedId;
    await pumpEditor(tester, diveId: dive.id, onSaved: (id) => savedId = id);

    await linkWreckTour(tester);
    // Sync (or the new-dive auto-link) links it elsewhere first.
    await routes.link(routeId, other.id, linkMode: NavTrackLinkMode.manual);
    await save(tester);

    expect(savedId, dive.id);
    expect(
      find.textContaining("Could not update this dive's underwater tracks"),
      findsNothing,
    );
    final route = await routes.getById(routeId, includePoints: false);
    expect(route!.diveId, other.id);
  });

  testWidgets('a dive whose routes fail to load says so on the row', (
    tester,
  ) async {
    final dive = await insertDive();
    await pumpEditor(
      tester,
      diveId: dive.id,
      extraOverrides: [
        navTracksForDiveProvider(
          dive.id,
        ).overrideWith((ref) async => throw StateError('db closed')),
      ],
    );
    await pumpSteps(tester);

    expect(find.text('Could not load underwater tracks'), findsOneWidget);
  });

  testWidgets('a planned dive has no route row', (tester) async {
    final dive = await insertDive(isPlanned: true);
    await pumpEditor(tester, diveId: dive.id);

    expect(routeRow, findsNothing);
  });

  testWidgets('switching to planned after linking saves no link', (
    tester,
  ) async {
    final routeId = await insertRoute();
    await pumpEditor(tester);

    await linkWreckTour(tester);
    await tester.ensureVisible(plannedSwitch);
    await tester.tap(plannedSwitch);
    await pumpSteps(tester);
    expect(routeRow, findsNothing);
    await save(tester);

    final route = await routes.getById(routeId, includePoints: false);
    expect(route!.diveId, isNull);
  });

  testWidgets('bulk edit has no route row', (tester) async {
    final first = await insertDive();
    final second = await dives.createDive(
      Dive(id: 'dive-route-2', dateTime: DateTime.utc(2025, 8, 23, 10)),
    );
    await pumpEditor(tester, bulkDiveIds: [first.id, second.id]);

    expect(routeRow, findsNothing);
  });
}
