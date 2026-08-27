import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/presentation/widgets/dive_sparkline.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/dive_consolidation_service.dart';
import 'package:submersion/features/dive_log/data/services/dive_merge_service.dart';
import 'package:submersion/features/dive_log/data/services/dive_merge_snapshot.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/combine_dives_dialog.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Builds a bare-bones dive at [entry] with a [runtimeMin]-minute runtime.
/// Mirrors the `dive()` helper from dive_merge_builder_test.dart.
domain.Dive diveAt(
  String id,
  DateTime entry, {
  int runtimeMin = 30,
  String? diverId = 'diver1',
  List<domain.DiveProfilePoint> profile = const [],
  String? diveComputerModel,
  String? diveComputerSerial,
}) => domain.Dive(
  id: id,
  diverId: diverId,
  dateTime: entry,
  entryTime: entry,
  runtime: Duration(minutes: runtimeMin),
  profile: profile,
  diveComputerModel: diveComputerModel,
  diveComputerSerial: diveComputerSerial,
);

/// A short descend-bottom-ascend profile for the given [runtimeMin].
List<domain.DiveProfilePoint> _profile(int runtimeMin) {
  final end = runtimeMin * 60;
  return [
    const domain.DiveProfilePoint(timestamp: 0, depth: 0),
    domain.DiveProfilePoint(timestamp: end ~/ 2, depth: 15),
    domain.DiveProfilePoint(timestamp: end, depth: 0),
  ];
}

/// Fake [DiveRepository] whose `getDivesByIds` returns canned dives.
class _FakeDiveRepository implements DiveRepository {
  _FakeDiveRepository(this.dives);
  final List<domain.Dive> dives;

