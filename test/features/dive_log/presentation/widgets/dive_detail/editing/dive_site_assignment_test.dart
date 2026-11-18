import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_altitude_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_details_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_environment_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_header_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_site_assignment.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/weather/data/services/elevation_service.dart';
import 'package:submersion/features/weather/domain/services/altitude_resolver.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// Answers elevation lookups by latitude, counts them, and can hold one.
class _FakeElevation extends ElevationService {
  _FakeElevation(this.byLatitude)
    : super(client: MockClient((_) async => http.Response('', 500)));

  final Map<double, double?> byLatitude;
  final gates = <double, Completer<void>>{};
  int calls = 0;

  @override
  Future<double?> fetchElevation({
    required double latitude,
    required double longitude,
  }) async {
    calls++;
    await gates[latitude]?.future;
    return byLatitude[latitude];
  }
}

const _salt = DiveSite(id: 'salt', name: 'Reef', waterType: WaterType.salt);
const _plain = DiveSite(id: 'plain', name: 'Lake');
const _shore = DiveSite(
  id: 'shore',
  name: 'Beach',
  entryMethods: [EntryMethod.shore],
);
const _boatOut = DiveSite(
  id: 'boatOut',
  name: 'Cove',
  entryMethods: [EntryMethod.shore],
  exitMethods: [EntryMethod.boat],
);
const _highA = DiveSite(id: 'a', name: 'Alpine A', location: GeoPoint(46, 8));
const _highB = DiveSite(id: 'b', name: 'Alpine B', location: GeoPoint(47, 9));
const _withAltitude = DiveSite(
  id: 'known',
  name: 'Known',
  location: GeoPoint(45, 7),
  altitude: 700,
);

