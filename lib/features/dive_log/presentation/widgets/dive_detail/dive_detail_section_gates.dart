import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/text/blank_text.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/active_source_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/buoyancy_twin_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/utils/sac_segments_availability.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_analysis_retention.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart'
    show GeoPoint;
import 'package:submersion/features/reef/domain/entities/reef_health.dart';
import 'package:submersion/features/reef/presentation/providers/reef_providers.dart';
import 'package:submersion/features/reef/presentation/widgets/water_conditions_lines.dart';
import 'package:submersion/features/tides/presentation/providers/tide_providers.dart';

// What the section list needs to know to lay the page out: whether a section
// has anything to show, which is what decides if it takes a slot and if a pair
// can form. Each read is narrowed to that answer, so the list rebuilds when a
// section appears or goes, not whenever the data behind one changes.

/// Whether the location card has anything to map: a surface GPS fix, or
/// failing that the dive site's coordinates (issue #402).
bool diveHasLocationMap(Dive dive) =>
    dive.entryLocation != null ||
    dive.exitLocation != null ||
    dive.site?.location != null;

bool diveHasWeights(Dive dive) {
  return dive.weights.isNotEmpty ||
      (dive.weightAmount != null && dive.weightAmount! > 0);
}

bool diveHasExposureSuit(Dive dive) => dive.equipment.any(
  (e) => e.type == EquipmentType.wetsuit || e.type == EquipmentType.drysuit,
);

/// Whether the buoyancy model has anything to work from: a tank, or a suit to
/// account for.
bool diveHasBuoyancyInputs(Dive dive) =>
    dive.tanks.isNotEmpty || diveHasExposureSuit(dive);

/// Whether the Environment card has anything to show: a logged weather or
/// dive-conditions field, or satellite water conditions for the dive date.
bool watchHasEnvironmentData(WidgetRef ref, Dive dive) {
  return _hasLoggedEnvironmentData(dive) ||
      watchSatelliteWaterConditions(ref, dive) != null;
}

bool _hasLoggedEnvironmentData(Dive dive) {
  return trimmedOrNull(dive.surfaceConditions) != null ||
      dive.airTemp != null ||
      dive.surfacePressure != null ||
      dive.windSpeed != null ||
      dive.windDirection != null ||
      dive.cloudCover != null ||
      dive.precipitation != null ||
      dive.humidity != null ||
      dive.weatherDescription != null ||
      dive.currentDirection != null ||
      dive.currentStrength != null ||
      dive.swellHeight != null ||
      dive.effectiveEntryMethod != null ||
      dive.exitMethod != null;
}

/// Satellite water conditions on the date of this dive, or null when there
/// are none to show.
///
/// Historical NOAA readings are immutable, so the lookup is fetched once and
/// cached permanently. Null without site coordinates, and for freshwater
/// dives, whose water NOAA's ocean grid cannot see; the dive's own water
/// type wins over its site's, as everywhere else. Null too while the
/// lookup loads, fails, comes back empty or has no reading to show: a line
/// saying so would be noise in a card about the dive's conditions, and
/// would be the only line in an Environment card for a dive with nothing
/// logged.
///
/// [reefPossible] is false only once habitat has ruled a reef out; while it
/// resolves the coral lines stay, the conservative default.
({ReefHealth health, bool reefPossible})? watchSatelliteWaterConditions(
  WidgetRef ref,
  Dive dive,
) {
  final site = dive.site;
  if (site == null || !site.hasCoordinates) return null;
  if (dive.effectiveWaterType == WaterType.fresh) return null;
  final health = ref.watch(
    reefHealthForDiveProvider(
      ReefHealthRequest(
        location: site.location!,
        date: dive.effectiveEntryTime,
      ),
    ).select((a) {
      final part = a.valueOrNull;
      return part != null && part.hasValue ? part.value : null;
    }),
  );
  if (health == null) return null;
  final reefPossible = ref.watch(
    reefHabitatProvider(
      site.location!,
    ).select((a) => reefPossibleFor(a.valueOrNull)),
  );
  if (!hasWaterConditionsReadings(health, reefPossible: reefPossible)) {
    return null;
  }
  return (health: health, reefPossible: reefPossible);
}

/// What the tide providers are asked for [dive], or null when it can have no
/// tides to show.
///
/// Freshwater dives have no tides, even when an old stored record exists; the
/// dive's own water type wins over its site's, as everywhere else
/// (Dive.effectiveWaterType). Tide times are shown in the dive site's own
/// clock, so a site without coordinates has none to show them in.
({String diveId, GeoPoint location, DateTime entryTime})? diveTideRequest(
  Dive dive,
) {
  if (dive.effectiveWaterType == WaterType.fresh) return null;
  final location = dive.site?.location;
  if (location == null) return null;
  return (
    diveId: dive.id,
    location: location,
    entryTime: dive.effectiveEntryTime,
  );
}

/// Whether the dive has tide data to show, stored or modelled.
///
/// Mirrors what `DiveTideSection` renders, read down to that one answer: a
/// stored record, else the model's result; nothing while either is loading or
/// failed.
bool watchHasTide(WidgetRef ref, Dive dive) {
  final request = diveTideRequest(dive);
  if (request == null) return false;
  // Null while it loads or if it failed; otherwise whether a record is stored.
  final hasStoredRecord = ref.watch(
    healedTideRecordProvider(
      request,
    ).select((a) => a.whenOrNull(data: (record) => record != null)),
  );
  if (hasStoredRecord == null) return false;
  if (hasStoredRecord) return true;
  return ref.watch(
    calculatedTideRecordProvider(request).select((a) => a.value != null),
  );
}

/// Whether the Gas consumption by segment card has segments, or the note
/// explaining their absence (#2505), to show.
///
/// Mirrors the card's own gate, including its last-good fallback, so a
/// transient null analysis cannot split the pair while the card stays.
/// The read is narrowed to that answer, so the list rebuilds only when it
/// flips. It goes through the built-in [AsyncValue.value], which keeps the
/// previous analysis while a reload is in flight; the valueOrNull polyfill
/// reads null there, which would rebuild the list into the same
/// layout on every reload.
bool watchHasSacSegments(
  WidgetRef ref,
  Dive dive,
  DiveDetailAnalysisRetention retention,
) {
  if (dive.profile.isEmpty) return false;
  final computerId = ref.watch(
    activeSourceProfileProvider(dive.id).select((p) => p?.computerId),
  );
  final key = (
    diveId: dive.id,
    sourceId: ref.watch(activeDiveSourceProvider(dive.id)),
  );
  final hasSegments = ref.watch(
    sourceProfileAnalysisProvider(key).select(
      (a) =>
          (a.value?.sacSegments?.isNotEmpty ?? false) ||
          sacSegmentsLackRecordedPressure(
            a.value,
            dive,
            computerId: computerId,
          ),
    ),
  );
  return hasSegments || retention.sacSegmentsFor(key) != null;
}

/// Whether the Buoyancy card has a modelled result to show.
///
/// `BuoyancySection` renders nothing until it has an outcome, or for an
/// unmodelable dive, and keeps its last outcome through a reload; this reads
/// the provider the same way, narrowed to that answer.
bool watchHasBuoyancy(WidgetRef ref, Dive dive) {
  if (!diveHasBuoyancyInputs(dive)) return false;
  return ref.watch(
    buoyancyTwinProvider(dive.id).select((a) => a.value != null),
  );
}
