import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/presentation/chart/plan_stop_tags.dart';
import 'package:submersion/features/planner/presentation/widgets/contingency_chips.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_chart_readouts.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_stop_list.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../helpers/test_app.dart';
import '../../helpers/test_database.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() {
    DatabaseService.instance.resetForTesting();
  });

  var issuesTapped = false;

  Widget harness({List<dynamic> extraOverrides = const []}) {
    issuesTapped = false;
    return testApp(
      overrides: [
        settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
        ...extraOverrides,
      ],
      locale: const Locale('en'),
      child: Scaffold(
        body: Stack(
          children: [
            const Positioned.fill(child: ColoredBox(color: Colors.black12)),
            PlanChartReadouts(onIssuesTap: () => issuesTapped = true),
          ],
        ),
      ),
    );
  }

  void seed(WidgetTester tester, {required double depth, required int time}) {
    ProviderScope.containerOf(tester.element(find.byType(PlanChartReadouts)))
        .read(divePlanNotifierProvider.notifier)
        .addSimplePlan(maxDepth: depth, bottomTimeMinutes: time);
  }

  testWidgets('shallow plan shows runtime and NDL, no TTS or deco', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    seed(tester, depth: 12, time: 20);
    await tester.pumpAndSettle();

    expect(find.text('Runtime'), findsOneWidget);
    expect(find.text('NDL'), findsOneWidget);
    expect(find.text('TTS'), findsNothing);
    expect(find.text('DECO'), findsNothing);
    expect(find.textContaining('CNS'), findsOneWidget);
  });

  testWidgets('deco plan shows TTS and DECO; issues pill taps through', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    // A deep air plan trips a critical gas-density issue and mandatory deco,
    // so TTS/DECO render and the issues pill has a tap target.
    seed(tester, depth: 50, time: 25);
    await tester.pumpAndSettle();

    expect(find.text('TTS'), findsOneWidget);
    expect(find.text('DECO'), findsOneWidget);
    expect(find.text('NDL'), findsNothing);

    await tester.tap(find.textContaining('issue'));
    await tester.pumpAndSettle();
    expect(issuesTapped, isTrue);
  });

  testWidgets('a deco plan lists its stops under CNS', (tester) async {
    await tester.pumpWidget(harness());
    seed(tester, depth: 50, time: 25);
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanChartReadouts)),
    );
    final list = tester.widget<PlanStopList>(find.byType(PlanStopList));
    expect(list.tags, isNotEmpty);
    expect(list.tags, container.read(planReadoutStopTagsProvider));
    final cns = find.byWidgetPredicate(
      (w) => w is Text && (w.data ?? '').startsWith('CNS'),
    );
    expect(
      tester.getBottomLeft(cns).dy,
      lessThanOrEqualTo(tester.getTopLeft(find.byType(PlanStopList)).dy),
    );
    expect(
      tester.getBottomLeft(find.byType(PlanStopList)).dy,
      lessThanOrEqualTo(tester.getTopLeft(find.textContaining('issue')).dy),
    );
  });

  Future<double> pumpChart(
    WidgetTester tester,
    double height, {
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      testApp(
        overrides: [
          settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
        ],
        locale: const Locale('en'),
        child: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                key: const Key('chart'),
                height: height,
                child: Stack(
                  children: [
                    const Positioned.fill(
                      child: ColoredBox(color: Colors.black12),
                    ),
                    PlanChartReadouts(onIssuesTap: () {}),
                    // As the phone chart lays them out.
                    const Positioned(
                      left: 8,
                      right: 56,
                      bottom: 8,
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: ContingencyChips(overlay: true),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    seed(tester, depth: 50, time: 25);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    return tester.getBottomLeft(find.byKey(const Key('chart'))).dy;
  }

  testWidgets('the stop list gives up rows to keep the bottom row clear', (
    tester,
  ) async {
    final chartBottom = await pumpChart(tester, 230);

    // The chips and the full-screen button take the chart's foot.
    final limit =
        chartBottom -
        PlanChartReadouts.bottomClearanceFor(TextScaler.noScaling);
    expect(
      tester.getBottomLeft(find.textContaining('issue')).dy,
      lessThanOrEqualTo(limit),
    );
    expect(find.text('3m'), findsOneWidget);
  });

  testWidgets('a chart too short for a row shows no list and no overflow', (
    tester,
  ) async {
    await pumpChart(tester, 160);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanChartReadouts)),
    );

    expect(find.text('3m'), findsNothing);
    expect(find.textContaining('CNS'), findsOneWidget);
    // So the chart tags the stops itself rather than showing none.
    expect(container.read(phoneStopListFitsProvider), isFalse);

    await pumpChart(tester, 230);
    expect(container.read(phoneStopListFitsProvider), isTrue);
  });

  testWidgets('at large text sizes the list stops above the chips', (
    tester,
  ) async {
    final chartBottom = await pumpChart(tester, 520, textScale: 3);

    final chipsTop = tester.getTopLeft(find.byType(ContingencyChips)).dy;
    // The chips grew past the 56 dp strip a fixed clearance kept free.
    expect(chartBottom - chipsTop, greaterThan(56));
    expect(find.text('3m'), findsOneWidget);
    expect(
      tester.getBottomLeft(find.textContaining('issue')).dy,
      lessThanOrEqualTo(chipsTop),
    );
  });

  testWidgets('a no-stop plan has no stop list', (tester) async {
    await tester.pumpWidget(harness());
    seed(tester, depth: 12, time: 20);
    await tester.pumpAndSettle();

    expect(
      tester.widget<PlanStopList>(find.byType(PlanStopList)).tags,
      isEmpty,
    );
  });

  testWidgets('CNS readout tints orange at the warning threshold', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        extraOverrides: [cnsWarningThresholdProvider.overrideWithValue(0)],
      ),
    );
    seed(tester, depth: 30, time: 20);
    await tester.pumpAndSettle();

    final cns = tester.widget<Text>(
      find.byWidgetPredicate(
        (w) => w is Text && (w.data ?? '').startsWith('CNS'),
      ),
    );
    expect(cns.style?.color, Colors.orange);
  });
}
