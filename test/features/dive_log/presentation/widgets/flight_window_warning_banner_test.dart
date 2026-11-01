import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/flight_window_warning_banner.dart';
import 'package:submersion/features/safety/domain/services/no_fly_service.dart';
import 'package:submersion/features/safety/presentation/providers/flight_window_providers.dart';
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

  final openStatus = FlightWindowStatus(
    state: FlightWindowState.open,
    flightAt: DateTime(2126, 8, 10, 9).toUtc(),
    deadline: DateTime(2126, 8, 9, 15).toUtc(),
    category: NoFlyCategory.repetitive,
    interval: const Duration(hours: 18),
  );

  Future<void> pump(
    WidgetTester tester, {
    required String? tripId,
    required DateTime? diveEndTime,
    TimeFormat timeFormat = TimeFormat.twelveHour,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            (ref) => MockSettingsNotifier(AppSettings(timeFormat: timeFormat)),
          ),
          tripFlightWindowProvider(
            't1',
          ).overrideWith((ref) async => openStatus),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: FlightWindowWarningBanner(
              tripId: tripId,
              diveEndTime: diveEndTime,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('warns when the dive ends after the deadline', (tester) async {
    await pump(tester, tripId: 't1', diveEndTime: DateTime.utc(2126, 8, 9, 16));
    expect(
      find.textContaining('after the latest safe surfacing time'),
      findsOneWidget,
    );
  });

  testWidgets('silent when the dive ends before the deadline', (tester) async {
    await pump(tester, tripId: 't1', diveEndTime: DateTime.utc(2126, 8, 9, 12));
    expect(
      find.textContaining('after the latest safe surfacing time'),
      findsNothing,
    );
  });

  testWidgets('shows the deadline on the device clock', (tester) async {
    await pump(tester, tripId: 't1', diveEndTime: DateTime.utc(2126, 8, 9, 16));
    expect(find.textContaining('3:00 PM'), findsOneWidget);
  });

  testWidgets('shows the deadline in the diver\'s time format', (tester) async {
    await pump(
      tester,
      tripId: 't1',
      diveEndTime: DateTime.utc(2126, 8, 9, 16),
      timeFormat: TimeFormat.twentyFourHour,
    );
    expect(find.textContaining('15:00'), findsOneWidget);
  });

  testWidgets('silent without a trip', (tester) async {
    await pump(tester, tripId: null, diveEndTime: DateTime.utc(2126, 8, 9, 16));
    expect(
      find.textContaining('after the latest safe surfacing time'),
      findsNothing,
    );
  });
}
