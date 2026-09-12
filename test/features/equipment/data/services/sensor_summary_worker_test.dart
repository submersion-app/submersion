import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_field_table.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec_exception.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';
import 'package:submersion/features/equipment/data/services/sensor_summary_worker.dart';

void main() {
  const profileCodec = ProfileSeriesCodec();
  const tankCodec = TankPressureSeriesCodec();

  Uint8List profile(List<ProfileSample> samples) =>
      profileCodec.encode(samples).bytes;
  Uint8List pressures(List<TankPressureSample> samples) =>
      tankCodec.encode(samples).bytes;

  SensorSummaryWorkInput input({
    List<Uint8List> primary = const [],
    List<TankSeriesBlob> tanks = const [],
  }) => SensorSummaryWorkInput(
    diveId: 'd1',
    primaryBlobs: primary,
    tankBlobs: tanks,
    diveMode: DiveMode.ccr,
    runtimeSeconds: 3000,
    scrubberDurationMinutes: null,
    scrubberRemainingMinutes: null,
    sourceUpdatedAt: 42,
    computedAtMs: DateTime.utc(2026, 9, 9).millisecondsSinceEpoch,
  );

  test('decodes the profile and tank blobs and summarises them', () {
    final summary = computeSensorSummaryFromBlobs(
      input(
        primary: [
          profile(const [
            ProfileSample(timestamp: 0, depth: 0, temperature: 12),
            ProfileSample(timestamp: 60, depth: 25.5, temperature: 6),
            ProfileSample(timestamp: 120, depth: 3, temperature: 10),
          ]),
        ],
        tanks: [
          TankSeriesBlob(
            tankId: 't1',
            transmitterSerial: '180777',
            computerId: 'c1',
            samples: pressures(const [
              TankPressureSample(timestamp: 0, pressure: 200),
              TankPressureSample(timestamp: 10, pressure: 199),
              TankPressureSample(timestamp: 20, pressure: 198),
              TankPressureSample(timestamp: 120, pressure: 190),
            ]),
          ),
        ],
      ),
    );
    expect(summary.diveId, 'd1');
    expect(summary.sourceUpdatedAt, 42);
    expect(summary.computedAt, DateTime.utc(2026, 9, 9));
    expect(summary.maxDepth, 25.5);
    expect(summary.minTemperature, 6);
    expect(summary.scrubberConsumedMinutes, 50);
    expect(summary.transmitterGaps.single.tankId, 't1');
    expect(summary.transmitterGaps.single.gapCount, 1);
    expect(summary.transmitterGaps.single.gapSeconds, 100);
  });

  test('several primary blobs are merged by timestamp', () {
    final summary = computeSensorSummaryFromBlobs(
      input(
        primary: [
          profile(const [
            ProfileSample(timestamp: 100, depth: 30, temperature: 5),
            ProfileSample(timestamp: 200, depth: 10),
          ]),
          profile(const [
            ProfileSample(timestamp: 0, depth: 0, temperature: 20),
            ProfileSample(timestamp: 50, depth: 15),
          ]),
        ],
      ),
    );
    expect(summary.maxDepth, 30);
    expect(summary.minTemperature, 5);
  });

  test('an unreadable blob is skipped, not fatal', () {
    final summary = computeSensorSummaryFromBlobs(
      input(
        primary: [
          Uint8List.fromList([1, 2, 3]),
          profile(const [ProfileSample(timestamp: 0, depth: 7)]),
        ],
        tanks: [
          TankSeriesBlob(tankId: 't1', samples: Uint8List.fromList([9, 9])),
        ],
      ),
    );
    expect(summary.maxDepth, 7);
    expect(summary.transmitterGaps, isEmpty);
  });

  test('no blobs at all still yields a row', () {
    final summary = computeSensorSummaryFromBlobs(input());
    expect(summary.maxDepth, isNull);
    expect(summary.cellMetrics, isEmpty);
    expect(summary.scrubberConsumedMinutes, 50);
  });

  group('forward codec versions', () {
    /// A blob written by a hypothetical v2 codec: this build has no field
    /// table for it, but the samples are fine and a newer build reads them.
    Uint8List futureProfile() =>
        const ProfileSeriesCodec(fieldTables: {2: kProfileFieldTableV1}).encode(
          const [
            ProfileSample(timestamp: 0, depth: 1.0),
            ProfileSample(timestamp: 60, depth: 9.0),
          ],
          version: 2,
        ).bytes;

    test('a forward-version profile blob is refused, not summarised', () {
      // Swallowing it would persist an empty summary as current for this
      // dive's updated_at, and upgrading back to a build that CAN read the
      // blob would never recompute it: the dive would look done forever.
      expect(
        () => computeSensorSummaryFromBlobs(input(primary: [futureProfile()])),
        throwsA(isA<UnknownSeriesVersionException>()),
      );
    });

    test('a corrupt blob is still skipped', () {
      final summary = computeSensorSummaryFromBlobs(
        input(
          primary: [
            profile(const [
              ProfileSample(timestamp: 0, depth: 1.0),
              ProfileSample(timestamp: 60, depth: 9.0),
            ]),
            Uint8List.fromList([1, 2, 3]),
          ],
        ),
      );
      expect(summary.maxDepth, 9.0);
    });
  });
}
