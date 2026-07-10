import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/features/setup_wizard/domain/setup_wizard_models.dart';
import 'package:submersion/features/setup_wizard/presentation/providers/setup_wizard_providers.dart';
import 'package:submersion/features/setup_wizard/presentation/widgets/steps/appearance_step.dart';

import '../../../../../helpers/test_app.dart';

void main() {
  testWidgets('theme, map style, and language update draft and preview', (
    tester,
  ) async {
    late ProviderContainer container;
    await tester.pumpWidget(
      testApp(
        child: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return const AppearanceStep(mode: SetupWizardMode.firstRun);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Satellite'));
    await tester.tap(find.text('Satellite'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('setup-language')));
    await tester.tap(find.byKey(const ValueKey('setup-language')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deutsch').last);
    await tester.pumpAndSettle();

    final draft = container.read(setupWizardProvider(SetupWizardMode.firstRun));
    expect(draft.settings.themeMode, ThemeMode.dark);
    expect(draft.settings.mapStyle, MapStyle.esriSatellite);
    expect(draft.settings.locale, 'de');
    expect(container.read(previewLocaleProvider), 'de');
  });
}
