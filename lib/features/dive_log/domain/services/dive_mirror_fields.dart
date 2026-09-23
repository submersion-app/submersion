import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

/// Dive fields copied onto a sibling created by the mirror flow (issue
/// #2002): the facts two divers on the same dive share. Identity, ownership
/// and references are set by the service rather than copied verbatim, but
/// they are listed here so the census over the Dive constructor stays
/// exhaustive: every field is either mirrored or deliberately not.
const Set<String> kMirroredDiveFields = {
  // identity and ownership (set by the service)
  'id', 'diverId', 'outingId', 'isPlanned', 'diverRoleId',
  // when
  'dateTime', 'entryTime', 'exitTime',
  // where (resolved per profile by the service)
  'site', 'trip', 'tripId', 'diveCenter', 'entryLocation', 'exitLocation',
  'altitude', 'surfacePressure', 'waterType',
  // conditions
  'waterTemp', 'airTemp', 'visibility', 'visibilityMeters',
  'currentDirection', 'currentStrength', 'swellHeight',
  'entryMethod', 'exitMethod',
  // weather
  'windSpeed', 'windDirection', 'cloudCover', 'precipitation', 'humidity',
  'weatherDescription', 'weatherCode', 'weatherSource', 'weatherFetchedAt',
  // what kind of dive (resolved per profile by the service)
  'diveTypeIds', 'diveType', 'tags',
};

/// Dive fields that stay with the source: the diver's own measurements,
/// gear, breathing configuration, opinions, people (rebuilt by the service
/// from the buddy group) and provenance.
const Set<String> kUnmirroredDiveFields = {
  'diveNumber',
  'name',
  'bottomTime',
  'runtime',
  'maxDepth',
  'avgDepth',
  'tanks',
  'profile',
  'gear',
  'notes',
  'photoIds',
  'sightings',
  'buddy',
  'diveMaster',
  'buddies',
  'rating',
  'surfaceInterval',
  'gradientFactorLow',
  'gradientFactorHigh',
  'decoAlgorithm',
  'decoConservatism',
  'diveComputerModel',
  'diveComputerSerial',
  'diveComputerFirmware',
  'computerId',
  'weightAmount',
  'weightType',
  'weights',
  'weightingFeedback',
  'weightingFeedbackKg',
  'isFavorite',
  'excludedFromStats',
  'excludedFromGasStats',
  'diveMode',
  'setpointLow',
  'setpointHigh',
  'setpointDeco',
  'scrType',
  'scrInjectionRate',
  'scrAdditionRatio',
  'scrOrificeSize',
  'assumedVo2',
  'diluentGas',
  'loopO2Min',
  'loopO2Max',
  'loopO2Avg',
  'loopVolume',
  'scrubber',
  'courseId',
  'importSource',
  'importId',
  'customFields',
};

/// The sibling dive for [targetDiverId], with references already resolved
/// for that profile by the caller. The site and center entities come from
/// the source (only their ids are written); [tripId] is null when the trip
/// is not shared.
Dive mirroredDiveFrom(
  Dive source, {
  required String targetDiverId,
  required String outingId,
  required bool includeSite,
  required String? tripId,
  required bool includeDiveCenter,
  required List<String> diveTypeIds,
  required List<Tag> tags,
  required String? diverRoleId,
}) {
  return Dive(
    id: '',
    diverId: targetDiverId,
    outingId: outingId,
    isPlanned: true,
    diverRoleId: diverRoleId,
    dateTime: source.dateTime,
    entryTime: source.entryTime,
    exitTime: source.exitTime,
    site: includeSite ? source.site : null,
    tripId: tripId,
    diveCenter: includeDiveCenter ? source.diveCenter : null,
    entryLocation: source.entryLocation,
    exitLocation: source.exitLocation,
    altitude: source.altitude,
    surfacePressure: source.surfacePressure,
    waterType: source.waterType,
    waterTemp: source.waterTemp,
    airTemp: source.airTemp,
    visibility: source.visibility,
    visibilityMeters: source.visibilityMeters,
    currentDirection: source.currentDirection,
    currentStrength: source.currentStrength,
    swellHeight: source.swellHeight,
    entryMethod: source.entryMethod,
    exitMethod: source.exitMethod,
    windSpeed: source.windSpeed,
    windDirection: source.windDirection,
    cloudCover: source.cloudCover,
    precipitation: source.precipitation,
    humidity: source.humidity,
    weatherDescription: source.weatherDescription,
    weatherCode: source.weatherCode,
    weatherSource: source.weatherSource,
    weatherFetchedAt: source.weatherFetchedAt,
    diveTypeIds: diveTypeIds,
    tags: tags,
  );
}
