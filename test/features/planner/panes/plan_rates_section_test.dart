import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_rates_section.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/test_app.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier({DepthUnit depthUnit = DepthUnit.meters})
    : super(AppSettings(depthUnit: depthUnit));

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('shows all five rate sliders reflecting plan state', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        overrides: [
          settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
        ],
        child: const SingleChildScrollView(child: PlanRatesSection()),
      ),
    );
    await tester.pumpAndSettle();

    // Working ascent, the two deco bands, the final stretch, and descent.
    expect(find.byType(Slider), findsNWidgets(5));
    expect(find.text('9 m/min'), findsOneWidget); // bottom to first stop
    expect(find.text('6 m/min'), findsOneWidget); // between intermediate stops
    expect(find.text('3 m/min'), findsOneWidget); // between shallow stops
    expect(find.text('1 m/min'), findsOneWidget); // last stop to surface
    expect(find.text('18 m/min'), findsOneWidget); // descent

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanRatesSection)),
    );
    final sliders = tester.widgetList<Slider>(find.byType(Slider)).toList();
    // Each slider must drive its own rate: five controls in one column are
    // easy to wire to the wrong callback, and the mistake would be invisible
    // until a schedule came out wrong.
    sliders[0].onChanged!(12);
    sliders[1].onChanged!(7);
    sliders[2].onChanged!(4);
    sliders[3].onChanged!(2);
    sliders[4].onChanged!(20);
    await tester.pumpAndSettle();

    final state = container.read(divePlanNotifierProvider);
    expect(state.ascentRate, 12);
    expect(state.intermediateAscentRate, 7);
    expect(state.shallowAscentRate, 4);
    expect(state.finalAscentRate, 2);
    expect(state.descentRate, 20);
  });

  testWidgets('displays and edits rates in ft/min when depth unit is feet', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        overrides: [
          settingsProvider.overrideWith(
            (ref) => _TestSettingsNotifier(depthUnit: DepthUnit.feet),
          ),
        ],
        child: const SingleChildScrollView(child: PlanRatesSection()),
      ),
    );
    await tester.pumpAndSettle();

    // Defaults shown converted to whole ft/min, with no m/min text. These are
    // the TDI rates a diver taught in imperial would recognise: 30 / 20 / 10
    // off the bottom and down the stops, 3 over the last stretch.
    expect(find.text('30 ft/min'), findsOneWidget); // 9 m/min
    expect(find.text('20 ft/min'), findsOneWidget); // 6 m/min
    expect(find.text('10 ft/min'), findsOneWidget); // 3 m/min
    expect(find.text('3 ft/min'), findsOneWidget); // 1 m/min
    expect(find.text('59 ft/min'), findsOneWidget); // 18 m/min descent
    expect(find.textContaining('m/min'), findsNothing);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanRatesSection)),
    );
    // Editing in ft/min stores the converted m/min value.
    final ascent = tester.widgetList<Slider>(find.byType(Slider)).first;
    ascent.onChanged!(33); // 33 ft/min
    await tester.pumpAndSettle();
    expect(
      container.read(divePlanNotifierProvider).ascentRate,
      closeTo(33 / 3.28084, 0.001),
    );
  });
}
