import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_chart_readouts.dart';
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

  testWidgets('following pill shows under runtime and clears on tap', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    seed(tester, depth: 30, time: 20);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanChartReadouts)),
    );
    container
        .read(divePlanNotifierProvider.notifier)
        .setFollowedDive(
          diveId: 'missing-dive',
          surfaceInterval: const Duration(hours: 1),
        );
    await tester.pumpAndSettle();

    expect(find.textContaining('Following'), findsOneWidget);
    await tester.tap(find.textContaining('Following'));
    await tester.pumpAndSettle();
    expect(container.read(divePlanNotifierProvider).sourceDiveId, isNull);
    expect(find.textContaining('Following'), findsNothing);
  });
}
