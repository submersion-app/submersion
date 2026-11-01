import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:submersion/features/safety/domain/services/no_fly_service.dart';
import 'package:submersion/features/safety/presentation/widgets/flight_window_card.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  // The times shown go through DateFormat, which reads Intl.defaultLocale: a
  // process global that a test sharing this isolate may leave set.
  late String? previousLocale;

  setUpAll(() => initializeDateFormatting('en'));

  setUp(() {
    previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en';
  });

  tearDown(() => Intl.defaultLocale = previousLocale);

  Future<void> pumpCard(WidgetTester tester, FlightWindowStatus status) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: FlightWindowCard(status: status)),
        ),
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

  testWidgets('counts down to a true instant', (tester) async {
    await pumpCard(
      tester,
      FlightWindowStatus(
        state: FlightWindowState.open,
        flightAt: DateTime.now().toUtc().add(const Duration(hours: 23)),
        deadline: DateTime.now().toUtc().add(
          const Duration(hours: 5, minutes: 30),
        ),
        category: NoFlyCategory.repetitive,
        interval: const Duration(hours: 18),
      ),
    );
    expect(find.textContaining('Time left to dive: 5h'), findsOneWidget);
  });

  testWidgets('shows the times on the device clock', (tester) async {
    final deadline = DateTime(2126, 8, 9, 15).toUtc();
    await pumpCard(
      tester,
      FlightWindowStatus(
        state: FlightWindowState.open,
        flightAt: deadline.add(const Duration(hours: 18)),
        deadline: deadline,
        category: NoFlyCategory.repetitive,
        interval: const Duration(hours: 18),
      ),
    );
    expect(find.textContaining('3:00 PM'), findsOneWidget);
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
