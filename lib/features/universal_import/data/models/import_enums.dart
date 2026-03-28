/// File format types that can be detected by the universal import wizard.
enum ImportFormat {
  csv,
  uddf,
  subsurfaceXml,
  divingLogXml,
  suuntoSml,
  suuntoDm5,
  fit,
  shearwaterDb,
  scubapro,
  danDl7,
  sqlite,
  unknown;

  String get displayName => switch (this) {
    csv => 'CSV',
    uddf => 'UDDF',
    subsurfaceXml => 'Subsurface XML',
    divingLogXml => 'Diving Log XML',
    suuntoSml => 'Suunto SML',
    suuntoDm5 => 'Suunto DM5',
    fit => 'Garmin FIT',
    shearwaterDb => 'Shearwater Cloud',
    scubapro => 'Scubapro',
    danDl7 => 'DAN DL7',
    sqlite => 'SQLite Database',
    unknown => 'Unknown',
  };

  /// Whether this format has a parser implemented in v1.5.
  bool get isSupported => switch (this) {
    csv || uddf || subsurfaceXml || fit || shearwaterDb => true,
    _ => false,
  };
}

/// Source applications that export dive data.
enum SourceApp {
  submersion,
  subsurface,
  macdive,
  divingLog,
  diveMate,
  shearwater,
  suunto,
  garminConnect,
  scubapro,
  ssiMyDiveGuide,
  dan,
  generic;

  String get displayName => switch (this) {
    submersion => 'Submersion',
    subsurface => 'Subsurface',
    macdive => 'MacDive',
    divingLog => 'Diving Log',
    diveMate => 'DiveMate',
    shearwater => 'Shearwater',
    suunto => 'Suunto',
    garminConnect => 'Garmin Connect',
    scubapro => 'Scubapro',
    ssiMyDiveGuide => 'SSI MyDiveGuide',
    dan => 'DAN',
    generic => 'Unknown App',
  };

  /// Instructions for exporting from this app in a supported format.
  String? get exportInstructions => switch (this) {
    shearwater => null, // Native .db import supported
    suunto =>
      'In Suunto DM5, select your dives and go to File > Export > UDDF.',
    scubapro =>
      'In Scubapro LogTRAK, select your dives and export as UDDF format.',
    ssiMyDiveGuide =>
      'In the SSI app, go to My Logbook and export your dives as CSV.',
    dan =>
      'DAN DL7 format support is planned for a future update. '
          'Please export your dives in UDDF format if possible.',
    _ => null,
  };
}

/// Resolution choice for a dive that was flagged as a potential duplicate.
///
/// When a dive match is detected during import, the user can choose how to
/// handle it:
/// - [skip]: Do not import this dive at all (default for matched dives).
/// - [importAsNew]: Import the dive as a brand-new separate entry.
/// - [consolidate]: Attach the imported data as a secondary computer reading
///   on the matched existing dive.
enum DiveDuplicateResolution {
  skip,
  importAsNew,
  consolidate;

  String get displayName => switch (this) {
    skip => 'Skip',
    importAsNew => 'Import as New',
    consolidate => 'Consolidate as additional computer',
  };
}

/// Entity types that can be included in an import payload.
///
/// Mirrors the existing `UddfEntityType` but used across all import formats.
enum ImportEntityType {
  dives,
  sites,
  trips,
  equipment,
  equipmentSets,
  buddies,
  diveCenters,
  certifications,
  courses,
  tags,
  diveTypes;

  String get displayName => switch (this) {
    dives => 'Dives',
    sites => 'Sites',
    trips => 'Trips',
    equipment => 'Equipment',
    equipmentSets => 'Equipment Sets',
    buddies => 'Buddies',
    diveCenters => 'Dive Centers',
    certifications => 'Certifications',
    courses => 'Courses',
    tags => 'Tags',
    diveTypes => 'Dive Types',
  };

  String get shortName => switch (this) {
    dives => 'Dives',
    sites => 'Sites',
    trips => 'Trips',
    equipment => 'Equipment',
    equipmentSets => 'Sets',
    buddies => 'Buddies',
    diveCenters => 'Centers',
    certifications => 'Certs',
    courses => 'Courses',
    tags => 'Tags',
    diveTypes => 'Types',
  };
}
