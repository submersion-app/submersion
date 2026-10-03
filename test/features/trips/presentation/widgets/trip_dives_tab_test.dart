import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_dives_tab.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  testWidgets('dives list in entry-time order, as the story numbers them', (
    tester,
  ) async {
    // The morning dive was logged late in the day with its real entry time;
    // ordering by the log time would put it after the afternoon dive.
    final morning = Dive(
      id: 'm',
      diveNumber: 7,
      dateTime: DateTime(2026, 3, 8, 18),
      entryTime: DateTime(2026, 3, 8, 9),
    );
    final afternoon = Dive(
      id: 'a',
      diveNumber: 8,
      dateTime: DateTime(2026, 3, 8, 14),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          divesForTripProvider(
            't1',
          ).overrideWith((ref) async => [afternoon, morning]),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: TripDivesTab(tripId: 't1')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final morningTop = tester.getTopLeft(find.text('#7')).dy;
    final afternoonTop = tester.getTopLeft(find.text('#8')).dy;
    expect(morningTop, lessThan(afternoonTop));
  });
}
