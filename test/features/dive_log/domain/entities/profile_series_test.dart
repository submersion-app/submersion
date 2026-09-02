import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_summary.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_series.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_series_identity.dart';
import 'package:uuid/uuid.dart';

void main() {
  group('profileSeriesMigratedId', () {
    test('is deterministic over the identity tuple', () {
      final a = profileSeriesMigratedId(
        diveId: 'd1',
        computerId: 'c1',
        sourceId: 's1',
        isPrimary: true,
      );
      final b = profileSeriesMigratedId(
        diveId: 'd1',
        computerId: 'c1',
        sourceId: 's1',
        isPrimary: true,
      );
      expect(a, b);
      expect(a, hasLength(36));
      expect(a[14], '5', reason: 'uuid v5 version nibble');
    });

    test('every tuple member changes the id', () {
      final base = profileSeriesMigratedId(
        diveId: 'd1',
        computerId: 'c1',
        sourceId: 's1',
        isPrimary: true,
      );
      expect(
        profileSeriesMigratedId(
          diveId: 'd2',
          computerId: 'c1',
          sourceId: 's1',
          isPrimary: true,
        ),
        isNot(base),
      );
      expect(
        profileSeriesMigratedId(
          diveId: 'd1',
          computerId: null,
          sourceId: 's1',
          isPrimary: true,
        ),
        isNot(base),
      );
      expect(
        profileSeriesMigratedId(
          diveId: 'd1',
          computerId: 'c1',
          sourceId: null,
          isPrimary: true,
        ),
        isNot(base),
      );
      expect(
        profileSeriesMigratedId(
          diveId: 'd1',
          computerId: 'c1',
          sourceId: 's1',
          isPrimary: false,
        ),
        isNot(base),
      );
    });

    test('absent members are spelled null in the key, per the spec', () {
      // Spec section 8: uuid v5 over `dive_id|computer_id|source_id|
      // is_primary` with the literal `null` for absent members. Pinning the
      // key format keeps every device deriving the same id.
      expect(
        profileSeriesMigratedId(
          diveId: 'd1',
          computerId: null,
          sourceId: null,
          isPrimary: true,
        ),
        const Uuid().v5(kProfileSeriesNamespace, 'd1|null|null|1'),
      );
    });
  });

  group('tankPressureSeriesMigratedId', () {
    test('is deterministic and distinct from the profile namespace', () {
      final a = tankPressureSeriesMigratedId(
        diveId: 'd1',
        tankId: 't1',
        computerId: null,
      );
      final b = tankPressureSeriesMigratedId(
        diveId: 'd1',
        tankId: 't1',
        computerId: null,
      );
      expect(a, b);
      expect(
        a,
        isNot(
          profileSeriesMigratedId(
            diveId: 'd1',
            computerId: null,
            sourceId: 't1',
            isPrimary: true,
          ),
        ),
      );
    });
  });

  group('ProfileSeries', () {
    const samples = [
      ProfileSample(timestamp: 0, depth: 0.0),
      ProfileSample(timestamp: 10, depth: 12.5, temperature: 20.0),
    ];
    final series = ProfileSeries(
      id: 'ps1',
      diveId: 'd1',
      computerId: 'c1',
      sourceId: 's1',
      isPrimary: true,
      summary: ProfileSeriesSummary.of(samples),
      samples: samples,
      codecVersion: 1,
      createdAt: 1000,
      updatedAt: 1000,
    );

    test('points converts every sample to a DiveProfilePoint', () {
      final points = series.points;
      expect(points, hasLength(2));
      expect(points[1].timestamp, 10);
      expect(points[1].depth, 12.5);
      expect(points[1].temperature, 20.0);
    });

    test('copyWith replaces only what is given', () {
      final demoted = series.copyWith(isPrimary: false, updatedAt: 2000);
      expect(demoted.isPrimary, isFalse);
      expect(demoted.updatedAt, 2000);
      expect(demoted.id, 'ps1');
      expect(demoted.samples, samples);
      expect(demoted, isNot(series));
    });

    test('copyWith can clear nullable members', () {
      final cleared = series.copyWith(
        clearComputerId: true,
        clearSourceId: true,
      );
      expect(cleared.computerId, isNull);
      expect(cleared.sourceId, isNull);
    });
  });

  group('TankPressureSeries', () {
    const samples = [
      TankPressureSample(timestamp: 0, pressure: 200.0),
      TankPressureSample(timestamp: 30, pressure: 195.5),
    ];
    final series = TankPressureSeries(
      id: 'tps1',
      diveId: 'd1',
      tankId: 't1',
      computerId: 'c1',
      summary: TankPressureSeriesSummary.of(samples),
      samples: samples,
      codecVersion: 1,
      createdAt: 1000,
      updatedAt: 1000,
      hlc: 'hlc-1',
    );

    test('copyWith replaces only what is given', () {
      final moved = series.copyWith(tankId: 't2', updatedAt: 2000);
      expect(moved.tankId, 't2');
      expect(moved.updatedAt, 2000);
      expect(moved.id, 'tps1');
      expect(moved.diveId, 'd1');
      expect(moved.computerId, 'c1');
      expect(moved.samples, samples);
      expect(moved.summary, series.summary);
      expect(moved.codecVersion, 1);
      expect(moved.createdAt, 1000);
      expect(moved.hlc, 'hlc-1');
      expect(moved, isNot(series));
    });

    test('copyWith can clear the nullable members', () {
      final cleared = series.copyWith(clearComputerId: true, clearHlc: true);
      expect(cleared.computerId, isNull);
      expect(cleared.hlc, isNull);
      expect(cleared.tankId, 't1');
    });

    test('value equality covers every field', () {
      final same = series.copyWith();
      expect(same, series);
      expect(series.copyWith(codecVersion: 2), isNot(series));
      expect(series.copyWith(createdAt: 5), isNot(series));
      expect(series.copyWith(diveId: 'd2'), isNot(series));
    });
  });

  group('ProfileSeries hlc', () {
    const samples = [ProfileSample(timestamp: 0, depth: 0.0)];
    final series = ProfileSeries(
      id: 'ps2',
      diveId: 'd1',
      isPrimary: true,
      summary: ProfileSeriesSummary.of(samples),
      samples: samples,
      codecVersion: 1,
      createdAt: 1,
      updatedAt: 1,
      hlc: 'hlc-2',
    );

    test('copyWith keeps, replaces, and clears the clock', () {
      expect(series.copyWith().hlc, 'hlc-2');
      expect(series.copyWith(hlc: 'hlc-3').hlc, 'hlc-3');
      expect(series.copyWith(clearHlc: true).hlc, isNull);
    });
  });
}