  @override
  Future<List<domain.Dive>> getDivesByIds(List<String> ids) async =>
      dives.where((d) => ids.contains(d.id)).toList();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Fake [DiveRepository] whose `getDivesByIds` throws, as the real one does on
/// a DB/query failure.
class _ThrowingDiveRepository implements DiveRepository {
  @override
  Future<List<domain.Dive>> getDivesByIds(List<String> ids) async =>
      throw StateError('load failed');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Fake [DiveMergeService] whose `apply` always fails.
class _ThrowingMergeService implements DiveMergeService {
  @override
  Future<DiveMergeOutcome> apply(List<String> diveIds) async {
    throw StateError('apply failed');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Fake [DiveConsolidationService] that records `apply`/`undo` calls so
/// tests can assert on the wiring contract without touching a real database.
/// Mirrors the fake in merge_dive_dialog_test.dart (the apply-failure path is
/// already covered there, since both dialogs share `runDiveConsolidation`).
class _FakeDiveConsolidationService extends DiveConsolidationService {
  _FakeDiveConsolidationService() : super(DiveRepository());

  String? capturedTargetDiveId;
  List<String>? capturedSecondaryDiveIds;
  DiveMergeSnapshot? undoneSnapshot;

  final DiveMergeSnapshot outcomeSnapshot = const DiveMergeSnapshot(
    mergedDiveId: 'a',
    diveRows: [],
    profileRows: [],
    tankRows: [],
    weightRows: [],
    customFieldRows: [],
    equipmentRows: [],
    diveTypeRows: [],
    tagRows: [],
    buddyRows: [],
    sightingRows: [],
    eventRows: [],
    gasSwitchRows: [],
    tankPressureRows: [],
    dataSourceRows: [],
    tideRows: [],
    mediaDiveIds: {},
  );

  @override
  Future<DiveConsolidationOutcome> apply({
    required String targetDiveId,
    required List<String> secondaryDiveIds,
  }) async {
    capturedTargetDiveId = targetDiveId;
    capturedSecondaryDiveIds = secondaryDiveIds;
    return DiveConsolidationOutcome(
      targetDiveId: targetDiveId,
      snapshot: outcomeSnapshot,
    );
  }

  @override
  Future<void> undo(DiveMergeSnapshot snapshot) async {
    undoneSnapshot = snapshot;
  }
}

/// Minimal SettingsNotifier override that returns default AppSettings.
class _FakeSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _FakeSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Pumps a [MaterialApp] + [ProviderScope] (with l10n delegates wired) and
/// opens the [CombineDivesDialog] via [showCombineDivesDialog].
Future<void> pumpCombineDialog(
  WidgetTester tester, {
  required List<domain.Dive> dives,
  DiveMergeService? mergeService,
  DiveConsolidationService? consolidationService,
  List<String>? requestIds,
  DiveRepository? repository,
}) async {
  tester.view.physicalSize = const Size(1024, 768);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  late BuildContext savedContext;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        diveRepositoryProvider.overrideWithValue(
          repository ?? _FakeDiveRepository(dives),
        ),
        settingsProvider.overrideWith((ref) => _FakeSettingsNotifier()),
        if (mergeService != null)
          diveMergeServiceProvider.overrideWithValue(mergeService),
        if (consolidationService != null)
          diveConsolidationServiceProvider.overrideWithValue(
            consolidationService,
          ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              savedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  showCombineDivesDialog(
    context: savedContext,
    diveIds: requestIds ?? dives.map((d) => d.id).toList(),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sequential selection shows preview and confirm button', (
    tester,
  ) async {
    await pumpCombineDialog(
      tester,
      dives: [
        diveAt('a', DateTime.utc(2026, 7, 1, 9)),
        diveAt('b', DateTime.utc(2026, 7, 1, 10)),
      ],
    );
    expect(find.text('Combine dives'), findsOneWidget);
    expect(find.textContaining('Surface interval'), findsOneWidget);
    expect(find.text('Combine into one dive'), findsOneWidget);
  });

  testWidgets('sequential preview shows a depth-line profile chart when the '
      'sources carry profile data', (tester) async {
    await pumpCombineDialog(
      tester,
      dives: [
        diveAt(
          'a',
          DateTime.utc(2026, 7, 1, 9),
          runtimeMin: 5,
          profile: _profile(5),
        ),
        diveAt(
          'b',
          DateTime.utc(2026, 7, 1, 10),
          runtimeMin: 5,
          profile: _profile(5),
        ),
      ],
    );
    expect(find.text('Combined profile'), findsOneWidget);
    expect(find.byType(DiveSparkline), findsOneWidget);

    // The surface interval is passed as a highlight band so it renders in a
    // distinct colour, apart from the real dive data.
    final sparkline = tester.widget<DiveSparkline>(find.byType(DiveSparkline));
    expect(sparkline.highlightBands, hasLength(1));
    expect(
      sparkline.highlightBands.single.endX,
      greaterThan(sparkline.highlightBands.single.startX),
    );
    // Surface time is shaded green.
    expect(sparkline.highlightColor, Colors.green);
  });

  testWidgets('sequential preview omits the chart when sources have no '
      'profile data', (tester) async {
    await pumpCombineDialog(
      tester,
      dives: [
        diveAt('a', DateTime.utc(2026, 7, 1, 9)),
        diveAt('b', DateTime.utc(2026, 7, 1, 10)),
      ],
    );
    // Still a valid sequential preview...
    expect(find.text('Combine into one dive'), findsOneWidget);
    // ...but no chart to show.
    expect(find.byType(DiveSparkline), findsNothing);
    expect(find.text('Combined profile'), findsNothing);
  });

  testWidgets('shows the error panel when loading the dives fails', (
    tester,
  ) async {
    await pumpCombineDialog(
      tester,
      dives: const [],
      repository: _ThrowingDiveRepository(),
      requestIds: const ['a', 'b'],
    );
    // Not stuck on the spinner; the generic combine error is shown.
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      find.text("Couldn't combine the dives. Nothing was changed."),
      findsOneWidget,
    );
  });

  testWidgets('warns when a surface interval is longer than 30 minutes', (
    tester,
  ) async {
    await pumpCombineDialog(
      tester,
      dives: [
        diveAt('a', DateTime.utc(2026, 7, 1, 9), runtimeMin: 5), // ends 9:05
        diveAt('b', DateTime.utc(2026, 7, 1, 9, 40)), // ~35min surface gap
      ],
    );
    expect(find.textContaining('longer than 30 minutes'), findsOneWidget);
  });

  testWidgets('no long-surface warning for a short surface interval', (
    tester,
  ) async {
    await pumpCombineDialog(
      tester,
      dives: [
        diveAt('a', DateTime.utc(2026, 7, 1, 9), runtimeMin: 5), // ends 9:05
        diveAt('b', DateTime.utc(2026, 7, 1, 9, 20)), // ~15min surface gap
      ],
    );
    expect(find.textContaining('longer than 30 minutes'), findsNothing);
    expect(find.text('Combine into one dive'), findsOneWidget);
  });

  group('overlapping selection -- multi-computer consolidation', () {
    /// Two overlapping dives from different computers, each with a short
    /// profile so the preview chart has something to draw.
    List<domain.Dive> consolidatableDives() => [
      diveAt(
        'a',
        DateTime.utc(2026, 7, 1, 9),
        runtimeMin: 30,
        diveComputerModel: 'Perdix',
        diveComputerSerial: 'serial-a',
        profile: _profile(30),
      ),
      diveAt(
        'b',
        DateTime.utc(2026, 7, 1, 9, 5),
        runtimeMin: 25,
        diveComputerModel: 'Teric',
        diveComputerSerial: 'serial-b',
        profile: _profile(25),
      ),
    ];

    testWidgets(
      'shows a preview chart with both dives\' depth series on the shared '
      'timeline',
      (tester) async {
        await pumpCombineDialog(tester, dives: consolidatableDives());

        expect(find.byType(DiveSparkline), findsOneWidget);
        final sparkline = tester.widget<DiveSparkline>(
          find.byType(DiveSparkline),
        );
        expect(sparkline.profile, isNotEmpty);
        expect(sparkline.extraSeries, hasLength(1));
        expect(sparkline.extraSeries.single.profile, isNotEmpty);
      },
    );

    testWidgets(
      'shows a primary selector with one radio tile per dive, defaulting to '
      'the earliest entry time',
      (tester) async {
        await pumpCombineDialog(tester, dives: consolidatableDives());

        expect(find.byType(RadioListTile<String>), findsNWidgets(2));
        // 'a' (9:00) is earliest -> preselected as the primary via the
        // ancestor RadioGroup.
        final radioGroup = tester.widget<RadioGroup<String>>(
          find.byType(RadioGroup<String>),
        );
        expect(radioGroup.groupValue, 'a');
        expect(find.textContaining('Perdix'), findsOneWidget);
        expect(find.textContaining('Teric'), findsOneWidget);
      },
    );

    testWidgets(
      'confirming calls DiveConsolidationService.apply with the selected '
      'primary as target and shows an Undo snackbar',
      (tester) async {
        final service = _FakeDiveConsolidationService();
        await pumpCombineDialog(
          tester,
          dives: consolidatableDives(),
          consolidationService: service,
        );

        await tester.tap(find.text('Keep as one dive with both computers'));
        await tester.pumpAndSettle();

        expect(service.capturedTargetDiveId, 'a');
        expect(service.capturedSecondaryDiveIds, ['b']);

        // The dialog itself is gone.
        expect(find.text('Combine dives'), findsNothing);

        final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(snackBar.action, isNotNull);
        expect(snackBar.action!.label, 'Undo');
        expect(snackBar.persist, isFalse);
        expect(snackBar.showCloseIcon, isTrue);
      },
    );

    testWidgets(
      'picking the later dive as primary calls apply with that dive as '
      'target',
      (tester) async {
        final service = _FakeDiveConsolidationService();
        await pumpCombineDialog(
          tester,
          dives: consolidatableDives(),
          consolidationService: service,
        );

        await tester.tap(find.textContaining('Teric'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Keep as one dive with both computers'));
        await tester.pumpAndSettle();

        expect(service.capturedTargetDiveId, 'b');
        expect(service.capturedSecondaryDiveIds, ['a']);
      },
    );

    testWidgets(
      'dives sharing a dive computer serial show the sameComputer error '
      'instead of the confirm button',
      (tester) async {
        await pumpCombineDialog(
          tester,
          dives: [
            diveAt(
              'a',
              DateTime.utc(2026, 7, 1, 9),
              runtimeMin: 30,
              diveComputerSerial: 'same-serial',
            ),
            diveAt(
              'b',
              DateTime.utc(2026, 7, 1, 9, 5),
              runtimeMin: 25,
              diveComputerSerial: 'same-serial',
            ),
          ],
        );

        expect(
          find.text(
            "These dives are from the same dive computer and can't be "
            'merged this way.',
          ),
          findsOneWidget,
        );
        expect(find.text('Keep as one dive with both computers'), findsNothing);
      },
    );
  });

  testWidgets('apply failure closes dialog and shows error snackbar', (
    tester,
  ) async {
    await pumpCombineDialog(
      tester,
      dives: [
        diveAt('a', DateTime.utc(2026, 7, 1, 9)),
        diveAt('b', DateTime.utc(2026, 7, 1, 10)),
      ],
      mergeService: _ThrowingMergeService(),
    );

    await tester.tap(find.text('Combine into one dive'));
    await tester.pumpAndSettle();

    // Dialog is gone; failure is surfaced as an error snackbar.
    expect(find.text('Combine dives'), findsNothing);
    expect(
      find.text("Couldn't combine the dives. Nothing was changed."),
      findsOneWidget,
    );
  });

  testWidgets('mixed-diver selection shows the mixed-divers message', (
    tester,
  ) async {
    await pumpCombineDialog(
      tester,
      dives: [
        diveAt('a', DateTime.utc(2026, 7, 1, 9)),
        diveAt('b', DateTime.utc(2026, 7, 1, 10), diverId: 'diver2'),
      ],
    );
    expect(
      find.text(
        "The selected dives belong to different divers and can't be combined.",
      ),
      findsOneWidget,
    );
    expect(find.text('Combine into one dive'), findsNothing);
  });

  testWidgets('selection that loads too few dives shows the generic error, '
      'not the mixed-divers message', (tester) async {
    // Two ids requested, but only one dive still exists by load time
    // (e.g. deleted locally or via sync) -> tooFewDives.
    await pumpCombineDialog(
      tester,
      dives: [diveAt('a', DateTime.utc(2026, 7, 1, 9))],
      requestIds: ['a', 'ghost'],
    );
    expect(
      find.text("Couldn't combine the dives. Nothing was changed."),
      findsOneWidget,
    );
    expect(
      find.text(
        "The selected dives belong to different divers and can't be combined.",
      ),
      findsNothing,
    );
    expect(find.text('Combine into one dive'), findsNothing);
  });
}
