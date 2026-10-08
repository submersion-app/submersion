export 'certification_enums.dart';

/// A category of gear a diver owns.
///
/// Persisted by [name] (the `equipment.type` column is text), so the order of
/// the values is free to change and new values need no migration: an older
/// build reading a newer library falls back to [other] rather than failing.
/// The declaration order is not a display order: the type dropdown and the
/// filter chips list types alphabetically by localized label (#2937), via
/// `sortEquipmentTypesByLabel`, and the gear lists use the diver's chosen
/// `EquipmentTypeOrder`.
enum EquipmentType {
  regulator('Regulator'),
  // The regulator's parts (issue #1487). A diver who swaps second stages and
  // hoses between a DIN and a yoke first stage tracks service on each part,
  // so the parts are types of their own rather than `other` with a name.
  firstStage('First Stage'),
  secondStage('Second Stage'),
  hose('Hose'),
  bcd('BCD'),
  // The backplate-and-wing rig's parts (issue #1487): the plate is what a
  // diver swaps between a wetsuit and a drysuit season.
  backplate('Backplate'),
  wing('Wing'),
  harness('Harness'),
  // Rig accessories requested in #1877. Divers had been filing them under
  // BCD, which buried the real BCDs under cam bands and pouches whenever the
  // list was filtered or grouped by type.
  tankBand('Tank Band'),
  weightPocket('Weight Pocket'),
  gearPocket('Gear Pocket'),
  wetsuit('Wetsuit'),
  drysuit('Drysuit'),
  // The two drysuit layers, requested in #1537. They sit next to the suits
  // because that is where a diver looks for them, and they are separate types
  // rather than `other` because their thermal rating is what moves a drysuit
  // diver's lead between a summer and a winter dive.
  undersuit('Undersuit'),
  baselayer('Base Layer'),
  // Requested in #1518 alongside the two above. It is neither of them: a rash
  // guard is worn for sun and abrasion in warm water, so it is rated in UPF
  // rather than in warmth, and a diver owns one for the reason they own a
  // baselayer for the opposite one.
  rashGuard('Rash Guard'),
  fins('Fins'),
  mask('Mask'),
  snorkel('Snorkel'),
  computer('Dive Computer'),
  transmitter('Transmitter'),
  instrument('Instrument / Gauge'),
  compass('Compass'),
  tank('Tank'),
  rebreather('Rebreather'),
  weights('Weights'),
  light('Light'),
  camera('Camera'),
  // Photo rig parts (issue #1487): the same strobes ride different housings.
  // #1997 completed the family, so a camera is assembled from its parts the
  // way a regulator and a BCD are. They run lens to float, roughly from the
  // camera body outwards. A port is its own type because it, not the lens,
  // is what floods and scratches, and it is swapped with the lens behind it.
  lens('Lens'),
  port('Port'),
  housing('Housing'),
  trayHandle('Tray / Handle'),
  armClamp('Arm / Clamp'),
  strobe('Strobe'),
  // A light on the rig rather than in the hand: rated and charged like a
  // dive light, but carried by the camera's arms.
  videoLight('Video Light'),
  floatArm('Float Arm / Float'),
  smb('SMB'),
  reel('Reel'),
  knife('Knife'),
  tool('Tool'),
  hood('Hood'),
  gloves('Gloves'),
  boots('Boots'),
  dpv('DPV'),
  // Requested in #2952. A bag carries gear rather than being worn, so it
  // has no place on the diver figure or in a body order, and adds no mass
  // to a dive: gear bags, rollers, mesh and dry bags alike, told apart by
  // the bag_style attribute rather than by types of their own.
  bag('Bag'),
  // Consumable parts that live inside another item (spec: equipment
  // condition intelligence). Both are children of a parent item and inherit
  // its dives from their install date.
  o2Cell('O2 Cell'),
  battery('Battery'),
  other('Other');

  final String displayName;
  const EquipmentType(this.displayName);
}

/// Visibility conditions.
///
/// Legacy from v144: dives logged before measured visibility store one of
/// these buckets instead of a distance. New dives store
/// `dives.visibility_meters` and derive their adjective from the diver's
/// calibration, so the same distance can read "Good" for a cold-water diver
/// and "Moderate" for a tropical one.
///
/// [bandMinM] and [bandMaxM] record what a bucket actually means, so the UI
/// can show a legacy dive's honest range rather than guessing a point value.
///
/// [displayName] stays English on purpose: it feeds data interchange
/// (CSV/Excel export, the field extractor) where a stable, locale-independent
/// value is wanted. On-screen text goes through the formatters in
/// `dive_log/presentation/formatters/visibility_display.dart`.
enum Visibility {
  excellent('Excellent (>30m / >100ft)', 30, null),
  good('Good (15-30m / 50-100ft)', 15, 30),
  moderate('Moderate (5-15m / 15-50ft)', 5, 15),
  poor('Poor (<5m / <15ft)', null, 5),
  unknown('Unknown', null, null);

