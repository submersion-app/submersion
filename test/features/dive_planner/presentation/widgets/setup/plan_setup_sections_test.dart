import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_deco_section.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_environment_section.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_gas_section.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../../helpers/test_app.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _harness(Widget child) => testApp(
  // Pin English so finders on localized labels ("Must be greater than 0",
  // "Group 2", etc.) stay deterministic regardless of the platform locale.
  locale: const Locale('en'),
  overrides: [settingsProvider.overrideWith((ref) => _TestSettingsNotifier())],
  child: SingleChildScrollView(child: child),
);

void main() {
  testWidgets('deco section renders both GF sliders with defaults', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(const PlanDecoSection()));
    await tester.pumpAndSettle();
    expect(find.byType(Slider), findsNWidgets(2));
    expect(find.text('30%'), findsOneWidget);
    expect(find.text('70%'), findsOneWidget);
  });

  testWidgets('gas section shows SAC slider and reserve field with unit', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(const PlanGasSection()));
    await tester.pumpAndSettle();
    expect(find.byType(Slider), findsOneWidget);
    expect(find.text('50'), findsOneWidget);
    expect(find.textContaining('bar'), findsWidgets);
  });

  testWidgets('reserve validation: zero shows error, valid updates state', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(const PlanGasSection()));
    await tester.pumpAndSettle();
    final field = find.byType(TextField).last;
    await tester.enterText(field, '0');
    await tester.pumpAndSettle();
    expect(find.text('Must be greater than 0'), findsOneWidget);
    await tester.enterText(field, '60');
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanGasSection)),
    );
    expect(container.read(divePlanNotifierProvider).reservePressure, 60);
  });

  testWidgets('environment section shows altitude group chip at 1000m', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_harness(const PlanEnvironmentSection()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '1000');
    await tester.pumpAndSettle();
    expect(find.textContaining('Group 2'), findsOneWidget);
  });

  testWidgets('no overflow at narrow widths', (tester) async {
    for (final size in const [Size(300, 600), Size(375, 667)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(
        _harness(
          const Column(
            children: [
              PlanDecoSection(),
              PlanGasSection(),
              PlanEnvironmentSection(),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'overflow at $size');
    }
    tester.view.reset();
  });
}
