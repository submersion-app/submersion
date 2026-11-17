import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/deco/entities/breathing_config.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_number_field.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/presentation/widgets/pscr_settings_section.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/test_app.dart';

void main() {
  testWidgets('reflects a pSCR ratio that changes after init (async load)', (
    tester,
  ) async {
    final notifier = MockSettingsNotifier();
    await tester.pumpWidget(
      testApp(
        overrides: [settingsProvider.overrideWith((ref) => notifier)],
        child: const PscrSettingsSection(),
      ),
    );
    await tester.pumpAndSettle();

    // Starts at the default while "settings load".
    expect(find.widgetWithText(TextFormField, '100'), findsOneWidget);

    // The loaded/changed value propagates into the field (the bug Copilot
    // flagged: an init-once controller would still show 100).
    await notifier.setPscrRatio(250);
    await tester.pump();
    expect(find.widgetWithText(TextFormField, '250'), findsOneWidget);
  });

  testWidgets('persists the final value after debounce, not per keystroke', (
    tester,
  ) async {
    final notifier = MockSettingsNotifier();
    await tester.pumpWidget(
      testApp(
        overrides: [settingsProvider.overrideWith((ref) => notifier)],
        child: const PscrSettingsSection(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '180');
    // Before the debounce elapses nothing is persisted (no per-keystroke
    // save storm / overlapping writes).
    await tester.pump(const Duration(milliseconds: 100));
    expect(notifier.state.pscrRatio, 100.0);

    // After the debounce, the final value lands exactly once.
    await tester.pump(const Duration(milliseconds: 300));
    expect(notifier.state.pscrRatio, 180.0);
  });

  testWidgets('clearing the field before the debounce drops the pending edit', (
    tester,
  ) async {
    final notifier = MockSettingsNotifier();
    await tester.pumpWidget(
      testApp(
        overrides: [settingsProvider.overrideWith((ref) => notifier)],
        child: const PscrSettingsSection(),
      ),
    );
    await tester.pumpAndSettle();

    // Type a valid value, then clear the field before the debounce elapses.
    await tester.enterText(find.byType(TextFormField), '180');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextFormField), '');

    // The now-deleted 180 must not flush after the delay: invalid/empty input
    // cancels the pending save (regression for the stale-flush bug).
    await tester.pump(const Duration(milliseconds: 400));
    expect(notifier.state.pscrRatio, 100.0);
  });

  group('pSCR VO2 (#4660)', () {
    Future<ProviderContainer> pump(WidgetTester tester) async {
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          ],
          child: const SizedBox(width: 500, child: PscrSettingsSection()),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PscrSettingsSection)),
      );
      container
          .read(divePlanNotifierProvider.notifier)
          .updateMode(domain.PlanMode.pscr);
      await tester.pumpAndSettle();
      return container;
    }

    Finder vo2Field() => find.descendant(
      of: find.byType(PlanNumberField),
      matching: find.byType(TextField),
    );

    testWidgets('an empty VO2 shows the diver default as a hint', (
      tester,
    ) async {
      await pump(tester);
      final field = tester.widget<TextField>(vo2Field());
      expect(field.controller!.text, '');
      expect(field.decoration?.hintText, '0.72');
    });

    testWidgets('an imperial diver sees the VO2 hint to three places', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith(
              (ref) => MockSettingsNotifier(
                const AppSettings(volumeUnit: VolumeUnit.cubicFeet),
              ),
            ),
          ],
          child: const SizedBox(width: 500, child: PscrSettingsSection()),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(vo2Field()).decoration?.hintText,
        '0.025',
      );
    });

    testWidgets('typing a VO2 stores it on the plan; clearing follows the '
        'diver again', (tester) async {
      final container = await pump(tester);
      await tester.enterText(vo2Field(), '1.0');
      await tester.pumpAndSettle();
      expect(container.read(divePlanNotifierProvider).pscrVo2, 1.0);

      await tester.enterText(vo2Field(), '');
      await tester.pumpAndSettle();
      expect(container.read(divePlanNotifierProvider).pscrVo2, isNull);
    });

    testWidgets('shows the inspired ppO2 drop for the loop', (tester) async {
      await pump(tester);
      final drop = PassiveScr(
        supplyFO2: 0.21,
        o2ConsumptionMlMin: 720,
        sacMlMin: 15000,
      ).o2DropBar;
      expect(
        find.text('Loop ppO₂ drop: ${drop.toStringAsFixed(2)} bar'),
        findsOneWidget,
      );
    });

    testWidgets('the drop follows the locale decimal separator', (
      tester,
    ) async {
      // The app sets Intl.defaultLocale from the diver's language; a comma
      // locale must not read "0.38" beside every other "0,38" on screen.
      final previous = Intl.defaultLocale;
      Intl.defaultLocale = 'de';
      addTearDown(() => Intl.defaultLocale = previous);
      await pump(tester);
      final drop = PassiveScr(
        supplyFO2: 0.21,
        o2ConsumptionMlMin: 720,
        sacMlMin: 15000,
      ).o2DropBar;
      expect(
        find.text(
          'Loop ppO₂ drop: ${drop.toStringAsFixed(2).replaceAll('.', ',')} bar',
        ),
        findsOneWidget,
      );
    });
  });
}
