import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/domain/visibility/visibility_range.dart';
import 'package:submersion/core/domain/visibility/visibility_scale.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_details_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/visibility_input/visibility_entry.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

Trip _trip(String id, {DateTime? end}) => Trip(
  id: id,
  name: 'Trip $id',
  startDate: DateTime(2024, 3, 1),
  endDate: end ?? DateTime(2024, 3, 3),
  createdAt: DateTime(2024),
  updatedAt: DateTime(2024),
);

DiveCenter _center(String id, {String? city}) => DiveCenter(
  id: id,
  name: 'Center $id',
  city: city,
  createdAt: DateTime(2024),
  updatedAt: DateTime(2024),
);

/// The values the Details card edits, as fields of a sitting (issue #4527).
void main() {
  final bare = Dive(id: 'dive', dateTime: DateTime(2024, 6, 1, 10));
  final tripA = _trip('a');
  final centerA = _center('a');
  const range = VisibilityRange(minM: 10, maxM: 20);

  final all = <EditField<Dive, Object?>>[
    diveTypeIdsField,
    diveTripField,
    diveTripIdField,
    diveCenterField,
    diveOperatorField,
    diveBoatNameField,
    diveBoatCaptainField,
    diveCourseIdsField,
    diveVisibilityField,
    diveWaterTypeField,
    diveExcludedFromStatsField,
    diveExcludedFromGasStatsField,
  ];

  test('every field belongs to the Details card, under an id of its own', () {
    expect(all, hasLength(12));
    expect({for (final field in all) field.cardId}, {'details'});
    expect({for (final field in all) field.id}, hasLength(12));
  });

  test('only the header shows a Details value: the dive types', () {
    // The Tide card and the Environment card's satellite conditions follow
    // the water type, but they are laid out from the dive the page's layout
    // is held to, not redrawn as it is picked. The header block draws the
    // dive's types from the sitting (issue #4527, plan 4).
    for (final field in all) {
      expect(
        field.alsoShownOn,
        field == diveTypeIdsField ? {'header'} : isEmpty,
        reason: field.id,
      );
    }
  });

  group('trip', () {
    test('writing a trip sets the trip and its id', () {
      final dive = diveTripField.write(bare, tripA);
      expect((dive.trip?.id, dive.tripId), ('a', 'a'));
    });

    test('writing no trip clears the trip and its id', () {
      final onTrip = bare.copyWith(trip: tripA, tripId: 'a');
      final dive = diveTripField.write(onTrip, null);
      expect((dive.trip, dive.tripId), (null, null));
    });

    test('moving to another trip replaces the id', () {
      final onTrip = bare.copyWith(trip: tripA, tripId: 'a');
      final dive = diveTripField.write(onTrip, _trip('b'));
      expect((dive.trip?.id, dive.tripId), ('b', 'b'));
    });

    // The trip id alone, for a dive whose trip did not load (issue #4527).
    test('the trip id reads the id, or the carried trip\'s', () {
      expect(diveTripIdField.read(bare.copyWith(tripId: 'gone')), 'gone');
      expect(diveTripIdField.read(bare.copyWith(trip: tripA)), 'a');
      expect(diveTripIdField.read(bare), isNull);
    });

    test('writing no trip id clears the id and any trip', () {
      final dive = diveTripIdField.write(
        bare.copyWith(trip: tripA, tripId: 'a'),
        null,
      );
      expect((dive.trip, dive.tripId), (null, null));
    });

    test(
      'writing another trip id drops the trip that no longer matches it',
      () {
        final onTrip = bare.copyWith(trip: tripA, tripId: 'a');
        final moved = diveTripIdField.write(onTrip, 'b');
        expect((moved.trip, moved.tripId), (null, 'b'));
        final kept = diveTripIdField.write(onTrip, 'a');
        expect((kept.trip?.id, kept.tripId), ('a', 'a'));
      },
    );

    test('the same trip with other dates is not a change', () {
      final later = _trip('a', end: DateTime(2024, 3, 9));
      expect(diveTripField.same(tripA, later), isTrue);
      expect(diveTripField.same(tripA, _trip('b')), isFalse);
      expect(diveTripField.same(tripA, null), isFalse);
      expect(diveTripField.same(null, null), isTrue);
    });

    test('a pending trip is dropped when the stored dive catches up', () {
      final session = EditSession<Dive>(bare)..set(diveTripField, tripA);
      addTearDown(session.dispose);
      expect(session.isDirty, isTrue);

      session.rebase(
        bare.copyWith(
          trip: _trip('a', end: DateTime(2024, 3, 9)),
          tripId: 'a',
        ),
      );

      expect(session.isDirty, isFalse);
    });
  });

  group('dive center', () {
    test('writing a center sets it, and none clears it', () {
      final withCenter = diveCenterField.write(bare, centerA);
      expect(withCenter.diveCenter?.id, 'a');
      expect(diveCenterField.write(withCenter, null).diveCenter, isNull);
    });

    test('the same center with other details is not a change', () {
      expect(
        diveCenterField.same(centerA, _center('a', city: 'Dahab')),
        isTrue,
      );
      expect(diveCenterField.same(centerA, _center('b')), isFalse);
      expect(diveCenterField.same(centerA, null), isFalse);
    });
  });

  group('operator, boat and captain', () {
    final cases = <String, (EditField<Dive, String?>, String? Function(Dive))>{
      'operator': (diveOperatorField, (d) => d.diveOperator),
      'boat': (diveBoatNameField, (d) => d.boatName),
      'captain': (diveBoatCaptainField, (d) => d.boatCaptain),
    };
    final named = bare.copyWith(
      diveOperator: 'Emperor',
      boatName: 'Elite',
      boatCaptain: 'Sam',
    );

    for (final MapEntry(key: name, value: (field, read)) in cases.entries) {
      test('$name is stored trimmed', () {
        expect(read(field.write(bare, '  Aggressor ')), 'Aggressor');
      });

      test('$name is cleared by null and by blank text', () {
        expect(read(named), isNotNull);
        expect(read(field.write(named, null)), isNull);
        expect(read(field.write(named, '   ')), isNull);
      });

      test('$name ignores the space around its words', () {
        expect(field.same(' Emperor ', 'Emperor'), isTrue);
        expect(field.same('', null), isTrue);
        expect(field.same('Emperor', 'Aggressor'), isFalse);
      });

      test('writing $name leaves the other two alone', () {
        final written = field.write(named, 'Other');
        final others = cases.entries.where((e) => e.key != name);
        for (final other in others) {
          expect(other.value.$2(written), other.value.$2(named));
        }
      });
    }
  });

  group('dive types', () {
    test('the same ids in the same order are not a change', () {
      final session = EditSession<Dive>(
        bare.copyWith(diveTypeIds: ['wreck', 'night']),
      );
      addTearDown(session.dispose);

      session.set(diveTypeIdsField, <String>['wreck', 'night']);

      expect(session.isDirty, isFalse);
    });

    test('another order is a change: the first is the representative', () {
      final session = EditSession<Dive>(
        bare.copyWith(diveTypeIds: ['wreck', 'night']),
      );
      addTearDown(session.dispose);

      session.set(diveTypeIdsField, <String>['night', 'wreck']);

      expect(session.isDirty, isTrue);
      expect(session.working.diveTypeId, 'night');
    });

    test('the list written is a copy', () {
      final ids = <String>['wreck'];
      final dive = diveTypeIdsField.write(bare, ids);
      ids.add('night');
      expect(dive.diveTypeIds, ['wreck']);
    });
  });

  group('courses', () {
    test('the same ids in the same order are not a change', () {
      final session = EditSession<Dive>(bare.copyWith(courseIds: ['c1', 'c2']));
      addTearDown(session.dispose);

      session.set(diveCourseIdsField, <String>['c1', 'c2']);

      expect(session.isDirty, isFalse);
    });

    // The writer stores the set and picks the representative course itself,
    // so an order is nothing the diver can save.
    test('another order is not a change', () {
      final session = EditSession<Dive>(bare.copyWith(courseIds: ['c1', 'c2']));
      addTearDown(session.dispose);

      session.set(diveCourseIdsField, <String>['c2', 'c1']);

      expect(session.isDirty, isFalse);
    });

    test('a course added or dropped is a change', () {
      final session = EditSession<Dive>(bare.copyWith(courseIds: ['c1', 'c2']));
      addTearDown(session.dispose);

      session.set(diveCourseIdsField, <String>['c1', 'c2', 'c3']);
      expect(session.isDirty, isTrue);
      session.set(diveCourseIdsField, <String>['c1']);
      expect(session.isDirty, isTrue);
    });

    test('an empty list clears them', () {
      final dive = diveCourseIdsField.write(
        bare.copyWith(courseIds: ['c1']),
        <String>[],
      );
      expect(dive.courseIds, isEmpty);
    });
  });

  group('visibility', () {
    test('reads a measurement, a range and a bucket', () {
      expect(
        diveVisibilityField.read(bare.copyWith(visibilityMeters: 12)),
        const StoredVisibility(meters: 12),
      );
      expect(
        diveVisibilityField.read(
          bare.copyWith(visibilityMinMeters: 10, visibilityMaxMeters: 20),
        ),
        const StoredVisibility(range: range),
      );
      expect(
        diveVisibilityField.read(bare.copyWith(visibility: Visibility.good)),
        const StoredVisibility(legacy: Visibility.good),
      );
      expect(diveVisibilityField.read(bare), StoredVisibility.none);
    });

    test('a stale range beside a measurement reads as measured', () {
      final both = bare.copyWith(
        visibilityMeters: 12,
        visibilityMinMeters: 10,
        visibilityMaxMeters: 20,
      );
      expect(
        diveVisibilityField.read(both),
        const StoredVisibility(meters: 12),
      );
    });

    test('writing a measurement clears the range and the bucket', () {
      final ranged = bare.copyWith(
        visibility: Visibility.good,
        visibilityMinMeters: 10,
        visibilityMaxMeters: 20,
      );

      final dive = diveVisibilityField.write(
        ranged,
        const StoredVisibility(meters: 12),
      );

      expect(dive.visibilityMeters, 12);
      expect(dive.visibilityMinMeters, isNull);
      expect(dive.visibilityMaxMeters, isNull);
      expect(dive.visibility, isNull);
    });

    test('writing a range clears the measurement and the bucket', () {
      final measured = bare.copyWith(
        visibility: Visibility.good,
        visibilityMeters: 12,
      );

      final dive = diveVisibilityField.write(
        measured,
        const StoredVisibility(range: range),
      );

      expect(dive.visibilityMeters, isNull);
      expect(dive.visibilityMinMeters, 10);
      expect(dive.visibilityMaxMeters, 20);
      expect(dive.visibility, isNull);
    });

    test('writing none clears all four columns', () {
      final everything = bare.copyWith(
        visibility: Visibility.good,
        visibilityMeters: 12,
        visibilityMinMeters: 10,
        visibilityMaxMeters: 20,
      );

      final dive = diveVisibilityField.write(everything, StoredVisibility.none);

      expect(dive.visibilityMeters, isNull);
      expect(dive.visibilityMinMeters, isNull);
      expect(dive.visibilityMaxMeters, isNull);
      expect(dive.visibility, isNull);
    });

    test('an untouched dive with a stale range is not a change', () {
      final both = bare.copyWith(
        visibilityMeters: 12,
        visibilityMinMeters: 10,
        visibilityMaxMeters: 20,
      );
      final session = EditSession<Dive>(both);
      addTearDown(session.dispose);

      session.set(diveVisibilityField, StoredVisibility.of(both));

      expect(session.isDirty, isFalse);
      expect(session.working, both);
    });

    test('no measurement goes back to a stored range or bucket', () {
      expect(
        visibilityWithNoMeasurement(const StoredVisibility(range: range)),
        const StoredVisibility(range: range),
      );
      expect(
        visibilityWithNoMeasurement(
          const StoredVisibility(legacy: Visibility.good),
        ),
        const StoredVisibility(legacy: Visibility.good),
      );
    });

    test('no measurement clears a stored measurement', () {
      expect(
        visibilityWithNoMeasurement(const StoredVisibility(meters: 12)),
        StoredVisibility.none,
      );
      expect(
        visibilityWithNoMeasurement(StoredVisibility.none),
        StoredVisibility.none,
      );
    });

    test('a band is its range on the scale; no band is none', () {
      const scale = VisibilityScale.tropical;
      expect(
        visibilityForBand(VisibilityBand.good, scale),
        StoredVisibility(range: scale.rangeFor(VisibilityBand.good)),
      );
      expect(visibilityForBand(null, scale), StoredVisibility.none);
    });
  });

  group('water type', () {
    test('writing one sets it, and null clears it', () {
      final salt = diveWaterTypeField.write(bare, WaterType.salt);
      expect(salt.waterType, WaterType.salt);
      expect(diveWaterTypeField.write(salt, null).waterType, isNull);
    });
  });

  group('the statistics switches', () {
    test('each writes its own flag', () {
      final excluded = diveExcludedFromStatsField.write(bare, true);
      expect(
        (excluded.excludedFromStats, excluded.excludedFromGasStats),
        (true, false),
      );
      final gasOnly = diveExcludedFromGasStatsField.write(bare, true);
      expect(
        (gasOnly.excludedFromStats, gasOnly.excludedFromGasStats),
        (false, true),
      );
    });

    test(
      'the master switch on then off leaves a gas-only choice as it was',
      () {
        final session = EditSession<Dive>(
          bare.copyWith(excludedFromGasStats: true),
        );
        addTearDown(session.dispose);

        session.set(diveExcludedFromStatsField, true);
        expect(session.working.excludedFromGasStats, isTrue);
        session.set(diveExcludedFromStatsField, false);

        expect(session.isDirty, isFalse);
        expect(session.working.excludedFromGasStats, isTrue);
      },
    );
  });

  group('the trip suggestion day', () {
    test('is the entry time\'s own day, read from its components', () {
      final late = bare.copyWith(entryTime: DateTime.utc(2026, 3, 9, 23, 30));
      expect(diveTripSuggestionDay(late), DateTime(2026, 3, 9));
    });

    test('falls back to the dive date with no entry time', () {
      final dive = Dive(id: 'd', dateTime: DateTime.utc(2025, 12, 31, 0, 5));
      expect(diveTripSuggestionDay(dive), DateTime(2025, 12, 31));
    });
  });
}
