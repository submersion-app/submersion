import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/flight_window_warning_banner.dart';
import 'package:submersion/features/safety/domain/services/no_fly_service.dart';
import 'package:submersion/features/safety/presentation/providers/flight_window_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  final openStatus = FlightWindowStatus(
    state: FlightWindowState.open,
    flightAt: DateTime.utc(2126, 8, 10, 9),
    deadline: DateTime.utc(2126, 8, 9, 15),
    category: NoFlyCategory.repetitive,
    interval: const Duration(hours: 18),
  );

  Future<void> pump(
    WidgetTester tester, {
    required String? tripId,
    required DateTime? diveEndTime,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
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

  testWidgets('silent without a trip', (tester) async {
    await pump(tester, tripId: null, diveEndTime: DateTime.utc(2126, 8, 9, 16));
    expect(
      find.textContaining('after the latest safe surfacing time'),
      findsNothing,
    );
  });
}
