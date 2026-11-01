import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/safety/domain/services/no_fly_service.dart';
import 'package:submersion/features/safety/presentation/pages/no_fly_page.dart';
import 'package:submersion/features/safety/presentation/providers/flight_window_providers.dart';
import 'package:submersion/features/safety/presentation/providers/no_fly_providers.dart';
import 'package:submersion/features/safety/presentation/widgets/flight_window_card.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Stands in for the trip window the active-trip provider follows through
/// `.future`, so invalidating it reloads that provider as a dive write does.
final _tripWindowSource = FutureProvider<int>((ref) async => 0);

void main() {
  testWidgets('keeps the flight card through a reload', (tester) async {
    final status = FlightWindowStatus(
      state: FlightWindowState.open,
      flightAt: DateTime.utc(2126, 8, 10, 9),
      deadline: DateTime.utc(2126, 8, 9, 15),
      category: NoFlyCategory.repetitive,
      interval: const Duration(hours: 18),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          noFlyStatusProvider.overrideWith((ref) async => null),
          activeTripFlightWindowProvider.overrideWith((ref) async {
            await ref.watch(_tripWindowSource.future);
            return status;
          }),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NoFlyPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byType(FlightWindowCard), findsOneWidget);

    ProviderScope.containerOf(
      tester.element(find.byType(NoFlyPage)),
    ).invalidate(_tripWindowSource);

    for (var frame = 0; frame < 3; frame++) {
      await tester.pump();
      expect(find.byType(FlightWindowCard), findsOneWidget);
    }
  });
}
