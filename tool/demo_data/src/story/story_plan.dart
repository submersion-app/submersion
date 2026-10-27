import '../shape/dive_shape.dart';
import 'catalog.dart';

enum StoryPhase { recreational, technicalOc, rebreather }

/// The certifications of the demo diver's progression, in order.
enum CertLevel {
  openWater('Open Water Diver'),
  advanced('Advanced Open Water Diver'),
  nitrox('Enriched Air Nitrox Diver'),
  rescue('Rescue Diver'),
  deep('Deep Diver'),
  decoProcedures('Advanced Nitrox and Decompression Procedures'),
  trimix('Normoxic Trimix Diver'),
  ccr('CCR Diver');

  const CertLevel(this.title);

  final String title;
}

/// Where the diver dives: home waters or a trip destination.
class Destination {
  const Destination({
    required this.key,
    required this.label,
    required this.country,
    required this.region,
    required this.waterTempC,
    required this.freshwater,
    required this.nameRegion,
    this.liveaboard = false,
    this.area,
    this.minPhase = StoryPhase.recreational,
    this.nearHome = false,
    this.scooterOk = true,
    this.boatNames = const [],
    this.resortNames = const [],
  });

  final String key;
  final String label;
  final String country;

  /// The catalogue's region, or null to take sites from any region of
  /// [country] (narrowed by [area]).
  final String? region;

  /// A circle the sites must lie in, for a country or region that holds
  /// more than this one place.
  final ({double lat, double lon, double km})? area;

  /// The first phase of the story that travels here (wreck trips wait for
  /// technical training).
  final StoryPhase minPhase;

  /// Close enough to home for a weekend trip.
  final bool nearHome;

  /// False where a scooter run would be cave diving, which the diver is not
  /// trained for.
  final bool scooterOk;

  /// Which name pool the people met here are drawn from.
  final String nameRegion;

  /// Fictional liveaboards and resorts the trips here stay on.
  final List<String> boatNames;
  final List<String> resortNames;

  /// (min, max) bottom temperature over the year.
  final (double, double) waterTempC;
  final bool freshwater;
  final bool liveaboard;
}

class FictionalPerson {
  const FictionalPerson({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.role,
  });

  final String id;
  final String firstName;
  final String lastName;

  /// buddy, instructor or guide.
  final String role;

  String get name => '$firstName $lastName';
}

class PlannedCert {
  const PlannedCert({
    required this.id,
    required this.level,
    required this.issueDate,
    this.courseId,
    this.instructorId,
  });

  final String id;
  final CertLevel level;
  final DateTime issueDate;
  final String? courseId;
  final String? instructorId;
}

class PlannedCourse {
  const PlannedCourse({
    required this.id,
    required this.level,
    required this.start,
    required this.end,
    required this.instructorId,
  });

  final String id;
  final CertLevel level;
  final DateTime start;
  final DateTime end;
  final String instructorId;

  String get name => '${level.title} course';
}

class PlannedTrip {
  const PlannedTrip({
    required this.id,
    required this.destination,
    required this.start,
    required this.end,
    required this.siteIds,
    this.centerId,
  });

  final String id;
  final Destination destination;
  final DateTime start;
  final DateTime end;
  final List<String> siteIds;
  final String? centerId;

  String get name => '${destination.label} ${start.year}';
}

class PlannedDive {
  const PlannedDive({
    required this.number,
    required this.start,
    required this.phase,
    required this.wantedKinds,
    required this.siteId,
    required this.destination,
    required this.targetMaxDepth,
    required this.diveMode,
    required this.tankCount,
    required this.buddyIds,
    required this.plannedDuration,
    this.tripId,
    this.courseId,
    this.requiresCert,
    this.night = false,
  });

  final int number;
  final DateTime start;
  final StoryPhase phase;
  final Set<ShapeKind> wantedKinds;
  final String siteId;
  final Destination destination;
  final double targetMaxDepth;

  /// oc or ccr.
  final String diveMode;
  final int tankCount;
  final List<String> buddyIds;

  /// An upper bound on how long the dive lasts, for spacing dives.
  final Duration plannedDuration;
  final String? tripId;
  final String? courseId;
  final CertLevel? requiresCert;
  final bool night;
}

class StoryPlan {
  const StoryPlan({
    required this.anchor,
    required this.dives,
    required this.trips,
    required this.certs,
    required this.courses,
    required this.sites,
    required this.centers,
    required this.people,
    required this.home,
  });

  final DateTime anchor;
  final List<PlannedDive> dives;
  final List<PlannedTrip> trips;
  final List<PlannedCert> certs;
  final List<PlannedCourse> courses;

  /// The catalogue sites and centres the story uses.
  final List<CatalogSite> sites;
  final List<CatalogCenter> centers;
  final List<FictionalPerson> people;
  final Destination home;
}
