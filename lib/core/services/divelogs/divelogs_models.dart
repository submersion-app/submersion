/// Typed views over the divelogs.de REST API JSON.
///
/// Field names and semantics follow the OpenAPI spec at
/// https://divelogs.de/api/docs/divelogs-openapi3.json. All values are
/// metric (meters, bar, Celsius, kg).
library;

double? _asDouble(Object? v) => switch (v) {
  final num n => n.toDouble(),
  final String s => double.tryParse(s),
  _ => null,
};

int? _asInt(Object? v) => switch (v) {
  final num n => n.toInt(),
  final String s => int.tryParse(s),
  _ => null,
};

String? _asNonEmptyString(Object? v) {
  if (v is! String) return null;
  final trimmed = v.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// A remote row id, or null when absent or blank. Ids key source ids, gear
/// links and photo maps, so an empty string must never stand in for one:
/// every blank-id row would then share a single key.
String? _asId(Object? v) => switch (v) {
  final num n => '$n',
  final String s => _asNonEmptyString(s),
  _ => null,
};

DateTime? _asUtcDate(Object? v) {
  final s = _asNonEmptyString(v);
  return s == null ? null : DateTime.tryParse('${s}T00:00:00Z');
}

class DivelogsSample {
  final double depth;
  final double? temperature;

  const DivelogsSample({required this.depth, this.temperature});
}

class DivelogsTank {
  final double? o2;
  final double? he;
  final double? startPressure;
  final double? endPressure;
  final double? volume;
  final double? workingPressure;
  final bool dbltank;
  final String? name;

  const DivelogsTank({
    this.o2,
    this.he,
    this.startPressure,
    this.endPressure,
    this.volume,
    this.workingPressure,
    this.dbltank = false,
    this.name,
  });

  factory DivelogsTank.fromJson(Map<String, dynamic> json) => DivelogsTank(
    o2: _asDouble(json['o2']),
    he: _asDouble(json['he']),
    startPressure: _asDouble(json['start_pressure']),
    endPressure: _asDouble(json['end_pressure']),
    volume: _asDouble(json['vol']),
    workingPressure: _asDouble(json['wp']),
    dbltank: json['dbltank'] == true,
    name:
        _asNonEmptyString(json['tankname']) ?? _asNonEmptyString(json['tank']),
  );
}

class DivelogsDive {
  final String? id;
  final DateTime dateTime;
  final int durationSeconds;
  final double maxDepth;
  final double? meanDepth;
  final int? sampleRateSeconds;
  final List<DivelogsSample> samples;
  final List<DivelogsTank> tanks;
  final String? buddy;
  final String? siteName;
  final String? location;
  final String? notes;
  final String? weather;
  final String? visibility;
  final String? boat;
  final String? dcModel;
  final double? latitude;
  final double? longitude;
  final double? airTemp;
  final double? depthTemp;
  final double? surfaceTemp;
  final double? weightsKg;
  final int? surfaceIntervalSeconds;
  final List<String> gearItemIds;

  const DivelogsDive({
    this.id,
    required this.dateTime,
    required this.durationSeconds,
    required this.maxDepth,
    this.meanDepth,
    this.sampleRateSeconds,
    this.samples = const [],
    this.tanks = const [],
    this.buddy,
    this.siteName,
    this.location,
    this.notes,
    this.weather,
    this.visibility,
    this.boat,
    this.dcModel,
    this.latitude,
    this.longitude,
    this.airTemp,
    this.depthTemp,
    this.surfaceTemp,
    this.weightsKg,
    this.surfaceIntervalSeconds,
    this.gearItemIds = const [],
  });

  factory DivelogsDive.fromJson(Map<String, dynamic> json) {
    final date = _asNonEmptyString(json['date']);
    final time = _asNonEmptyString(json['time']);
    final duration = _asInt(json['duration']);
    final maxDepth = _asDouble(json['maxdepth']);
    // A missing time is not guessed as midnight: a made-up start would
    // file the dive at the wrong moment and defeat duplicate matching.
    if (date == null || time == null || duration == null || maxDepth == null) {
      throw FormatException('divelogs dive missing mandatory fields', json);
    }
    // Dive timestamps are wall-clock; the import pipeline convention is to
    // represent wall-clock as UTC (matches the Subsurface parser and DB
    // loads with isUtc: true), so parse with an explicit Z suffix.
    final DateTime dateTime;
    try {
      dateTime = DateTime.parse('${date}T${time}Z');
    } on FormatException {
      throw FormatException('divelogs dive has unparseable date/time', json);
    }

    final samples = <DivelogsSample>[];
    final sampleData = json['sampledata'];
    if (sampleData is List) {
      for (final entry in sampleData) {
        if (entry is num) {
          samples.add(DivelogsSample(depth: entry.toDouble()));
        } else if (entry is Map) {
          final d = _asDouble(entry['d']);
          if (d != null) {
            samples.add(
              DivelogsSample(depth: d, temperature: _asDouble(entry['t'])),
            );
          }
        }
      }
    }

    final tanks = <DivelogsTank>[];
    final tanksJson = json['tanks'];
    if (tanksJson is List) {
      for (final t in tanksJson) {
        if (t is Map) {
          tanks.add(DivelogsTank.fromJson(Map<String, dynamic>.from(t)));
        }
      }
    }

    return DivelogsDive(
      id: _asId(json['id'] ?? json['dive_id']),
      dateTime: dateTime,
      durationSeconds: duration,
      maxDepth: maxDepth,
      meanDepth: _asDouble(json['meandepth']),
      sampleRateSeconds: _asInt(json['samplerate']),
      samples: samples,
      tanks: tanks,
      buddy: _asNonEmptyString(json['buddy']),
      siteName: _asNonEmptyString(json['divesite']),
      location: _asNonEmptyString(json['location']),
      notes: _asNonEmptyString(json['notes']),
      weather: _asNonEmptyString(json['weather']),
      visibility: _asNonEmptyString(json['visibility']),
      boat: _asNonEmptyString(json['boat']),
      dcModel: _asNonEmptyString(json['dc_model']),
      latitude: _asDouble(json['lat']),
      longitude: _asDouble(json['lng']),
      airTemp: _asDouble(json['airtemp']),
      depthTemp: _asDouble(json['depthtemp']),
      surfaceTemp: _asDouble(json['surfacetemp']),
      weightsKg: _asDouble(json['weights']),
      surfaceIntervalSeconds: _asInt(json['surface_interval']),
      gearItemIds: json['gearitems'] is List
          ? [for (final g in json['gearitems'] as List) '$g']
          : const [],
    );
  }
}

class DivelogsDivesResult {
  final List<DivelogsDive> dives;
  final int skippedCount;

  const DivelogsDivesResult({required this.dives, this.skippedCount = 0});
}

/// One row of GET /gear. Tolerant: unusable rows yield null.
class DivelogsGearItem {
  final String id;
  final String name;
  final int? geartypeId;
  final DateTime? purchaseDate;
  final DateTime? lastServiceDate;
  final DateTime? discardDate;

  const DivelogsGearItem({
    required this.id,
    required this.name,
    this.geartypeId,
    this.purchaseDate,
    this.lastServiceDate,
    this.discardDate,
  });

  static DivelogsGearItem? fromJson(Map<String, dynamic> json) {
    final rawId = _asId(json['id'] ?? json['gear_id']);
    final name = _asNonEmptyString(json['name']);
    if (rawId == null || name == null) return null;
    return DivelogsGearItem(
      id: rawId,
      name: name,
      geartypeId: _asInt(json['geartype']),
      purchaseDate: _asUtcDate(json['purchasedate']),
      lastServiceDate: _asUtcDate(json['last_servicedate']),
      discardDate: _asUtcDate(json['discarddate']),
    );
  }
}

/// One row of GET /certifications. Tolerant: unusable rows yield null.
class DivelogsCertification {
  final String? id;
  final String name;
  final DateTime? date;
  final String? org;

  const DivelogsCertification({
    this.id,
    required this.name,
    this.date,
    this.org,
  });

  static DivelogsCertification? fromJson(Map<String, dynamic> json) {
    final name = _asNonEmptyString(json['name']);
    if (name == null) return null;
    final rawId = _asId(json['id']);
    return DivelogsCertification(
      id: rawId,
      name: name,
      date: _asUtcDate(json['date']),
      org: _asNonEmptyString(json['org']),
    );
  }
}

/// One row of GET /pictures/{dive_id}. The response shape is undocumented,
/// so parsing is tolerant: [url] is the first key that resolves to an
/// absolute http(s) URI, and rows with only a bare filename keep their id
/// with a null url (the caller counts those as un-downloadable).
class DivelogsPicture {
  final String? id;
  final Uri? url;

  const DivelogsPicture({this.id, this.url});

  static const _urlKeys = ['url', 'link', 'href', 'imageurl'];

  static DivelogsPicture? fromJson(Map<String, dynamic> json) {
    final rawId = _asId(json['id'] ?? json['picture_id']);
    Uri? url;
    for (final key in _urlKeys) {
      final candidate = _asNonEmptyString(json[key]);
      if (candidate == null) continue;
      final parsed = Uri.tryParse(candidate);
      if (parsed != null &&
          (parsed.isScheme('http') || parsed.isScheme('https'))) {
        url = parsed;
        break;
      }
    }
    final hasUrlKey = _urlKeys.any((k) => json[k] != null);
    if (rawId == null && !hasUrlKey) return null;
    return DivelogsPicture(id: rawId, url: url);
  }
}
