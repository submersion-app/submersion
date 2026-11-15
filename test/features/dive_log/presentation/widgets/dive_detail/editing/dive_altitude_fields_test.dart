import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_altitude_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_edit_cards.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/weather/data/services/elevation_service.dart';
import 'package:submersion/features/weather/domain/services/altitude_resolver.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// Answers elevation lookups from a fixed value, counts them, and can hold
/// one until released or fail it.
class _FakeElevation extends ElevationService {
  _FakeElevation({this.result, this.gate, this.fail = false})
    : super(client: MockClient((_) async => http.Response('', 500)));

  final double? result;
  final Completer<void>? gate;
  final bool fail;
  int calls = 0;

  @override
  Future<double?> fetchElevation({
    required double latitude,
    required double longitude,
  }) async {
    calls++;
    await gate?.future;
    if (fail) throw StateError('offline');
    return result;
  }
}

const _cardId = 'altitude';

/// The values the Altitude card edits, and the lookup that fills an empty
/// altitude (issue #4527).
void main() {
  final bare = Dive(id: 'dive', dateTime: DateTime(2024, 6, 1, 10));
  final high = bare.copyWith(altitude: 1200, surfacePressure: 0.87);

  const lakeNoAltitude = DiveSite(
    id: 'site-1',
    name: 'Lake',
    location: GeoPoint(46.5, 8.6),
  );
  const lakeAt900 = DiveSite(
    id: 'site-1',
    name: 'Lake',
    location: GeoPoint(46.5, 8.6),
    altitude: 900,
  );

  group('the card and its fields', () {
    final card = diveEditCards[DiveDetailSectionId.altitude]!;

    test('the card is left out at or below sea level', () {
      expect(card.id, _cardId);
      expect(card.isEmpty(bare), isTrue);
      expect(card.isEmpty(bare.copyWith(altitude: 0)), isTrue);
      expect(card.isEmpty(bare.copyWith(altitude: -5)), isTrue);
      expect(card.isEmpty(bare.copyWith(altitude: 1)), isFalse);
    });

    test('both fields belong to the Altitude card', () {
      expect(diveAltitudeField.cardId, _cardId);
      expect(diveSurfacePressureField.cardId, _cardId);
      expect(diveAltitudeField.read(high), 1200);
      expect(diveSurfacePressureField.read(high), 0.87);
    });

    test('writing a value replaces it and writing null clears it', () {
      expect(diveAltitudeField.write(high, 300).altitude, 300);
      expect(diveAltitudeField.write(high, null).altitude, isNull);
      expect(diveSurfacePressureField.write(high, 0.9).surfacePressure, 0.9);
      expect(
        diveSurfacePressureField.write(high, null).surfacePressure,
        isNull,
      );
    });

    test('a field writes nothing but its own value', () {
      final written = diveAltitudeField.write(high, null);

      expect(written.surfacePressure, 0.87);
      expect(written.copyWith(altitude: 1200), high);
    });
  });

  group('fillAltitudeIfEmpty', () {
    late List<(String, double)> wrote;

    Future<void> writeSite(String siteId, double meters) async {
      wrote.add((siteId, meters));
    }

    EditSession<Dive> sessionOver(Dive dive) {
      final session = EditSession<Dive>(dive);
      addTearDown(session.dispose);
      return session;
    }

    setUp(() => wrote = []);

    test('does nothing when an altitude is already set', () async {
      final elevation = _FakeElevation(result: 512);
      final session = sessionOver(high.copyWith(site: lakeNoAltitude));

      await fillAltitudeIfEmpty(
        session,
        resolver: AltitudeResolver(elevationService: elevation),
        writeSiteAltitude: writeSite,
      );

      expect(elevation.calls, 0);
      expect(session.isDirty, isFalse);
      expect(session.hasHeldWrites, isFalse);
    });

    test('an altitude of zero counts as set', () async {
      final elevation = _FakeElevation(result: 512);
      final session = sessionOver(
        bare.copyWith(altitude: 0, site: lakeNoAltitude),
      );

      await fillAltitudeIfEmpty(
        session,
        resolver: AltitudeResolver(elevationService: elevation),
        writeSiteAltitude: writeSite,
      );

      expect(elevation.calls, 0);
      expect(session.isDirty, isFalse);
    });

    test('sets it from the dive GPS and holds no site write', () async {
      final session = sessionOver(
        bare.copyWith(
          entryLocation: const GeoPoint(46.5, 8.6),
          site: lakeNoAltitude,
        ),
      );

      await fillAltitudeIfEmpty(
        session,
        resolver: AltitudeResolver(
          elevationService: _FakeElevation(result: 512),
        ),
        writeSiteAltitude: writeSite,
      );

      expect(session.valueOf(diveAltitudeField), 512);
      expect(session.changedCardIds, {_cardId});
      expect(session.hasHeldWrites, isFalse);
    });

    test('uses the site altitude without a lookup', () async {
      final elevation = _FakeElevation(result: 512);
      final session = sessionOver(bare.copyWith(site: lakeAt900));

      await fillAltitudeIfEmpty(
        session,
        resolver: AltitudeResolver(elevationService: elevation),
        writeSiteAltitude: writeSite,
      );

      expect(session.valueOf(diveAltitudeField), 900);
      expect(elevation.calls, 0);
      expect(session.hasHeldWrites, isFalse);
    });

    test('a site coordinate lookup sets it and holds the site write', () async {
      final session = sessionOver(bare.copyWith(site: lakeNoAltitude));

      await fillAltitudeIfEmpty(
        session,
        resolver: AltitudeResolver(
          elevationService: _FakeElevation(result: 512),
        ),
        writeSiteAltitude: writeSite,
      );

      expect(session.valueOf(diveAltitudeField), 512);
      expect(session.hasHeldWrites, isTrue);
      // Held, not written: the site changes only when the sitting is saved.
      expect(wrote, isEmpty);

      await session.runHeldWrites();

      expect(wrote, [('site-1', 512.0)]);
    });

    // The site is given the altitude that was looked up for the dive. A
    // diver who then types another, or takes it out, has not accepted it.
    for (final (name, typed) in [('typed over', 600.0), ('cleared', null)]) {
      test(
        'a looked-up altitude the diver $name is not written to the site',
        () async {
          final session = sessionOver(bare.copyWith(site: lakeNoAltitude));
          await fillAltitudeIfEmpty(
            session,
            resolver: AltitudeResolver(
              elevationService: _FakeElevation(result: 512),
            ),
            writeSiteAltitude: writeSite,
          );

          session.set(diveAltitudeField, typed);
          await session.runHeldWrites();

          expect(wrote, isEmpty);
        },
      );
    }

    test('a diver who typed a value while the lookup ran keeps it', () async {
      final gate = Completer<void>();
      final session = sessionOver(bare.copyWith(site: lakeNoAltitude));

      final filling = fillAltitudeIfEmpty(
        session,
        resolver: AltitudeResolver(
          elevationService: _FakeElevation(result: 512, gate: gate),
        ),
        writeSiteAltitude: writeSite,
      );
      // A double, spelled out: an int literal here is inferred as num and
      // fails in the field's comparison at run time.
      session.set(diveAltitudeField, 10.0);
      gate.complete();
      await filling;

      expect(session.valueOf(diveAltitudeField), 10);
      expect(session.hasHeldWrites, isFalse);
    });

    // The dive can change underneath while the lookup runs, a sync bringing
    // in another site, say. What was found is for the dive as it was asked
    // about, and is not put on another.
    test('a lookup for a site the dive no longer has is dropped', () async {
      final gate = Completer<void>();
      final session = sessionOver(bare.copyWith(site: lakeNoAltitude));

      final filling = fillAltitudeIfEmpty(
        session,
        resolver: AltitudeResolver(
          elevationService: _FakeElevation(result: 512, gate: gate),
        ),
        writeSiteAltitude: writeSite,
      );
      session.rebase(
        bare.copyWith(
          site: const DiveSite(
            id: 'site-2',
            name: 'Quarry',
            location: GeoPoint(51.2, -2.5),
          ),
        ),
      );
      gate.complete();
      await filling;

      expect(session.valueOf(diveAltitudeField), isNull);
      expect(session.hasHeldWrites, isFalse);
    });

    test('a lookup that finds nothing changes nothing', () async {
      final session = sessionOver(bare.copyWith(site: lakeNoAltitude));

      await fillAltitudeIfEmpty(
        session,
        resolver: AltitudeResolver(elevationService: _FakeElevation()),
        writeSiteAltitude: writeSite,
      );

      expect(session.isDirty, isFalse);
      expect(session.hasHeldWrites, isFalse);
    });

    test('a lookup that fails changes nothing and does not throw', () async {
      final session = sessionOver(bare.copyWith(site: lakeNoAltitude));

      await fillAltitudeIfEmpty(
        session,
        resolver: AltitudeResolver(
          elevationService: _FakeElevation(fail: true),
        ),
        writeSiteAltitude: writeSite,
      );

      expect(session.isDirty, isFalse);
    });

    test('a dive with no GPS and no site is left alone', () async {
      final elevation = _FakeElevation(result: 512);
      final session = sessionOver(bare);

      await fillAltitudeIfEmpty(
        session,
        resolver: AltitudeResolver(elevationService: elevation),
        writeSiteAltitude: writeSite,
      );

      expect(elevation.calls, 0);
      expect(session.isDirty, isFalse);
    });

    test('a result nobody is waiting for is dropped', () async {
      final gate = Completer<void>();
      final session = sessionOver(bare.copyWith(site: lakeNoAltitude));
      var wanted = true;

      final filling = fillAltitudeIfEmpty(
        session,
        resolver: AltitudeResolver(
          elevationService: _FakeElevation(result: 512, gate: gate),
        ),
        writeSiteAltitude: writeSite,
        stillWanted: () => wanted,
      );
      wanted = false;
      gate.complete();
      await filling;

      expect(session.isDirty, isFalse);
      expect(session.hasHeldWrites, isFalse);
    });

    test('a lookup that returns while the sitting is being saved changes '
        'nothing', () async {
      final gate = Completer<void>();
      final session = sessionOver(bare.copyWith(site: lakeNoAltitude));

      final filling = fillAltitudeIfEmpty(
        session,
        resolver: AltitudeResolver(
          elevationService: _FakeElevation(result: 512, gate: gate),
        ),
        writeSiteAltitude: writeSite,
      );
      session.freeze();
      gate.complete();
      await filling;
      session.thaw();

      expect(session.isDirty, isFalse);
      expect(session.hasHeldWrites, isFalse);
    });

    test('a sitting discarded while the lookup ran is left alone', () async {
      final gate = Completer<void>();
      final session = EditSession<Dive>(bare.copyWith(site: lakeNoAltitude));

      final filling = fillAltitudeIfEmpty(
        session,
        resolver: AltitudeResolver(
          elevationService: _FakeElevation(result: 512, gate: gate),
        ),
        writeSiteAltitude: writeSite,
      );
      session.dispose();
      gate.complete();

      await expectLater(filling, completes);
    });
  });
}
