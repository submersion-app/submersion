import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../../helpers/test_database.dart';

/// Covers the profile-span SQL directly: the legacy span was
/// `MAX(timestamp) - MIN(timestamp)` over every `dive_profiles` row of the
/// dive, with no `is_primary` filter, so the series replacement must span
/// every series of the dive too.
void main() {
  late DiveRepository repository;
  late ProfileSeriesRepository series;

  setUp(() async {
    await setUpTestDatabase();
    repository = DiveRepository();
    series = ProfileSeriesRepository();
  });
  tearDown(() async => tearDownTestDatabase());

  test('effective runtime spans every series of the dive, primary and demoted '
      'alike', () async {
    await repository.createDive(
      domain.Dive(
        id: 'multi-series',
        dateTime: DateTime.utc(2026, 8, 1, 10),
        bottomTime: const Duration(minutes: 40),
      ),
    );
    await series.insertSeries(
      diveId: 'multi-series',
      isPrimary: true,
      samples: [
        for (var t = 0; t <= 600; t += 60)
          ProfileSample(timestamp: t, depth: t == 0 || t == 600 ? 0 : 18),
      ],
    );
    await series.insertSeries(
      diveId: 'multi-series',
      isPrimary: false,
      samples: [
        for (var t = 0; t <= 900; t += 60)
          ProfileSample(timestamp: t, depth: t == 0 || t == 900 ? 0 : 18),
      ],
    );

    final times = await repository.getDiveTimes('multi-series');
    expect(times, isNotNull);
    // No runtime, no exit/entry pair, so the resolution falls to the
    // profile span; the span is over ALL series, not just the primary
    // one, so the 900 s demoted series wins over the 600 s primary one.
    expect(times!.effectiveRuntime, const Duration(seconds: 900));
  });

  test('a single-sample series has a zero span and falls through to bottom '
      'time', () async {
    await repository.createDive(
      domain.Dive(
        id: 'zero-span',
        dateTime: DateTime.utc(2026, 8, 2, 10),
        bottomTime: const Duration(minutes: 40),
      ),
    );
    await series.insertSeries(
      diveId: 'zero-span',
      isPrimary: true,
      samples: const [ProfileSample(timestamp: 300, depth: 18)],
    );

    final times = await repository.getDiveTimes('zero-span');
    expect(times, isNotNull);
    // A zero-span profile (single sample) must NULLIF to null and fall
    // through to bottom_time, matching calculateRuntimeFromProfile().
    expect(times!.effectiveRuntime, const Duration(seconds: 2400));
  });
}
