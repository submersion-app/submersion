/// Types of dives
enum DiveType {
  recreational('Recreational'),
  technical('Technical'),
  freedive('Freedive'),
  training('Training'),
  wreck('Wreck'),
  cave('Cave'),
  ice('Ice'),
  night('Night'),
  drift('Drift'),
  deep('Deep'),
  altitude('Altitude'),
  shore('Shore'),
  boat('Boat'),
  liveaboard('Liveaboard');

  final String displayName;
  const DiveType(this.displayName);
}

/// Types of diving equipment
enum EquipmentType {
  regulator('Regulator'),
  bcd('BCD'),
  wetsuit('Wetsuit'),
  drysuit('Drysuit'),
  fins('Fins'),
  mask('Mask'),
  computer('Dive Computer'),
  tank('Tank'),
  weights('Weights'),
  light('Light'),
  camera('Camera'),
  smb('SMB'),
  reel('Reel'),
  knife('Knife'),
  hood('Hood'),
  gloves('Gloves'),
  boots('Boots'),
  other('Other');

  final String displayName;
  const EquipmentType(this.displayName);
}

/// Visibility conditions
enum Visibility {
  excellent('Excellent (>30m / >100ft)'),
  good('Good (15-30m / 50-100ft)'),
  moderate('Moderate (5-15m / 15-50ft)'),
  poor('Poor (<5m / <15ft)'),
  unknown('Unknown');

  final String displayName;
  const Visibility(this.displayName);
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

/// Buddy role on a dive
enum BuddyRole {
  buddy('Buddy'),
  diveGuide('Dive Guide'),
  instructor('Instructor'),
  student('Student'),
  diveMaster('Divemaster'),
  solo('Solo');

  final String displayName;
  const BuddyRole(this.displayName);
}

/// Certification agencies
enum CertificationAgency {
  padi('PADI'),
  ssi('SSI'),
  naui('NAUI'),
  sdi('SDI'),
  tdi('TDI'),
  gue('GUE'),
  raid('RAID'),
  bsac('BSAC'),
  cmas('CMAS'),
  iantd('IANTD'),
  psai('PSAI'),
  other('Other');

  final String displayName;
  const CertificationAgency(this.displayName);
}

/// Common certification levels
enum CertificationLevel {
  openWater('Open Water'),
  advancedOpenWater('Advanced Open Water'),
  rescue('Rescue Diver'),
  diveMaster('Divemaster'),
  instructor('Instructor'),
  masterInstructor('Master Instructor'),
  courseDirector('Course Director'),
  nitrox('Nitrox'),
  advancedNitrox('Advanced Nitrox'),
  decompression('Decompression'),
  trimix('Trimix'),
  cavern('Cavern'),
  cave('Cave'),
  wreck('Wreck'),
  sidemount('Sidemount'),
  rebreather('Rebreather'),
  techDiver('Tech Diver'),
  other('Other');

  final String displayName;
  const CertificationLevel(this.displayName);
}

/// Service type for equipment maintenance
enum ServiceType {
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
  const ServiceType(this.displayName);
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
enum EquipmentStatus {
  active('Active'),
  needsService('Needs Service'),
  inService('In Service'),
  retired('Retired'),
  loaned('Loaned Out'),
  lost('Lost');

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

/// Tank role/purpose during a dive
enum TankRole {
  backGas('Back Gas'),
  stage('Stage'),
  deco('Deco'),
  bailout('Bailout'),
  sidemountLeft('Sidemount Left'),
  sidemountRight('Sidemount Right'),
  pony('Pony Bottle');

  final String displayName;
  const TankRole(this.displayName);
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
  scr('Semi-Closed Rebreather');

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

/// Profile event types (markers on dive profile)
enum ProfileEventType {
  descentStart('Descent Start', 'info'),
  descentEnd('Descent End', 'info'),
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
      case ProfileEventType.descentStart:
      case ProfileEventType.descentEnd:
        return 'arrow_downward';
      case ProfileEventType.ascentStart:
        return 'arrow_upward';
      case ProfileEventType.safetyStopStart:
      case ProfileEventType.safetyStopEnd:
        return 'pause_circle';
      case ProfileEventType.decoStopStart:
      case ProfileEventType.decoStopEnd:
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
        return 'propane_tank';
      case ProfileEventType.cnsWarning:
      case ProfileEventType.cnsCritical:
        return 'air';
      case ProfileEventType.ppO2High:
      case ProfileEventType.ppO2Low:
        return 'warning';
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

/// Event severity levels
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