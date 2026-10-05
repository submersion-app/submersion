import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/settings_summary_widget.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  testWidgets('the summary lists the altitude and distance units', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            (ref) => MockSettingsNotifier(
              const AppSettings(
                altitudeUnit: AltitudeUnit.feet,
                distanceUnit: DistanceUnit.miles,
              ),
            ),
          ),
          currentDiverProvider.overrideWith((ref) async => null),
        ],
        child: const MaterialApp(
          // Pinned: the finders match English strings.
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SettingsSummaryWidget()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Altitude'), findsOneWidget);
    expect(find.text('Distance'), findsOneWidget);
    expect(find.text('mi'), findsOneWidget);
  });
}
