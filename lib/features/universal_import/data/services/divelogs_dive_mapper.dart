import 'package:submersion/core/services/divelogs/divelogs_models.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/universal_import/data/services/import_site_location.dart';

/// Converts divelogs.de API dives into the untyped entity maps consumed by
/// the universal import pipeline (UddfEntityImporter key conventions).
///
/// divelogs.de uses 0 for "not set" on numeric optionals (temps, weights);
/// those are dropped rather than imported as literal zeros.
class DivelogsDiveMapper {
  const DivelogsDiveMapper();

  static String siteKey(String name) =>
      'divelogs-site-${name.trim().toLowerCase()}';

  /// Payload ref key for a remote gear item; must match the `uddfId` used
  /// by the equipment entities so `equipmentIdMapping` links dives to gear.
  static String gearKey(String id) => 'divelogs-gear-$id';

  /// The dive's source id. Namespaced with a dash, never a colon: the
  /// duplicate checker's exact-match pass only reads source ids that
  /// contain one (`DiveRepository._looksLikeSourceUuid`).
  static String sourceUuidFor(String id) => 'divelogs-$id';

  Map<String, dynamic> mapDive(DivelogsDive dive) {
    final map = <String, dynamic>{
      'dateTime': dive.dateTime,
      'runtime': Duration(seconds: dive.durationSeconds),
      'maxDepth': dive.maxDepth,
      if (dive.meanDepth != null && dive.meanDepth! > 0)
        'avgDepth': dive.meanDepth,
      'notes': _buildNotes(dive),
    };

    final waterTemp = _nonZero(dive.depthTemp) ?? _nonZero(dive.surfaceTemp);
    if (waterTemp != null) map['waterTemp'] = waterTemp;
    final airTemp = _nonZero(dive.airTemp);
    if (airTemp != null) map['airTemp'] = airTemp;
    final weight = _positive(dive.weightsKg);
    if (weight != null) map['weightUsed'] = weight;

    if (dive.buddy != null) {
      map['buddy'] = dive.buddy;
      map['buddyRefs'] = [dive.buddy!];
    }
    final fix = ImportSiteLocation.fix(dive.latitude, dive.longitude);
    if (fix != null) {
      map['latitude'] = fix.latitude;
      map['longitude'] = fix.longitude;
    }
    if (dive.dcModel != null) map['diveComputerModel'] = dive.dcModel;
    if (dive.surfaceIntervalSeconds != null &&
        dive.surfaceIntervalSeconds! > 0) {
      map['surfaceInterval'] = Duration(seconds: dive.surfaceIntervalSeconds!);
    }
    if (dive.id != null) map['sourceUuid'] = sourceUuidFor(dive.id!);
    if (dive.gearItemIds.isNotEmpty) {
      map['equipmentRefs'] = [for (final id in dive.gearItemIds) gearKey(id)];
    }

    final site = mapSite(dive);
    if (site != null) {
      map['siteName'] = site['name'];
      map['site'] = <String, dynamic>{
        'uddfId': site['uddfId'],
        'name': site['name'],
      };
    }

    final tanks = dive.tanks
        .map(
          (t) => <String, dynamic>{
            'gasMix': GasMix(o2: t.o2 ?? 21.0, he: t.he ?? 0.0),
            if (t.startPressure != null) 'startPressure': t.startPressure,
            if (t.endPressure != null) 'endPressure': t.endPressure,
            if (t.volume != null && t.volume! > 0)
              'volume': t.volume!.toDouble(),
            if (t.workingPressure != null && t.workingPressure! > 0)
              'workingPressure': t.workingPressure,
            if (t.name != null) 'name': t.name,
          },
        )
        .toList();
    if (tanks.isNotEmpty) map['tanks'] = tanks;

    final rate = dive.sampleRateSeconds;
    if (dive.samples.isNotEmpty && rate != null && rate > 0) {
      map['profile'] = [
        for (var i = 0; i < dive.samples.length; i++)
          <String, dynamic>{
            'timestamp': i * rate,
            'depth': dive.samples[i].depth,
            if (dive.samples[i].temperature != null)
              'temperature': dive.samples[i].temperature,
          },
      ];
    }

    return map;
  }

  /// Site entity map for the payload, or null when the dive names no site
  /// and has no usable coordinates. A site with coordinates but no name is
  /// named from them, per the import site contract.
  Map<String, dynamic>? mapSite(DivelogsDive dive) {
    final fix = ImportSiteLocation.fix(dive.latitude, dive.longitude);
    final named = ImportSiteLocation.named(<String, dynamic>{
      'name': dive.siteName,
      if (fix != null) 'latitude': fix.latitude,
      if (fix != null) 'longitude': fix.longitude,
    });
    if (named == null) return null;
    return <String, dynamic>{
      ...named,
      'uddfId': siteKey(named['name'] as String),
    };
  }

  double? _positive(double? value) =>
      (value != null && value > 0) ? value : null;

  /// Temperatures may be below zero (ice diving, winter air); only 0 is the
  /// "not set" placeholder divelogs.de writes.
  double? _nonZero(double? value) =>
      (value != null && value != 0) ? value : null;

  String _buildNotes(DivelogsDive dive) {
    final parts = <String>[
      if (dive.notes != null) dive.notes!,
      if (dive.weather != null) 'Weather: ${dive.weather}',
      if (dive.visibility != null) 'Visibility: ${dive.visibility}',
      if (dive.boat != null) 'Boat: ${dive.boat}',
      if (dive.location != null) 'Location: ${dive.location}',
    ];
    return parts.join('\n');
  }
}
