import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/o2_cell_unit.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/chart_options_dialog.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_legend_config.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

Widget _dialog(ProfileLegendConfig config) => ProviderScope(
  overrides: [settingsProvider.overrideWith((ref) => MockSettingsNotifier())],
  child: MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: ChartOptionsDialog(
        config: config,
        anchorOffset: Offset.zero,
        anchorSize: const Size(40, 40),
      ),
    ),
  ),
);

void main() {
  group('O2 cell unit switch', () {
    testWidgets('picking a unit persists it as the default, not just for '
        'this dive', (tester) async {
      await tester.pumpWidget(
        _dialog(
          const ProfileLegendConfig(
            hasO2CellData: true,
            hasBothO2CellUnits: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Gas Analysis is collapsed by default.
      await tester.tap(find.text('Gas Analysis'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ChartOptionsDialog)),
      );
      expect(container.read(settingsProvider).o2CellUnit, O2CellUnit.ppO2);

      await tester.tap(find.text('mV'));
      await tester.pumpAndSettle();

      // Both the session state and the stored default move: the unit is a
      // viewing preference, so the next dive opens the way this one was left.
      expect(
        container.read(profileLegendProvider).o2CellUnit,
        O2CellUnit.millivolts,
      );
      expect(
        container.read(settingsProvider).o2CellUnit,
        O2CellUnit.millivolts,
      );
    });

    testWidgets('a dive with one unit offers no switch', (tester) async {
      await tester.pumpWidget(
        _dialog(const ProfileLegendConfig(hasO2CellData: true)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gas Analysis'));
      await tester.pumpAndSettle();

      expect(find.text('O2 cells'), findsOneWidget);
      expect(find.text('mV'), findsNothing);
    });
  });
}
