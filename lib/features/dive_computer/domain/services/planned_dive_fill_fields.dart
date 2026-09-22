/// Dive fields the dive computer overwrites when a download fills a planned
/// dive (issue #2002): what the computer measured or recorded, plus the
/// lifecycle fields the fill itself sets. Listed so the census over the Dive
/// constructor stays exhaustive: every field is either measured or human.
const Set<String> kMeasuredDiveFields = {
  // lifecycle, set by the fill
  'isPlanned', 'diveNumber', 'computerId',
  // when the computer says the dive ran
  'entryTime', 'exitTime', 'bottomTime', 'runtime', 'surfaceInterval',
  // depths and temperature
  'maxDepth', 'avgDepth', 'waterTemp',
  // the record itself
  'profile', 'tanks',
  // deco and exposure the computer reports
  'gradientFactorLow', 'gradientFactorHigh', 'decoAlgorithm',
  'decoConservatism',
  'diveComputerModel', 'diveComputerSerial', 'diveComputerFirmware',
  // breathing configuration the computer reports
  'diveMode', 'setpointLow', 'setpointHigh', 'setpointDeco', 'scrType',
  'scrInjectionRate', 'scrAdditionRatio', 'scrOrificeSize', 'assumedVo2',
  'diluentGas', 'loopO2Min', 'loopO2Max', 'loopO2Avg', 'loopVolume',
  'scrubber',
  // GPS the computer captured
  'entryLocation', 'exitLocation',
};

/// Dive fields the planned dive keeps: what the diver typed ahead of time,
/// their references, opinions and provenance. `dateTime` stays as planned;
/// the computer's start goes to `entryTime`.
const Set<String> kHumanDiveFields = {
  'id',
  'diverId',
  'outingId',
  'diverRoleId',
  'name',
  'dateTime',
  'site',
  'trip',
  'tripId',
  'diveCenter',
  'gear',
  'notes',
  'photoIds',
  'sightings',
  'buddy',
  'diveMaster',
  'buddies',
  'rating',
  'isFavorite',
  'excludedFromStats',
  'excludedFromGasStats',
  'airTemp',
  'visibility',
  'visibilityMeters',
  'currentDirection',
  'currentStrength',
  'swellHeight',
  'entryMethod',
  'exitMethod',
  'waterType',
  'altitude',
  'surfacePressure',
  'diveTypeIds',
  'diveType',
  'tags',
  'weightAmount',
  'weightType',
  'weights',
  'weightingFeedback',
  'weightingFeedbackKg',
  'courseId',
  'importSource',
  'importId',
  'customFields',
  'windSpeed',
  'windDirection',
  'cloudCover',
  'precipitation',
  'humidity',
  'weatherDescription',
  'weatherCode',
  'weatherSource',
  'weatherFetchedAt',
};
