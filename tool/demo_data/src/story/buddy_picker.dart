import 'dart:math';

import '../shape/dive_shape.dart';
import 'destinations.dart';
import 'dive_spec.dart';
import 'people.dart';
import 'schedule.dart';
import 'story_plan.dart';

/// The diver's partner, who logs on the same device; always the first
/// regular.
const partner = FictionalPerson(
  id: 'p-mara',
  firstName: 'Mara',
  lastName: 'Lindqvist',
  role: PersonRole.regular,
);

/// Who dives with the demo diver, dive by dive.
///
/// A few home regulars dive most local weekends (weighted by rank, so the
/// first few appear far more than the rest); a small technical team joins
/// the technical dives; each trip brings its guides and a couple of other
/// guests met on the boat; each course has its instructor.
class BuddyPicker {
  BuddyPicker(this.random, this.people) {
    people.reserve(partner.name);
    regulars = [
      partner,
      for (var i = 0; i < 7; i++)
        people.make(PersonRole.regular, nameRegion: homeDestination.nameRegion),
    ];
    techTeam = [
      for (var i = 0; i < 3; i++)
        people.make(
          PersonRole.techTeam,
          nameRegion: homeDestination.nameRegion,
        ),
    ];
  }

  final Random random;
  final PeopleFactory people;
  late final List<FictionalPerson> regulars;
  late final List<FictionalPerson> techTeam;
  final _instructors = <CertLevel, FictionalPerson>{};
  final _guidesAt = <String, List<FictionalPerson>>{};
  final tripPeople =
      <
        String,
        ({
          List<String> guides,
          List<String> guests,
          String? companion,
          String? techMate,
        })
      >{};

  /// Everyone, the partner first.
  List<FictionalPerson> get all => [partner, ...people.all];

  FictionalPerson instructorFor(CertLevel level, Destination where) =>
      _instructors.putIfAbsent(
        level,
        () => people.make(
          PersonRole.instructor,
          nameRegion: where.nameRegion,
          course: level,
        ),
      );

  /// Meets [trip]'s guides and guests, and decides whether a regular came
  /// along.
  void meetTrip(TripDraft trip) {
    final dest = trip.destination;
    if (dest.nearHome) {
      tripPeople[trip.id] = (
        guides: const [],
        guests: const [],
        companion: _regular().id,
        techMate: null,
      );
      return;
    }
    final known = _guidesAt.putIfAbsent(dest.key, () => []);
    final guides = <String>[];
    for (var i = 0; i < (dest.liveaboard ? 2 : 1); i++) {
      final FictionalPerson guide;
      if (known.length > i && random.nextDouble() < 0.6) {
        guide = known[i];
      } else {
        guide = people.make(
          PersonRole.guide,
          nameRegion: dest.nameRegion,
          destinationKey: dest.key,
        );
        known.add(guide);
      }
      guides.add(guide.id);
    }
    // Mostly fellow North Americans, as on a Caribbean dive boat.
    const travellers = ['en', 'en', 'en', 'es', 'fr', 'nl', 'de', 'it'];
    final guests = [
      if (random.nextDouble() < 0.5)
        for (var i = 0; i < 1 + random.nextInt(2); i++)
          people
              .make(
                PersonRole.boatBuddy,
                nameRegion: travellers[random.nextInt(travellers.length)],
                destinationKey: dest.key,
              )
              .id,
    ];
    tripPeople[trip.id] = (
      guides: guides,
      guests: guests,
      companion: random.nextDouble() < 0.6 ? _regular().id : null,
      // A wreck or cold-water trip may take one of the technical team.
      techMate: isTechnicalDestination(dest) && random.nextDouble() < 0.5
          ? techTeam[random.nextInt(techTeam.length)].id
          : null,
    );
  }

  /// The buddies of one dive.
  List<String> forDive(
    Slot slot,
    Set<ShapeKind> kinds,
    StoryPhase phase,
    PlannedCourse? course,
  ) {
    final technical =
        phase != StoryPhase.recreational &&
        !kinds.contains(ShapeKind.recreational);
    final ids = <String>{};
    if (course != null) ids.add(course.instructorId);
    final trip = slot.tripId == null ? null : tripPeople[slot.tripId];
    if (trip == null) {
      if (course?.level == CertLevel.openWater) return ids.toList();
      if (technical) {
        ids.add(techTeam[random.nextInt(techTeam.length)].id);
        if (random.nextDouble() < 0.4) {
          ids.add(techTeam[random.nextInt(techTeam.length)].id);
        }
      } else {
        ids.add(_regular().id);
        if (random.nextDouble() < 0.75) ids.add(_regular().id);
      }
      return ids.toList();
    }
    if (trip.guides.isNotEmpty && random.nextDouble() < 0.5) {
      ids.add(trip.guides[random.nextInt(trip.guides.length)]);
    }
    if (trip.guests.isNotEmpty && random.nextDouble() < 0.35) {
      ids.add(trip.guests[random.nextInt(trip.guests.length)]);
    }
    if (trip.companion != null && random.nextDouble() < 0.9) {
      ids.add(trip.companion!);
    }
    if (technical && trip.techMate != null && random.nextDouble() < 0.8) {
      ids.add(trip.techMate!);
    }
    if (ids.isEmpty) {
      ids.add(
        trip.guides.isNotEmpty
            ? trip.guides.first
            : trip.companion ?? trip.guests.firstOrNull ?? _regular().id,
      );
    }
    return ids.toList();
  }

  /// A regular, the first ones far more often (weight 1 / rank^1.5).
  FictionalPerson _regular() {
    final weights = [
      for (var i = 0; i < regulars.length; i++) 1 / pow(i + 1, 1.5),
    ];
    var r = random.nextDouble() * weights.fold(0.0, (a, b) => a + b);
    for (var i = 0; i < regulars.length; i++) {
      r -= weights[i];
      if (r <= 0) return regulars[i];
    }
    return regulars.last;
  }
}