  final String displayName;

  /// Inclusive lower bound of the band in meters, or null when unbounded
  /// below.
  final double? bandMinM;

  /// Exclusive upper bound of the band in meters, or null when unbounded
  /// above.
  final double? bandMaxM;

  const Visibility(this.displayName, this.bandMinM, this.bandMaxM);
}

/// Current strength
enum CurrentStrength {
  none('None'),
  light('Light'),
  moderate('Moderate'),
  strong('Strong');

  final String displayName;
  const CurrentStrength(this.displayName);
}

/// Water type
enum WaterType {
  salt('Salt Water'),
  fresh('Fresh Water'),
  brackish('Brackish');

  final String displayName;
  const WaterType(this.displayName);
}

/// Water type for the dive planner. Logged dives still use [WaterType],
/// which includes brackish; the planner offers salt, fresh, or a custom
/// salinity instead.
enum PlannerWaterType { salt, fresh, custom }

/// Marine life categories
enum SpeciesCategory {
  fish('Fish'),
  shark('Shark'),
  ray('Ray'),
  mammal('Mammal'),
  turtle('Turtle'),
  invertebrate('Invertebrate'),
  coral('Coral'),
  plant('Plant/Algae'),
  other('Other');

  final String displayName;
  const SpeciesCategory(this.displayName);
}

/// The category of work a maintenance record represents (what kind of job it
/// was), as distinct from the service type it fulfills, which is the
/// user-extensible ServiceKind catalog. Renamed from ServiceType in v160:
/// the catalog owns the words "service type" in the UI.
enum ServiceCategory {
  annual('Annual Service'),
  repair('Repair'),
  inspection('Inspection'),
  overhaul('Overhaul'),
  replacement('Part Replacement'),
  cleaning('Cleaning'),
  calibration('Calibration'),
  warranty('Warranty Service'),
  recall('Recall/Safety'),
  other('Other');

  final String displayName;
  const ServiceCategory(this.displayName);
}

/// Current direction
enum CurrentDirection {
  north('North'),
  northEast('North-East'),
  east('East'),
  southEast('South-East'),
  south('South'),
  southWest('South-West'),
  west('West'),
  northWest('North-West'),
  variable('Variable'),
  none('None');

  final String displayName;
  const CurrentDirection(this.displayName);
}

/// Entry/exit method for dives
enum EntryMethod {
  shore('Shore Entry'),
  boat('Boat Entry'),
  backRoll('Back Roll'),

  /// Rolling forward off the tube of a RIB (#2927).
  frontRoll('Front Roll'),
  giantStride('Giant Stride'),
  seatedEntry('Seated Entry'),
  ladder('Ladder'),
  platform('Platform'),
  jetty('Jetty/Dock'),
  other('Other');

  final String displayName;
  const EntryMethod(this.displayName);
}

/// Equipment status
///
/// Stored by [name] in a TEXT column, so declaration order only sets the
/// order of the status dropdown and filter chips.
enum EquipmentStatus {
  active('Active'),

  /// Usable gear on the shelf rather than in the dive rotation, such as a
  /// spare hose or O-ring kit (#1803). Still listed, serviced and reminded
  /// like active gear; only the dive gear pickers leave it out.
  spare('Spare'),
  needsService('Needs Service'),
  inService('In Service'),
  retired('Retired'),
  sold('Sold'),
  loaned('Loaned Out'),
  lost('Lost'),

  /// Gear the diver wants to buy (#2025). Not owned yet, so it is stored
  /// with isActive=false like Sold and kept out of every owned-gear surface:
  /// the active list, pickers, sets, service clocks, statistics and totals.
  /// "Mark as purchased" turns it into active gear.
  wanted('Wanted');

  final String displayName;
  const EquipmentStatus(this.displayName);
}

/// Weight type
enum WeightType {
  belt('Weight Belt'),
  integrated('Integrated Weights'),
  ankleWeights('Ankle Weights'),
  trimWeights('Trim Weights'),
  backplate('Backplate Weights'),
  mixed('Mixed/Combined');

  final String displayName;
  const WeightType(this.displayName);
}

/// Post-dive weighting feedback: was the carried weight right? (v104)
///
/// Turns raw weight history into corrected training data for the weight
/// prediction engine.
enum WeightingFeedback {
  correct('Felt right'),
  overweighted('Overweighted'),
  underweighted('Underweighted');

