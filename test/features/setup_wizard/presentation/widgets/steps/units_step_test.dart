import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/setup_wizard/domain/setup_wizard_models.dart';
import 'package:submersion/features/setup_wizard/presentation/providers/setup_wizard_providers.dart';
import 'package:submersion/features/setup_wizard/presentation/widgets/steps/units_step.dart';

import '../../../../../helpers/test_app.dart';

void main() {
  testWidgets('preset toggle drives the draft units', (tester) async {
    tester.binding.platformDispatcher.localeTestValue = const Locale(
      'de',
      'DE',
    );
    addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);

    late ProviderContainer container;
    await tester.pumpWidget(
      testApp(
        // UI pinned to English; the device locale set above only drives
        // presetForLocale, not the labels this test taps.
        locale: const Locale('en'),
        child: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return const UnitsStep(mode: SetupWizardMode.firstRun);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Imperial'));
    await tester.pumpAndSettle();

    final draft = container.read(setupWizardProvider(SetupWizardMode.firstRun));
    expect(draft.settings.unitPreset, UnitPreset.imperial);
    expect(draft.settings.depthUnit, DepthUnit.feet);
  });

  testWidgets('advanced expander exposes per-unit overrides', (tester) async {
    tester.binding.platformDispatcher.localeTestValue = const Locale(
      'de',
      'DE',
    );
    addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);

    late ProviderContainer container;
    await tester.pumpWidget(
      testApp(
        // UI pinned to English; the device locale set above only drives
        // presetForLocale, not the labels this test taps.
        locale: const Locale('en'),
        child: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return const UnitsStep(mode: SetupWizardMode.firstRun);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Fine-tune units'));
    await tester.pumpAndSettle();

    // Depth row: switch to feet only.
    await tester.ensureVisible(
      find.byKey(const ValueKey('setup-unit-depth-ft')),
    );
    await tester.tap(find.byKey(const ValueKey('setup-unit-depth-ft')));
    await tester.pumpAndSettle();

    final draft = container.read(setupWizardProvider(SetupWizardMode.firstRun));
    expect(draft.settings.depthUnit, DepthUnit.feet);
    expect(draft.settings.temperatureUnit, TemperatureUnit.celsius);
    expect(draft.settings.unitPreset, UnitPreset.custom);
  });

  testWidgets('US device locale preselects imperial once', (tester) async {
    tester.binding.platformDispatcher.localeTestValue = const Locale(
      'en',
      'US',
    );
    addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);

    late ProviderContainer container;
    await tester.pumpWidget(
      testApp(
        // UI pinned to English; the device locale set above only drives
        // presetForLocale, not the labels this test taps.
        locale: const Locale('en'),
        child: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return const UnitsStep(mode: SetupWizardMode.firstRun);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final draft = container.read(setupWizardProvider(SetupWizardMode.firstRun));
    expect(draft.settings.unitPreset, UnitPreset.imperial);
  });
}
