import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/safety/domain/services/no_fly_service.dart';
import 'package:submersion/features/safety/presentation/providers/flight_window_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_flight_countdown_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required FlightWindowStatus? status,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tripFlightWindowProvider('t1').overrideWith((ref) async => status),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: TripFlightCountdownCard(tripId: 't1')),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the flight window card when a status exists', (
    tester,
  ) async {
    await pump(
      tester,
      status: FlightWindowStatus(
        state: FlightWindowState.open,
        flightAt: DateTime.utc(2126, 8, 10, 9),
        deadline: DateTime.utc(2126, 8, 9, 15),
        category: NoFlyCategory.repetitive,
        interval: const Duration(hours: 18),
      ),
    );
    expect(find.textContaining('Time left to dive'), findsOneWidget);
  });

  testWidgets('renders nothing when the provider yields null', (tester) async {
    await pump(tester, status: null);
    expect(find.byType(Card), findsNothing);
  });
}
