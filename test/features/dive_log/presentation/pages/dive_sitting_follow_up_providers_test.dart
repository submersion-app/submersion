import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/tide/tide.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_sitting_follow_up.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/tides/data/repositories/tide_record_repository.dart';
import 'package:submersion/features/tides/data/services/dive_tide_recorder.dart';
import 'package:submersion/features/tides/data/services/tide_constituent_resolver.dart';
import 'package:submersion/features/tides/domain/entities/tide_record.dart';
import 'package:submersion/features/tides/presentation/providers/tide_providers.dart';
import 'package:submersion/features/weather/data/services/elevation_service.dart';
import 'package:submersion/features/weather/presentation/providers/weather_providers.dart';

/// The real bodies of what a saved sitting runs after its commit (issue
/// #4527): the follow-up's own tests stand in for both.
class _Elevation extends ElevationService {
  _Elevation(this.meters);

  final double? meters;

  @override
  Future<double?> fetchElevation({
    required double latitude,
    required double longitude,
  }) async => meters;
}

class _Sites extends SiteRepository {
  final filled = <(String, double)>[];

  @override
  Future<bool> fillSiteAltitudeIfEmpty(String siteId, double meters) async {
    filled.add((siteId, meters));
    return true;
  }
}

class _Tides extends TideRecordRepository {
  final recorded = <String>[];
  final statuses = <TideStatus>[];
  final deleted = <String>[];

  @override
  Future<TideRecord> createFromStatus({
    required String diveId,
    required TideStatus status,
    String? id,
  }) async {
    recorded.add(diveId);
    statuses.add(status);
    return TideRecord.fromStatus(id: 'r1', diveId: diveId, status: status);
  }

  @override
  Future<void> deleteTideRecordForDive(String diveId) async =>
      deleted.add(diveId);
}

void main() {
  const point = GeoPoint(12.15, -68.27);

  group('the site altitude lookup', () {
    Future<_Sites> fill(double? meters) async {
      final sites = _Sites();
      final container = ProviderContainer(
        overrides: [
          elevationServiceProvider.overrideWithValue(_Elevation(meters)),
          siteRepositoryProvider.overrideWithValue(sites),
        ],
      );
      addTearDown(container.dispose);
      await container.read(diveSiteAltitudeFillProvider)('s1', point);
      return sites;
    }

    test('stores the altitude it finds for the site', () async {
      expect((await fill(434)).filled, [('s1', 434.0)]);
    });

    test('stores nothing when the lookup finds none', () async {
      expect((await fill(null)).filled, isEmpty);
    });
  });

  group('the tide record', () {
    final calculator = TideCalculator(
      constituents: {
        'M2': const TideConstituent(name: 'M2', amplitude: 1.0, phase: 0.0),
      },
    );
    const reef = DiveSite(id: 'reef', name: 'Reef', location: point);
    final atReef = Dive(
      id: 'd1',
      dateTime: DateTime.utc(2026, 3, 28, 10),
      site: reef,
    );

    Future<_Tides> record(Dive dive, {bool modelAnswers = true}) async {
      final tides = _Tides();
      final container = ProviderContainer(
        overrides: [
          tideRecordRepositoryProvider.overrideWithValue(tides),
          resolvedTideDataProvider(point).overrideWith(
            (ref) async => modelAnswers
                ? ResolvedTideData(
                    calculator: calculator,
                    source: const TideDataSource.fesModel(),
                  )
                : null,
          ),
          tideRecordForDiveProvider(dive.id).overrideWith((ref) async => null),
        ],
      );
      addTearDown(container.dispose);
      await container.read(diveTideRecordProvider)(dive);
      return tides;
    }

    test('is recorded for a dive at a sea site', () async {
      final tides = await record(atReef);
      expect(tides.recorded, ['d1']);
      expect(tides.deleted, isEmpty);
    });

    // A tide record is worked out from the site, never typed: one left from
    // a site the dive is no longer at would show a tide that never was.
    test('is cleared for a dive taken off its site', () async {
      final tides = await record(atReef.copyWith(clearSite: true));
      expect(tides.recorded, isEmpty);
      expect(tides.deleted, ['d1']);
    });

    // A draft's tide is recorded at the dive's own entry position, with no
    // site (DraftConditionsService), and nothing records it again once the
    // draft has been tried: a save that only moved its time keeps it.
    test('is kept for a dive with its own position and no sited one', () async {
      final tides = await record(
        atReef.copyWith(clearSite: true, entryLocation: point),
      );
      expect(tides.recorded, isEmpty);
      expect(tides.deleted, isEmpty);
    });

    test('is cleared for a dive at a site with no location', () async {
      final tides = await record(
        atReef.copyWith(
          site: const DiveSite(id: 'lake', name: 'Lake'),
        ),
      );
      expect(tides.recorded, isEmpty);
      expect(tides.deleted, ['d1']);
    });

    // The tide model answers null for a fetch that failed with nothing
    // cached, or a grid this device has not got, as well as for a place it
    // does not cover: it cannot say the record is wrong, so it stays.
    test('is kept when the tide model cannot answer now', () async {
      final tides = await record(atReef, modelAnswers: false);
      expect(tides.recorded, isEmpty);
      expect(tides.deleted, isEmpty);
    });

    test('is cleared for a freshwater dive', () async {
      final tides = await record(atReef.copyWith(waterType: WaterType.fresh));
      expect(tides.recorded, isEmpty);
      expect(tides.deleted, ['d1']);
    });
  });
  // Copilot's review of PR #4670: each save's tide is recorded without
  // being waited for, and a record replaces the dive's last one. An older
  // save whose tide model answers late must not land over a newer save's.
  test('two saves in a row: the later save\'s tide is the one kept', () async {
    const there = GeoPoint(-16.5, 145.8);
    TideCalculator calculator(double amplitude) => TideCalculator(
      constituents: {
        'M2': TideConstituent(name: 'M2', amplitude: amplitude, phase: 0.0),
      },
    );
    final slow = Completer<ResolvedTideData?>();
    final tides = _Tides();
    final container = ProviderContainer(
      overrides: [
        tideRecordRepositoryProvider.overrideWithValue(tides),
        resolvedTideDataProvider(point).overrideWith((ref) => slow.future),
        resolvedTideDataProvider(there).overrideWith(
          (ref) async => ResolvedTideData(
            calculator: calculator(2.0),
            source: const TideDataSource.fesModel(),
          ),
        ),
        tideRecordForDiveProvider('d1').overrideWith((ref) async => null),
      ],
    );
    addTearDown(container.dispose);
    final record = container.read(diveTideRecordProvider);
    final entry = DateTime.utc(2026, 3, 28, 10);
    final first = Dive(
      id: 'd1',
      dateTime: entry,
      site: const DiveSite(id: 'a', name: 'A', location: point),
    );
    final second = first.copyWith(
      site: const DiveSite(id: 'b', name: 'B', location: there),
    );

    final older = record(first);
    final newer = record(second);
    await Future<void>.delayed(Duration.zero);
    slow.complete(
      ResolvedTideData(
        calculator: calculator(1.0),
        source: const TideDataSource.fesModel(),
      ),
    );
    await Future.wait([older, newer]);

    final alone = _Tides();
    await recordDiveTide(
      repository: alone,
      calculator: calculator(2.0),
      diveId: 'd1',
      entryWallClock: entry,
      location: there,
      waterType: null,
    );
    expect(tides.statuses, hasLength(2));
    expect(tides.statuses.last, alone.statuses.single);
  });
}
