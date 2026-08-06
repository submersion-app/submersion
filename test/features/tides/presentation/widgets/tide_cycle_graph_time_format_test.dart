import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/tide/entities/tide_extremes.dart';
import 'package:submersion/features/tides/domain/entities/tide_record.dart';
import 'package:submersion/features/tides/presentation/widgets/tide_cycle_graph.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

// Tide instants are stored wall-clock-as-UTC. The cycle graph paints its
// start/end timestamps through a private CustomPainter, so the digits land on
// the canvas rather than in a Text widget; the assertion this test can make is
// that the painter runs end-to-end over wall-clock-UTC instants without a
// device-local conversion crashing or being skipped. The same instants are
// asserted digit-for-digit through the dive-detail tide card. (#222)
final _record = TideRecord(
  id: 'tide-1',
  diveId: 'dive-1',
  heightMeters: 1.6,
  tideState: TideState.rising,
  rateOfChange: 0.4,
  highTideHeight: 2.4,
  highTideTime: DateTime.utc(2026, 3, 28, 14, 20),
  lowTideHeight: 0.4,
  lowTideTime: DateTime.utc(2026, 3, 28, 8, 20),
  createdAt: DateTime.utc(2026, 3, 28, 12),
);

void main() {
  String? previousDefaultLocale;

  setUp(() {
    previousDefaultLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
  });

  tearDown(() {
    Intl.defaultLocale = previousDefaultLocale;
  });

  testWidgets('TideCycleGraph paints wall-clock cycle bounds (#222)', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              child: TideCycleGraph(
                record: _record,
                referenceTime: DateTime.utc(2026, 3, 28, 10),
                height: 80,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CustomPaint), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
