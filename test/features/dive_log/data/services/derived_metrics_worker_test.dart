import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/data/services/derived_metrics_worker.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';
import 'package:submersion/features/dive_log/domain/entities/derived_metrics.dart';

void main() {
  const profileCodec = ProfileSeriesCodec();
  const tankCodec = TankPressureSeriesCodec();

  Uint8List encodeProfile(List<ProfileSample> samples) =>
      profileCodec.encode(samples).bytes;

  List<ProfileSample> square() => [
    for (var t = 0; t <= 1200; t += 10)
      ProfileSample(timestamp: t, depth: t < 1080 ? 20 : 5),
  ];

  DerivedMetricsWorkInput input({
    required List<Uint8List> primaryBlobs,
    List<TankPressureBlob> tankBlobs = const [],
    DiveMode mode = DiveMode.oc,
  }) => DerivedMetricsWorkInput(
    diveId: 'd1',
    primaryBlobs: primaryBlobs,
    tankBlobs: tankBlobs,
    diveMode: mode,
    sourceUpdatedAt: 7,
    computedAtMs: 9,
  );

  test('decodes the primary blobs and derives metrics', () {
    final out = computeDerivedMetricsFromBlobs(
      input(primaryBlobs: [encodeProfile(square())]),
    );
    expect(out.diveId, 'd1');
    expect(out.sourceUpdatedAt, 7);
    expect(out.computedAt, 9);
    expect(out.runtimeSeconds, 1200);
    // No tank blobs, so SAC is unavailable but the stop still lands.
    expect(out.unsupportedReason, UnsupportedReason.noPressureSeries);
    expect(out.finalStopKind, FinalStopKind.safety);
  });

  test('merges several source blobs in timestamp order', () {
    final first = square().where((s) => s.timestamp <= 600).toList();
    final second = square().where((s) => s.timestamp > 600).toList();
    final out = computeDerivedMetricsFromBlobs(
      // Deliberately out of order: the worker sorts.
      input(primaryBlobs: [encodeProfile(second), encodeProfile(first)]),
    );
    expect(out.runtimeSeconds, 1200);
  });

  test('a corrupt blob is skipped, and a row is still produced', () {
    final out = computeDerivedMetricsFromBlobs(
      input(
        primaryBlobs: [
          encodeProfile(square()),
          Uint8List.fromList([0, 1, 2, 3, 4]),
        ],
      ),
    );
    expect(out.runtimeSeconds, 1200);
  });

  test('no decodable profile at all is reported as noProfile', () {
    final out = computeDerivedMetricsFromBlobs(
      input(
        primaryBlobs: [
          Uint8List.fromList([9, 9, 9]),
        ],
      ),
    );
    expect(out.unsupportedReason, UnsupportedReason.noProfile);
  });

  test('a tank blob feeds the SAC engine', () {
    final pressures = [
      for (var t = 0; t <= 1200; t += 10)
        TankPressureSample(timestamp: t, pressure: 200 - 2 * (t / 60)),
    ];
    final out = computeDerivedMetricsFromBlobs(
      input(
        primaryBlobs: [encodeProfile(square())],
        tankBlobs: [
          TankPressureBlob(
            tankId: 't1',
            volumeLiters: 12,
            samples: tankCodec.encode(pressures).bytes,
          ),
        ],
      ),
    );
    expect(out.hasSac, isTrue);
    expect(out.unsupportedReason, isNull);
    expect(out.sacBuckets, isNotEmpty);
  });

  test('a corrupt tank blob is skipped, leaving SAC unavailable', () {
    final out = computeDerivedMetricsFromBlobs(
      input(
        primaryBlobs: [encodeProfile(square())],
        tankBlobs: [
          TankPressureBlob(
            tankId: 't1',
            volumeLiters: 12,
            samples: Uint8List.fromList([4, 4, 4]),
          ),
        ],
      ),
    );
    expect(out.unsupportedReason, UnsupportedReason.noPressureSeries);
    expect(out.finalStopKind, FinalStopKind.safety);
  });
}
