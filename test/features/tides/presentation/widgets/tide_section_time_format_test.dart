import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/tide/entities/tide_extremes.dart';
import 'package:submersion/core/tide/entities/tide_prediction.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/tides/presentation/providers/tide_providers.dart';
import 'package:submersion/features/tides/presentation/widgets/tide_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

const _location = GeoPoint(36.95, -122.02);

// The chart-window label replicates TideChart's window maths against the real
// clock: the newest extreme before now becomes the window start (minus 30min)
// and the second extreme after now becomes the window end (plus 30min). Anchor
// those two bounds on far-past and far-future wall-clock-as-UTC fixtures so the
// rendered digits are fully determined by the fixtures and never by the host's
// UTC offset. (#222)
final _extremes = [
  TideExtreme(
    type: TideExtremeType.low,
    time: DateTime.utc(2020, 3, 10, 6, 15),
    heightMeters: 0.4,
  ),
  TideExtreme(
    type: TideExtremeType.high,
    time: DateTime.utc(2030, 5, 20, 8),
    heightMeters: 2.4,
  ),
  TideExtreme(
    type: TideExtremeType.low,
    time: DateTime.utc(2030, 5, 20, 14, 30),
    heightMeters: 0.6,
  ),
];

void main() {
  String? previousDefaultLocale;

  setUp(() {
    previousDefaultLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
  });

  tearDown(() {
    Intl.defaultLocale = previousDefaultLocale;
  });

  testWidgets('TideSection labels its chart window in wall-clock time (#222)', (
    tester,
  ) async {
    final settings = MockSettingsNotifier();
    await settings.setTimeFormat(TimeFormat.twentyFourHour);
    final overrides = await getBaseOverrides(settingsNotifier: settings);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          hasTideDataProvider(_location).overrideWith((ref) async => true),
          currentTideStatusProvider(
            _location,
          ).overrideWith((ref) async => null),
          tidePredictionsProvider(
            _location,
          ).overrideWith((ref) async => <TidePrediction>[]),
          tideExtremesProvider(
            _location,
          ).overrideWith((ref) async => _extremes),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: TideSection(location: _location),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 06:15 - 30min = 05:45 on Tue Mar 10; 14:30 + 30min = 15:00 on May 20.
    expect(find.text('Tue, Mar 10 | 05:45 - 15:00 (May 20)'), findsOneWidget);
  });
}