/// Picking a site in a sitting sets what the site says on the cards that
/// own each value, and takes back what the previous site set unless the
/// diver changed it since (issue #4527, plan 4).
void main() {
  final bare = Dive(id: 'dive', dateTime: DateTime.utc(2026, 3, 9, 9));
  late _FakeElevation elevation;
  late List<(String, double)> siteWrites;
  late Map<String, List<String>> typesBySite;
  late Map<String, Completer<void>> typeGates;
  late int typeReads;

  setUp(() {
    elevation = _FakeElevation({46: 512, 47: 1300, 45: 999});
    siteWrites = [];
    typesBySite = {
      'salt': ['wreck'],
    };
    typeGates = {};
    typeReads = 0;
  });

  Future<List<String>> readTypes(String siteId) async {
    typeReads++;
    await typeGates[siteId]?.future;
    if (siteId == 'broken') throw StateError('no database');
    return typesBySite[siteId] ?? const [];
  }

  void assign(EditSession<Dive> session, DiveSite? site) => assignDiveSite(
    session,
    site,
    siteDiveTypeIds: readTypes,
    resolver: AltitudeResolver(elevationService: elevation),
    writeSiteAltitude: (id, m) async => siteWrites.add((id, m)),
  );

  /// Lets lookups and reads that are not held answer.
  Future<void> answer(EditSession<Dive> session) async {
    await session.settled();
    await pumpEventQueue();
  }

  group('water type', () {
    test('a site with a water type sets it', () async {
      final session = EditSession(bare);
      assign(session, _salt);
      expect(session.valueOf(diveWaterTypeField), WaterType.salt);
    });

    test('a site with none keeps the dive\'s', () {
      final session = EditSession(bare.copyWith(waterType: WaterType.fresh));
      assign(session, _plain);
      expect(session.valueOf(diveWaterTypeField), WaterType.fresh);
    });

    test('one the diver picked is replaced by a site that has one', () {
      final session = EditSession(bare)
        ..set(diveWaterTypeField, WaterType.fresh);
      assign(session, _salt);
      expect(session.valueOf(diveWaterTypeField), WaterType.salt);
    });

    test('site A then site B with none gives back the dive\'s own', () {
      final session = EditSession(bare.copyWith(waterType: WaterType.fresh));
      assign(session, _salt);
      assign(session, _plain);
      expect(session.valueOf(diveWaterTypeField), WaterType.fresh);
    });

    test('site A then cleared gives back the dive\'s own, and holds no '
        'water type change', () async {
      final session = EditSession(bare);
      assign(session, _salt);
      assign(session, null);
      await answer(session);
      expect(session.valueOf(diveWaterTypeField), isNull);
      expect(session.changedCardIds, isNot(contains('details')));
    });

    test('one the diver picked after site A is kept by site B with none', () {
      final session = EditSession(bare);
      assign(session, _salt);
      session.set(diveWaterTypeField, WaterType.brackish);
      assign(session, _plain);
      expect(session.valueOf(diveWaterTypeField), WaterType.brackish);
    });
  });

  group('entry and exit', () {
    test('a site\'s single entry and exit fill both', () {
      final session = EditSession(bare);
      assign(session, _boatOut);
      expect(session.valueOf(diveEntryMethodField), EntryMethod.shore);
      expect(session.valueOf(diveExitMethodField), EntryMethod.boat);
    });

    test('a still linked exit follows a site\'s single entry', () {
      final session = EditSession(bare);
      assign(session, _shore);
      expect(session.valueOf(diveExitMethodField), EntryMethod.shore);
    });

    test('an exit edited directly is kept, even when equal to the entry', () {
      final session = EditSession(bare);
      session.set(diveEntryMethodField, EntryMethod.ladder);
      exitEditedDirectly(session);
      session.set(diveExitMethodField, EntryMethod.ladder);

      assign(session, _boatOut);

      expect(session.valueOf(diveEntryMethodField), EntryMethod.shore);
      expect(session.valueOf(diveExitMethodField), EntryMethod.ladder);
      expect(exitFollows(session), isFalse);
    });

    test('site A then site B with no methods gives back the dive\'s own', () {
      final session = EditSession(
        bare.copyWith(
          entryMethod: EntryMethod.ladder,
          exitMethod: EntryMethod.ladder,
        ),
      );
      assign(session, _boatOut);
      assign(session, _plain);
      expect(session.valueOf(diveEntryMethodField), EntryMethod.ladder);
      expect(session.valueOf(diveExitMethodField), EntryMethod.ladder);
    });
  });

  group('altitude', () {
    test(
      'a site with an altitude fills an empty one, and holds no write',
      () async {
        final session = EditSession(bare);
        assign(session, _withAltitude);
        await answer(session);

        expect(session.valueOf(diveAltitudeField), 700);
        expect(session.hasHeldWrites, isFalse);
        expect(elevation.calls, 0);
      },
    );

    test('a site looked up holds its site write', () async {
      final session = EditSession(bare);
      assign(session, _highA);
      await answer(session);

      expect(session.valueOf(diveAltitudeField), 512);
      expect(session.isHeld(siteAltitudeWriteKey('a')), isTrue);
    });

    test('site A looked up, then site B: A\'s is taken back, its write '
        'released, and B looked up', () async {
      final session = EditSession(bare);
      assign(session, _highA);
      await answer(session);

      assign(session, _highB);
      expect(session.isHeld(siteAltitudeWriteKey('a')), isFalse);
      await answer(session);

      expect(session.valueOf(diveAltitudeField), 1300);
      await session.runHeldWrites();
      expect(siteWrites, [('b', 1300.0)]);
    });

    test('site A looked up, then cleared: the altitude goes', () async {
      final session = EditSession(bare);
      assign(session, _highA);
      await answer(session);

      assign(session, null);
      await answer(session);

      expect(session.valueOf(diveAltitudeField), isNull);
      expect(session.hasHeldWrites, isFalse);
      expect(session.isDirty, isFalse);
    });

    // The take-back gives back the value before the lookup, not the stored
    // one: a stored altitude the diver cleared must not come back.
    test('a stored altitude the diver cleared stays cleared when the '
        'looked-up one is taken back', () async {
      final session = EditSession(bare.copyWith(altitude: 300))
        ..set(diveAltitudeField, null);
      assign(session, _highA);
      await answer(session);
      expect(session.valueOf(diveAltitudeField), 512);

      assign(session, null);
      await answer(session);

      expect(session.valueOf(diveAltitudeField), isNull);
      expect(session.hasHeldWrites, isFalse);
    });

    test('a stored altitude is never replaced', () async {
      final session = EditSession(bare.copyWith(altitude: 300));
      assign(session, _highA);
      await answer(session);

      expect(session.valueOf(diveAltitudeField), 300);
      expect(elevation.calls, 0);
    });

    test('one the diver typed is never replaced or taken back', () async {
      final session = EditSession(bare);
      assign(session, _highA);
      await answer(session);
      session.set(diveAltitudeField, 600.0);

      assign(session, _highB);
      await answer(session);

      expect(session.valueOf(diveAltitudeField), 600);
    });

    test('A\'s lookup answering after B was picked sets nothing', () async {
      final session = EditSession(bare);
      final gate = elevation.gates[46] = Completer<void>();
      assign(session, _highA);
      assign(session, _highB);
      await answer(session);
      expect(session.valueOf(diveAltitudeField), 1300);

      gate.complete();
      await answer(session);

      expect(session.valueOf(diveAltitudeField), 1300);
      expect(session.isHeld(siteAltitudeWriteKey('a')), isFalse);
    });
  });

  group('dive types', () {
    test('a site standing for wreck adds wreck', () async {
      final session = EditSession(bare.copyWith(diveTypeIds: ['boat']));
      assign(session, _salt);
      await answer(session);
      expect(session.valueOf(diveTypeIdsField), ['boat', 'wreck']);
    });

    test('clearing takes back what it added', () async {
      final session = EditSession(bare.copyWith(diveTypeIds: ['boat']));
      assign(session, _salt);
      await answer(session);
      assign(session, null);
      await answer(session);
      expect(session.valueOf(diveTypeIdsField), ['boat']);
    });

    test('a type ticked again by hand survives the next site', () async {
      final session = EditSession(bare.copyWith(diveTypeIds: ['boat']));
      assign(session, _salt);
      await answer(session);
      diveTypesEditedByHand(session, ['boat']);
      session.set(diveTypeIdsField, <String>['boat']);
      diveTypesEditedByHand(session, ['boat', 'wreck']);
      session.set(diveTypeIdsField, <String>['boat', 'wreck']);

      assign(session, null);
      await answer(session);

      expect(session.valueOf(diveTypeIdsField), ['boat', 'wreck']);
    });

    test('a failed read leaves the types alone', () async {
      final session = EditSession(bare.copyWith(diveTypeIds: ['boat']));
      assign(session, const DiveSite(id: 'broken', name: 'Broken'));
      await answer(session);
      expect(session.valueOf(diveTypeIdsField), ['boat']);
    });

    test('A\'s types answering after B was picked are dropped', () async {
      final session = EditSession(bare.copyWith(diveTypeIds: ['boat']));
      final gate = typeGates['salt'] = Completer<void>();
      assign(session, _salt);
      assign(session, _plain);
      gate.complete();
      await answer(session);
      expect(session.valueOf(diveTypeIdsField), ['boat']);
    });

    test('a save waits for the types', () async {
      final session = EditSession(bare.copyWith(diveTypeIds: ['boat']));
      final gate = typeGates['salt'] = Completer<void>();
      assign(session, _salt);
      var settled = false;
      unawaited(session.settled().then((_) => settled = true));
      await pumpEventQueue();
      expect(settled, isFalse);

      gate.complete();
      await pumpEventQueue();

      expect(settled, isTrue);
      expect(session.valueOf(diveTypeIdsField), ['boat', 'wreck']);
    });
  });

  test('a location held for site A is released when B is picked', () {
    final session = EditSession(bare.copyWith(site: _highA))
      ..holdChange(
        siteLocationChangeKey('a'),
        cardId: diveHeaderCardId,
        write: () async {},
      );
    assign(session, _highB);
    expect(session.isHeld(siteLocationChangeKey('a')), isFalse);
  });

  test('a dismissed suggestion is kept when the site changes', () {
    final session = EditSession(bare)
      ..holdChange(
        siteSuggestionDismissKey,
        cardId: diveHeaderCardId,
        write: () async {},
      );
    assign(session, _salt);
    expect(session.isHeld(siteSuggestionDismissKey), isTrue);
  });

  test('picking the same site again does nothing', () async {
    final session = EditSession(bare.copyWith(site: _salt));
    assign(session, _salt);
    await answer(session);
    expect(session.isDirty, isFalse);
    expect(typeReads, 0);
  });

  test(
    'ended before the lookups answer: nothing set, nothing thrown',
    () async {
      final session = EditSession(bare);
      final gate = typeGates['salt'] = Completer<void>();
      elevation.gates[46] = Completer<void>();
      assign(session, _salt);
      session.dispose();
      gate.complete();
      elevation.gates[46]!.complete();
      await pumpEventQueue();
      expect(session.valueOf(diveTypeIdsField), bare.diveTypeIds);
      expect(session.valueOf(diveAltitudeField), isNull);
    },
  );

  test('each value lands on its own card', () async {
    final session = EditSession(bare);
    assign(
      session,
      const DiveSite(
        id: 'salt',
        name: 'Reef',
        waterType: WaterType.salt,
        entryMethods: [EntryMethod.shore],
        altitude: 10,
      ),
    );
    await answer(session);
    expect(session.changedCardIds, {
      'header',
      'details',
      'environment',
      'altitude',
    });
  });

  group('exitFollows', () {
    test('is settled the first time it is asked', () {
      final stored = bare.copyWith(
        entryMethod: EntryMethod.shore,
        exitMethod: EntryMethod.boat,
      );
      final session = EditSession(stored);
      expect(exitFollows(session), isFalse);

      session.rebase(stored.copyWith(exitMethod: EntryMethod.shore));

      expect(exitFollows(session), isFalse);
    });

    test('an edit of the exit stops it for the rest of the sitting', () {
      final session = EditSession(bare);
      expect(exitFollows(session), isTrue);
      exitEditedDirectly(session);
      expect(exitFollows(session), isFalse);
    });
  });
}
