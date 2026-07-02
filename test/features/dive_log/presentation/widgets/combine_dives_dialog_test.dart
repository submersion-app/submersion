import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/presentation/widgets/dive_sparkline.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/dive_merge_service.dart';
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
}) => domain.Dive(
  id: id,
  diverId: diverId,
  dateTime: entry,
  entryTime: entry,
  runtime: Duration(minutes: runtimeMin),
  profile: profile,
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
  Future<List<domain.Dive>> getDivesByIds(List<String> ids) async => dives;

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
  List<String>? requestIds,
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
        diveRepositoryProvider.overrideWithValue(_FakeDiveRepository(dives)),
        settingsProvider.overrideWith((ref) => _FakeSettingsNotifier()),
        if (mergeService != null)
          diveMergeServiceProvider.overrideWithValue(mergeService),
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

  testWidgets('overlapping selection shows the explanation panel', (
    tester,
  ) async {
    await pumpCombineDialog(
      tester,
      dives: [
        diveAt('a', DateTime.utc(2026, 7, 1, 9), runtimeMin: 90),
        diveAt('b', DateTime.utc(2026, 7, 1, 10)),
      ],
    );
    expect(find.text('These dives overlap in time'), findsOneWidget);
    expect(find.text('Combine into one dive'), findsNothing);
    // 2 dives selected -> hint at the existing per-dive merge action.
    expect(find.textContaining('Merge with another dive'), findsOneWidget);
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