  final String displayName;
  const WeightingFeedback(this.displayName);
}

/// Tank role/purpose during a dive
enum TankRole {
  backGas('Back Gas'),
  stage('Stage'),
  deco('Deco'),
  bailout('Bailout'),
  sidemountLeft('Sidemount Left'),
  sidemountRight('Sidemount Right'),
  pony('Pony Bottle'),
  diluent('Diluent'), // CCR diluent tank
  oxygenSupply('O₂ Supply'); // CCR oxygen supply cylinder

  final String displayName;
  const TankRole(this.displayName);
}

/// Where a cylinder's [TankRole] came from when no person chose it (issue
/// #2595). Stored by name in `dive_tanks.role_source`; null means the diver
/// or the transmitter registry set the role, or nothing more is known.
enum TankRoleSource {
  /// The dive computer derived the role from the name the diver gave the
  /// transmitter: in its CCR modes a Shearwater reads a name starting with
  /// "O" as the oxygen supply and one starting with "D" as the diluent. The
  /// name is free text nothing checks, so a bailout named "OC" becomes the
  /// oxygen supply. Unconfirmed until the diver registers the transmitter or
  /// sets the role.
  transmitterName;

  /// The source stored as [name], or null for null or an unknown value
  /// (a newer peer's source this build does not know is treated as none).
  static TankRoleSource? fromName(String? name) {
    for (final source in values) {
      if (source.name == name) return source;
    }
    return null;
  }
}

/// Tank construction material
enum TankMaterial {
  aluminum('Aluminum'),
  steel('Steel'),
  carbonFiber('Carbon Fiber');

  final String displayName;
  const TankMaterial(this.displayName);
}

/// Dive mode (open circuit, closed circuit rebreather, semi-closed)
enum DiveMode {
  oc('Open Circuit'),
  ccr('Closed Circuit Rebreather'),
  scr('Semi-Closed Rebreather'),
  gauge('Gauge');

  final String displayName;
  const DiveMode(this.displayName);

  /// Short code for database storage
  String get code => name;

  /// Parse from database value
  static DiveMode fromCode(String code) {
    return DiveMode.values.firstWhere(
      (e) => e.code == code,
      orElse: () => DiveMode.oc,
    );
  }
}

/// Semi-Closed Rebreather type
enum ScrType {
  cmf('Constant Mass Flow', 'CMF'),
  pascr('Passive Addition', 'PASCR'),
  escr('Electronically Controlled', 'ESCR');

  final String displayName;
  final String shortName;
  const ScrType(this.displayName, this.shortName);

  /// Short code for database storage
  String get code => name;

  /// Parse from database value
  static ScrType? fromCode(String? code) {
    if (code == null) return null;
    return ScrType.values.firstWhere(
      (e) => e.code == code,
      orElse: () => ScrType.cmf,
    );
  }
}

/// Profile event types (markers on dive profile)
enum ProfileEventType {
  ascentStart('Ascent Start', 'info'),
  safetyStopStart('Safety Stop Start', 'info'),
  safetyStopEnd('Safety Stop End', 'info'),
  decoStopStart('Deco Stop Start', 'info'),
  decoStopEnd('Deco Stop End', 'info'),
  gasSwitch('Gas Switch', 'info'),
  maxDepth('Max Depth', 'info'),
  ascentRateWarning('Ascent Rate Warning', 'warning'),
  ascentRateCritical('Ascent Rate Critical', 'alert'),
  decoViolation('Deco Violation', 'alert'),
  missedStop('Missed Deco Stop', 'alert'),
  lowGas('Low Gas Warning', 'warning'),
  cnsWarning('CNS Warning', 'warning'),
  cnsCritical('CNS Critical', 'alert'),
  ppO2High('High ppO2', 'warning'),
  ppO2Low('Low ppO2', 'warning'),
  // The computer's own "no-deco time is running low" and "this dive now
  // needs deco" notices (Suunto Warning NoDecoTime / State Ndl exceeded).
  lowNoDecoTime('Low No-Deco Time', 'warning'),
  decompressionDive('Decompression Dive', 'info'),
  setpointChange('Setpoint Change', 'info'),
  bookmark('Bookmark', 'info'),
  alert('Alert', 'alert'),
  note('Note', 'info');

  final String displayName;
  final String defaultSeverity; // 'info', 'warning', 'alert'

  const ProfileEventType(this.displayName, this.defaultSeverity);

