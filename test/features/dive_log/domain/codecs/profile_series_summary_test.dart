import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_summary.dart';

void main() {
  test('summarises a plain no-deco series', () {
    const samples = [
      ProfileSample(timestamp: 0, depth: 0.0),
      ProfileSample(timestamp: 10, depth: 5.2),
      ProfileSample(timestamp: 20, depth: 18.7),
      ProfileSample(timestamp: 30, depth: 12.1),
      ProfileSample(timestamp: 40, depth: 0.3),
    ];
    final summary = ProfileSeriesSummary.of(samples);
    expect(
      summary,
      const ProfileSeriesSummary(
        sampleCount: 5,
        startTimestamp: 0,
        endTimestamp: 40,
        maxDepth: 18.7,
        firstDepth: 0.0,
        lastDepth: 0.3,
        hasDecoType: false,
        hasDecoStop: false,
        hasPositiveCeiling: false,
      ),
    );
  });

  test('a recorded deco type without a stop sets only hasDecoType', () {
    const samples = [
      ProfileSample(timestamp: 0, depth: 0.0, decoType: 0),
      ProfileSample(timestamp: 10, depth: 20.0, decoType: 1),
    ];
    final summary = ProfileSeriesSummary.of(samples);
    expect(summary.hasDecoType, isTrue);
    expect(summary.hasDecoStop, isFalse);
  });

  test('deco type 2 on any sample sets hasDecoStop', () {
    const samples = [
      ProfileSample(timestamp: 0, depth: 0.0, decoType: 0),
      ProfileSample(timestamp: 10, depth: 6.0, decoType: kDecoTypeDecoStop),
    ];
    expect(ProfileSeriesSummary.of(samples).hasDecoStop, isTrue);
  });

  test('a positive ceiling on any sample sets hasPositiveCeiling', () {
    const samples = [
      ProfileSample(timestamp: 0, depth: 0.0, ceiling: 0.0),
      ProfileSample(timestamp: 10, depth: 30.0, ceiling: 3.0),
    ];
    expect(ProfileSeriesSummary.of(samples).hasPositiveCeiling, isTrue);
  });

  test('a zero or null ceiling does not count as positive', () {
    const samples = [
      ProfileSample(timestamp: 0, depth: 0.0, ceiling: 0.0),
      ProfileSample(timestamp: 10, depth: 30.0),
    ];
    expect(ProfileSeriesSummary.of(samples).hasPositiveCeiling, isFalse);
  });

  test('a single sample is its own start, end, first, last and max', () {
    const samples = [ProfileSample(timestamp: 7, depth: 4.4)];
    final summary = ProfileSeriesSummary.of(samples);
    expect(summary.sampleCount, 1);
    expect(summary.startTimestamp, 7);
    expect(summary.endTimestamp, 7);
    expect(summary.maxDepth, 4.4);
    expect(summary.firstDepth, 4.4);
    expect(summary.lastDepth, 4.4);
  });

  test('an empty series is a caller error', () {
    expect(() => ProfileSeriesSummary.of(const []), throwsArgumentError);
  });
}
