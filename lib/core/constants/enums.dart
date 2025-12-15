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