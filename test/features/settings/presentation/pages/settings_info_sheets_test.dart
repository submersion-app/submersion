import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/pages/decompression_settings_page.dart';
import 'package:submersion/features/settings/presentation/pages/equipment_condition_settings_page.dart';
import 'package:submersion/features/settings/presentation/pages/planner_defaults_settings_page.dart';
import 'package:submersion/features/settings/presentation/pages/safety_review_settings_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/info_sheets.dart';
import '../../../../helpers/mock_providers.dart';

/// Every settings section's info icon opens a sheet that builds.
void main() {
  final pages = <String, (Widget, int)>{
    'Decompression': (const DecompressionSettingsPage(), 7),
    'Planner defaults': (const PlannerDefaultsSettingsPage(), 4),
    'Equipment condition': (const EquipmentConditionSettingsPage(), 3),
    'Safety review': (const SafetyReviewSettingsPage(), 2),
  };

  for (final MapEntry(key: name, value: (page, icons)) in pages.entries) {
    testWidgets('every info icon on $name settings opens its sheet', (
      tester,
    ) async {
      // Tall enough that every section builds at once.
      tester.view.physicalSize = const Size(900, 8000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: page,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(await openEveryInfoSheet(tester), icons);
    });
  }
}
