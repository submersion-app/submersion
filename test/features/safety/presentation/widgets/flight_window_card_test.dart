import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/safety/domain/services/no_fly_service.dart';
import 'package:submersion/features/safety/presentation/widgets/flight_window_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  Future<void> pumpCard(WidgetTester tester, FlightWindowStatus status) {
    return tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: FlightWindowCard(status: status)),
      ),
    );
  }

  // Far-future fixture dates keep the open state's remaining(now) positive
  // without a fake clock.
  FlightWindowStatus status(FlightWindowState state) => FlightWindowStatus(
    state: state,
    flightAt: DateTime.utc(2126, 8, 10, 9),
    deadline: DateTime.utc(2126, 8, 9, 15),
    category: NoFlyCategory.repetitive,
    interval: const Duration(hours: 18),
  );

  testWidgets('open state shows countdown and surface-by time', (tester) async {
    await pumpCard(tester, status(FlightWindowState.open));
    expect(find.textContaining('Time left to dive'), findsOneWidget);
    expect(find.textContaining('Surface by'), findsOneWidget);
  });

  testWidgets('closed state shows the stop-diving message', (tester) async {
    await pumpCard(tester, status(FlightWindowState.closed));
    expect(find.text('No more diving before your flight'), findsOneWidget);
    expect(find.textContaining('Flight departs'), findsOneWidget);
  });

  testWidgets('conflict state shows the alert message', (tester) async {
    await pumpCard(tester, status(FlightWindowState.conflict));
    expect(
      find.text('Your no-fly time extends past your flight departure'),
      findsOneWidget,
    );
  });
}
