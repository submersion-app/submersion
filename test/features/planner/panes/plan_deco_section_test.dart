import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_deco_section.dart';
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
  testWidgets(
    'toggling the switch sets the 12/6 default, and editing the O2 field updates it',
    (tester) async {
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: const SingleChildScrollView(child: PlanDecoSection()),
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(PlanDecoSection)),
      );

      expect(container.read(divePlanNotifierProvider).airBreaks, isNull);
      // The minute fields are not shown until air breaks are enabled.
      expect(find.byType(TextField), findsNothing);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      final enabled = container.read(divePlanNotifierProvider).airBreaks;
      expect(enabled, isNotNull);
      expect(enabled!.o2Seconds, 12 * 60);
      expect(enabled.breakSeconds, 6 * 60);

      // Prefilled with the default 12 / 6 minutes.
      expect(find.text('12'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, '20');
      await tester.pumpAndSettle();

      final updated = container.read(divePlanNotifierProvider).airBreaks;
      expect(updated!.o2Seconds, 20 * 60);
      // The break side is untouched by editing the O2 field.
      expect(updated.breakSeconds, 6 * 60);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(container.read(divePlanNotifierProvider).airBreaks, isNull);
      expect(find.byType(TextField), findsNothing);
    },
  );
}
