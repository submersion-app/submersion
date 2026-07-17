import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Projects a domain Dive onto the divelogs.de dive JSON schema.
///
/// Lossy by design (spec: push path): one profile channel, tanks, site
/// name + GPS, buddy string, notes, temps, weights. Returns null when the
/// API's mandatory fields (date/time/duration/maxdepth) cannot be
/// produced; the caller reports such dives as skipped.
class DivelogsExportMapper {
  const DivelogsExportMapper();

  Map<String, dynamic>? mapDive(Dive dive) {
    final entry = dive.effectiveEntryTime;
    final durationSeconds = dive.effectiveRuntime?.inSeconds;
    final maxDepth = dive.maxDepth ?? dive.calculateMaxDepthFromProfile();
    if (durationSeconds == null || durationSeconds <= 0 || maxDepth == null) {
      return null;
    }

    String two(int v) => v.toString().padLeft(2, '0');
    final json = <String, dynamic>{
      'date': '${entry.year}-${two(entry.month)}-${two(entry.day)}',
      'time': '${two(entry.hour)}:${two(entry.minute)}:${two(entry.second)}',
      'duration': durationSeconds,
      'maxdepth': maxDepth,
    };

    final avg = dive.avgDepth;
    if (avg != null && avg > 0) json['meandepth'] = avg;
    if (dive.buddy != null) json['buddy'] = dive.buddy;
    final siteName = dive.site?.name;
    if (siteName != null && siteName.isNotEmpty) json['divesite'] = siteName;
    final location = dive.site?.location ?? dive.entryLocation;
    if (location != null) {
      json['lat'] = location.latitude;
      json['lng'] = location.longitude;
    }
    final locality = [
      dive.site?.country,
      dive.site?.region,
    ].whereType<String>().where((s) => s.isNotEmpty).join(', ');
    if (locality.isNotEmpty) json['location'] = locality;
    if (dive.notes.isNotEmpty) json['notes'] = dive.notes;
    if (dive.airTemp != null) json['airtemp'] = dive.airTemp;
    if (dive.waterTemp != null) json['depthtemp'] = dive.waterTemp;
    final weight = dive.weightAmount;
    if (weight != null && weight > 0) json['weights'] = weight;
    final surfaceInterval = dive.surfaceInterval?.inSeconds;
    if (surfaceInterval != null && surfaceInterval > 0) {
      json['surface_interval'] = surfaceInterval;
    }
    if (dive.diveComputerModel != null) {
      json['dc_model'] = dive.diveComputerModel;
    }

    final tanks = dive.tanks
        .map(
          (t) => <String, dynamic>{
            'o2': t.gasMix.o2,
            'he': t.gasMix.he,
            if (t.startPressure != null) 'start_pressure': t.startPressure,
            if (t.endPressure != null) 'end_pressure': t.endPressure,
            if (t.volume != null && t.volume! > 0) 'vol': t.volume,
            if (t.workingPressure != null && t.workingPressure! > 0)
              'wp': t.workingPressure,
            if (t.name != null && t.name!.isNotEmpty) 'tankname': t.name,
          },
        )
        .toList();
    if (tanks.isNotEmpty) json['tanks'] = tanks;

    _addProfile(json, dive.profile);
    return json;
  }

  /// divelogs sampledata assumes one fixed sample rate, so only uniform
  /// profiles are exported; anything else is omitted rather than distorted.
  void _addProfile(Map<String, dynamic> json, List<DiveProfilePoint> profile) {
    if (profile.length < 2) return;
    final delta = profile[1].timestamp - profile[0].timestamp;
    if (delta <= 0) return;
    for (var i = 1; i < profile.length; i++) {
      if (profile[i].timestamp - profile[i - 1].timestamp != delta) return;
    }
    json['samplerate'] = delta;
    json['sampledata'] = [
      for (final point in profile)
        if (point.temperature != null)
          {'d': point.depth, 't': point.temperature}
        else
          point.depth,
    ];
  }
}
