import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/geocoding/place_lookup.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_location_rules.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_plain_fields.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// The form's location and altitude rules, as functions of a site's
/// sitting (issue #4527, phase 2, plan 2).
void main() {
  final l10n = AppLocalizationsEn();
  const lookup = PlaceLookup(
    country: 'Belize',
    countryCode: 'BZ',
    region: 'Lighthouse Reef',
    locality: 'Belize City',
    bodyOfWater: 'Caribbean Sea',
  );

  EditSession<DiveSite> sitting([DiveSite? site]) =>
      EditSession<DiveSite>(site ?? const DiveSite(id: 's1', name: 'Hole'));

  group('place lookups', () {
    test('fill only empty names', () {
      final session = sitting(
        const DiveSite(id: 's1', name: 'Hole', region: 'Turneffe'),
      );

      expect(applyPlaceLookup(session, lookup, overwrite: false), isTrue);

      expect(session.valueOf(siteCountryField), 'Belize');
      expect(session.valueOf(siteRegionField), 'Turneffe');
      expect(session.valueOf(siteCityField), 'Belize City');
      expect(session.valueOf(siteBodyOfWaterField), 'Caribbean Sea');
    });

    test('overwrite replaces differing ones', () {
      final session = sitting(
        const DiveSite(id: 's1', name: 'Hole', region: 'Turneffe'),
      );

      applyPlaceLookup(session, lookup, overwrite: true);

      expect(session.valueOf(siteRegionField), 'Lighthouse Reef');
    });

    test('a written country keeps its code', () {
      final session = sitting();

      applyPlaceLookup(session, lookup, overwrite: false);

      expect(session.valueOf(siteCountryCodeField), 'BZ');
    });

    test('differingPlaceValues lists only found values that differ', () {
      final session = sitting(
        const DiveSite(
          id: 's1',
          name: 'Hole',
          country: 'Belize',
          region: 'Turneffe',
        ),
      );

      expect(differingPlaceValues(sittingPlaceNames(session), lookup, l10n), {
        l10n.diveSites_edit_field_region_label: 'Lighthouse Reef',
        l10n.diveSites_edit_field_city_label: 'Belize City',
        l10n.diveSites_edit_field_bodyOfWater_label: 'Caribbean Sea',
      });
    });

    test('moveSiteTo sets the position and fills empty names', () {
      final session = sitting();

      moveSiteTo(session, const GeoPoint(17.3, -87.5), place: lookup);

      expect(session.valueOf(siteLocationField), const GeoPoint(17.3, -87.5));
      expect(session.valueOf(siteCountryField), 'Belize');
      expect(session.changedCardIds, {'location'});
    });
  });

  group('the altitude after a move', () {
    test('fills an empty altitude a second later', () {
      fakeAsync((async) {
        final session = sitting();
        final asked = <GeoPoint>[];
        session.set(siteLocationField, const GeoPoint(1, 2));
        scheduleAltitudeAfterMove(session, (point) async {
          asked.add(point);
          return 12;
        });

        async.elapse(const Duration(milliseconds: 900));
        expect(asked, isEmpty);
        async.elapse(const Duration(milliseconds: 200));
        async.flushMicrotasks();

        expect(session.valueOf(siteAltitudeField), 12);
        expect(session.changedCardIds, contains('altitude'));
      });
    });

    test('an elevation below sea level is not filled, as the form '
        'would refuse it', () {
      fakeAsync((async) {
        final session = sitting();
        session.set(siteLocationField, const GeoPoint(31.5, 35.5));
        scheduleAltitudeAfterMove(session, (_) async => -400);

        async.elapse(const Duration(milliseconds: 1100));
        async.flushMicrotasks();

        expect(session.valueOf(siteAltitudeField), isNull);
      });
    });

    // The form's case: an elevation service that fails fills nothing.
    test('a failed lookup leaves the altitude empty and the card clean', () {
      fakeAsync((async) {
        final session = sitting();
        session.set(siteLocationField, const GeoPoint(1, 2));
        scheduleAltitudeAfterMove(session, (_) async => null);

        async.elapse(const Duration(milliseconds: 1100));
        async.flushMicrotasks();

        expect(session.valueOf(siteAltitudeField), isNull);
        expect(session.changedCardIds, isNot(contains('altitude')));
      });
    });

    test('a typed altitude stands', () {
      fakeAsync((async) {
        final session = sitting();
        final answer = Completer<double?>();
        session.set(siteLocationField, const GeoPoint(1, 2));
        scheduleAltitudeAfterMove(session, (_) => answer.future);
        async.elapse(const Duration(seconds: 1));

        session.set(siteAltitudeField, 30.0);
        answer.complete(12);
        async.flushMicrotasks();

        expect(session.valueOf(siteAltitudeField), 30);
      });
    });

    test('a lookup for an old position is dropped', () {
      fakeAsync((async) {
        final session = sitting();
        final answers = <GeoPoint, Completer<double?>>{};
        Future<double?> fetch(GeoPoint point) =>
            (answers[point] = Completer<double?>()).future;

        session.set(siteLocationField, const GeoPoint(1, 2));
        scheduleAltitudeAfterMove(session, fetch);
        async.elapse(const Duration(seconds: 1));
        session.set(siteLocationField, const GeoPoint(3, 4));
        scheduleAltitudeAfterMove(session, fetch);
        answers[const GeoPoint(1, 2)]!.complete(12);
        async.flushMicrotasks();
        expect(session.valueOf(siteAltitudeField), isNull);

        async.elapse(const Duration(seconds: 1));
        answers[const GeoPoint(3, 4)]!.complete(40);
        async.flushMicrotasks();
        expect(session.valueOf(siteAltitudeField), 40);
      });
    });
  });

  group('the found altitude', () {
    test('changes nothing and is asked once', () async {
      final session = sitting(
        const DiveSite(id: 's1', name: 'Hole', location: GeoPoint(1, 2)),
      );
      var asks = 0;
      Future<double?> fetch(GeoPoint _) async {
        asks++;
        return 12;
      }

      expect(await foundAltitude(session, fetch), 12);
      expect(await foundAltitude(session, fetch), 12);

      expect(asks, 1);
      expect(session.isDirty, isFalse);
    });

    test('is not asked for a site with an altitude or no position', () async {
      var asks = 0;
      Future<double?> fetch(GeoPoint _) async {
        asks++;
        return 12;
      }

      expect(await foundAltitude(sitting(), fetch), isNull);
      expect(
        await foundAltitude(
          sitting(
            const DiveSite(
              id: 's1',
              name: 'Hole',
              location: GeoPoint(1, 2),
              altitude: 3,
            ),
          ),
          fetch,
        ),
        isNull,
      );
      expect(asks, 0);
    });
  });
}
