import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/tide/tide.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/tides/presentation/providers/tide_providers.dart';

const _bonaire = GeoPoint(12.15, -68.27); // UTC-4, no DST

void main() {
  test('site-clock providers map the instant providers for display', () async {
    final container = ProviderContainer(
      overrides: [
        tideExtremesProvider(_bonaire).overrideWith(
          (ref) async => [
            TideExtreme(
              type: TideExtremeType.high,
              time: DateTime.utc(2026, 3, 28, 18, 20),
              heightMeters: 0.4,
            ),
          ],
        ),
        tidePredictionsProvider(_bonaire).overrideWith(
          (ref) async => [
            TidePrediction(
              time: DateTime.utc(2026, 3, 28, 12),
              heightMeters: 0.2,
            ),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);

    final extremes = await container.read(
      tideExtremesAtSiteProvider(_bonaire).future,
    );
    final predictions = await container.read(
      tidePredictionsAtSiteProvider(_bonaire).future,
    );

    expect(extremes.single.time, DateTime.utc(2026, 3, 28, 14, 20));
    expect(predictions.single.time, DateTime.utc(2026, 3, 28, 8));
  });
}