  /// Get icon for this event type
  String get iconName {
    switch (this) {
      case ProfileEventType.ascentStart:
        return 'arrow_upward';
      case ProfileEventType.safetyStopStart:
      case ProfileEventType.safetyStopEnd:
        return 'pause_circle';
      case ProfileEventType.decoStopStart:
      case ProfileEventType.decoStopEnd:
      case ProfileEventType.decompressionDive:
        return 'stop_circle';
      case ProfileEventType.gasSwitch:
        return 'swap_horiz';
      case ProfileEventType.maxDepth:
        return 'vertical_align_bottom';
      case ProfileEventType.ascentRateWarning:
      case ProfileEventType.ascentRateCritical:
        return 'speed';
      case ProfileEventType.decoViolation:
      case ProfileEventType.missedStop:
        return 'dangerous';
      case ProfileEventType.lowGas:
        return 'diving_scuba_tank';
      case ProfileEventType.cnsWarning:
      case ProfileEventType.cnsCritical:
        return 'air';
      case ProfileEventType.ppO2High:
      case ProfileEventType.ppO2Low:
        return 'warning';
      case ProfileEventType.lowNoDecoTime:
        return 'timer';
      case ProfileEventType.setpointChange:
        return 'tune';
      case ProfileEventType.bookmark:
        return 'bookmark';
      case ProfileEventType.alert:
        return 'notification_important';
      case ProfileEventType.note:
        return 'note';
    }
  }
}

/// Event severity levels.
///
/// Declaration order matters: [index] is used for severity comparison
/// (higher index = more severe). Do not reorder without checking usages.
enum EventSeverity {
  info('Info'),
  warning('Warning'),
  alert('Alert');

  final String displayName;
  const EventSeverity(this.displayName);
}

/// Ascent rate category for coloring
enum AscentRateCategory {
  safe('Safe', 'green'),
  warning('Warning', 'yellow'),
  danger('Danger', 'red');

  final String displayName;
  final String colorName;
  const AscentRateCategory(this.displayName, this.colorName);

  /// Get category from ascent rate in m/min
  static AscentRateCategory fromRate(double rateMetersPerMin) {
    final absRate = rateMetersPerMin.abs();
    if (absRate <= 9.0) return AscentRateCategory.safe;
    if (absRate <= 12.0) return AscentRateCategory.warning;
    return AscentRateCategory.danger;
  }
}

/// Trip type classification
enum TripType {
  shore('Shore'),
  liveaboard('Liveaboard'),
  resort('Resort'),
  dayTrip('Day Trip');

  final String displayName;
  const TripType(this.displayName);

  static TripType fromName(String name) {
    return TripType.values.firstWhere(
      (e) => e.name == name,
      orElse: () => TripType.shore,
    );
  }
}

/// Itinerary day type for liveaboard trips
enum DayType {
  diveDay('Dive Day'),
  seaDay('Sea Day'),
  portDay('Port Day'),
  embark('Embark'),
  disembark('Disembark'),

  /// A land trip's first and last day: getting there and back (#2845).
  travel('Travel'),

  /// A day planned at no dives (#2658).
  rest('Rest');

  final String displayName;
  const DayType(this.displayName);

  static DayType fromName(String name) {
    return DayType.values.firstWhere(
      (e) => e.name == name,
      orElse: () => DayType.diveDay,
    );
  }
}

/// Cloud cover conditions
enum CloudCover {
  clear('Clear'),
  partlyCloudy('Partly Cloudy'),
  mostlyCloudy('Mostly Cloudy'),
  overcast('Overcast');

  final String displayName;
  const CloudCover(this.displayName);
}

/// Precipitation type
enum Precipitation {
  none('None'),
  drizzle('Drizzle'),
  lightRain('Light Rain'),
  rain('Rain'),
  heavyRain('Heavy Rain'),
  snow('Snow'),
  sleet('Sleet'),
  hail('Hail');

  final String displayName;
  const Precipitation(this.displayName);
}

/// Source of weather data
enum WeatherSource {
  manual('Manual'),
  openMeteo('Open-Meteo');

  final String displayName;
  const WeatherSource(this.displayName);
}

/// Provenance of a [ProfileEvent]. Used for source-aware merge rules and
/// diagnostic display.
///
/// Members are ordered so that the default (`imported`) comes first. This
/// matters because the Drift `source` column has a DB-level default of
/// `'imported'`, and `EventSource.values.first.name` would produce the
/// default-equivalent if any future code uses it.
enum EventSource {
  /// Came from outside the app: file import (SSRF, UDDF) or native DC download.
  imported,

  /// Auto-detected by in-app analysis (ascent rate, CNS, ppO2 thresholds, etc.).
  computed,

  /// User-authored in the app (bookmarks, notes).
  user,
}
