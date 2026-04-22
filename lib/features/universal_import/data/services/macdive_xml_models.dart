/// Unit system declared at the top of a MacDive XML document (`<units>` child).
enum MacDiveUnitSystem {
  /// Feet, Fahrenheit, PSI, pounds.
  imperial,

  /// Meters, Celsius, bar, kilograms.
  metric,

  /// Value absent or unrecognised; converter should no-op and downstream
  /// code should treat fields as their raw form.
  unknown;

  /// Parse a MacDive `<units>` element text value. Case-insensitive. Whitespace
  /// is trimmed. Unknown or null input returns [unknown].
  static MacDiveUnitSystem fromXml(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'imperial':
        return MacDiveUnitSystem.imperial;
      case 'metric':
        return MacDiveUnitSystem.metric;
      default:
        return MacDiveUnitSystem.unknown;
    }
  }
}

/// Root of a parsed MacDive XML document (`<dives>` root element).
class MacDiveXmlLogbook {
  final MacDiveUnitSystem units;

  /// Schema version from the `<schema>` element (e.g. "2.2.0"). Nullable
  /// because older exports may omit it.
  final String? schemaVersion;

  final List<MacDiveXmlDive> dives;

  const MacDiveXmlLogbook({
    required this.units,
    required this.schemaVersion,
    required this.dives,
  });
}

/// A photo referenced under a dive's `<photos>` container in MacDive XML.
class MacDiveXmlPhoto {
  /// Absolute path as recorded in the XML. May not exist on the
  /// machine running the import — the resolver handles misses.
  final String path;

  /// Optional caption. Empty CDATA / whitespace-only caption comes
  /// through as null (consistent with the reader's `_text` normaliser).
  final String? caption;

  /// 0-based index among this dive's photos. Assigned by the reader.
  final int position;

  const MacDiveXmlPhoto({required this.path, this.caption, this.position = 0});
}

/// A single dive from a MacDive XML file. All numeric fields are in SI
/// canonical units after the unit converter has run at the reader boundary.
class MacDiveXmlDive {
  /// Stable MacDive identifier, e.g. `"20260311140918-CB115EF0"` (datetime +
  /// computer serial). Carried through as `sourceUuid` in the payload.
  final String? identifier;

  final DateTime? date;
  final int? diveNumber;

  /// Repetitive-dive number within a 24-hour window (0 for first dive of day).
  final int? repetitiveDive;

  /// 0.0 - 5.0 in MacDive (stars).
  final double? rating;

  final double? maxDepthMeters;
  final double? avgDepthMeters;

  /// CNS % at surface.
  final double? cns;

  /// Text label, e.g. "ZHL-16C GF 50/85".
  final String? decoModel;

  final Duration? duration;
  final Duration? surfaceInterval;
  final Duration? sampleInterval;

  /// E.g. "Air", "Nitrox", "Trimix".
  final String? gasModel;

  final double? airTempCelsius;
  final double? tempHighCelsius;
  final double? tempLowCelsius;

  /// Raw visibility text (unit may vary, often feet or meters).
  final String? visibility;

  final double? weightKg;
  final String? notes;
  final String? diveMaster;
  final String? diveOperator;
  final String? skipper;
  final String? boat;
  final String? weather;
  final String? current;
  final String? surfaceConditions;
  final String? entryType;

  /// Dive-computer model string (e.g. "Shearwater Tern").
  final String? computer;

  /// Dive-computer serial number.
  final String? serial;

  /// Owner/diver name (rarely populated in MacDive XML).
  final String? diver;

  final MacDiveXmlSite? site;
  final List<String> tags;
  final List<String> diveTypes;
  final List<String> buddies;
  final List<MacDiveXmlGearItem> gear;
  final List<MacDiveXmlGas> gases;
  final List<MacDiveXmlSample> samples;
  final List<MacDiveXmlPhoto> photos;

  const MacDiveXmlDive({
    this.identifier,
    this.date,
    this.diveNumber,
    this.repetitiveDive,
    this.rating,
    this.maxDepthMeters,
    this.avgDepthMeters,
    this.cns,
    this.decoModel,
    this.duration,
    this.surfaceInterval,
    this.sampleInterval,
    this.gasModel,
    this.airTempCelsius,
    this.tempHighCelsius,
    this.tempLowCelsius,
    this.visibility,
    this.weightKg,
    this.notes,
    this.diveMaster,
    this.diveOperator,
    this.skipper,
    this.boat,
    this.weather,
    this.current,
    this.surfaceConditions,
    this.entryType,
    this.computer,
    this.serial,
    this.diver,
    this.site,
    this.tags = const [],
    this.diveTypes = const [],
    this.buddies = const [],
    this.gear = const [],
    this.gases = const [],
    this.samples = const [],
    this.photos = const [],
  });
}

/// A dive-site record nested under a dive in MacDive XML. MacDive does not
/// emit a separate top-level site list; every dive carries its own site
/// block. Deduplication by name happens in the parser (Task 8).
class MacDiveXmlSite {
  final String? name;
  final String? country;
  final String? location;
  final String? bodyOfWater;

  /// Raw string like `"saltwater"`, `"freshwater"`, `"brackish"`. Mapped to
  /// an enum in the parser via [MacDiveValueMapper].
  final String? waterType;

  final String? difficulty;
  final double? altitudeMeters;

  /// Latitude in decimal degrees. Null when MacDive wrote 0.0/0.0 (which
  /// MacDive uses as "no GPS set" — the reader applies that filter).
  final double? latitude;
  final double? longitude;

  const MacDiveXmlSite({
    this.name,
    this.country,
    this.location,
    this.bodyOfWater,
    this.waterType,
    this.difficulty,
    this.altitudeMeters,
    this.latitude,
    this.longitude,
  });
}

/// A gear / equipment item attached to a dive. MacDive's `<gear><item>` format.
class MacDiveXmlGearItem {
  /// E.g. "Regulator", "BCD - Wing", "Computer", "Suit".
  final String? type;

  final String? manufacturer;
  final String? name;
  final String? serial;

  const MacDiveXmlGearItem({
    this.type,
    this.manufacturer,
    this.name,
    this.serial,
  });
}

/// A gas / tank entry from `<gases><gas>`. A dive may have multiple for
/// multi-tank / deco setups.
class MacDiveXmlGas {
  final double? pressureStartBar;
  final double? pressureEndBar;

  /// 0-100.
  final double? oxygenPercent;

  /// 0-100.
  final double? heliumPercent;

  /// MacDive emits an integer flag (0 or 1) for double-tank setups.
  final bool? doubleTank;

  /// Tank size in liters after unit conversion (MacDive Imperial uses cubic
  /// feet at the working pressure; metric uses liters directly).
  final double? tankSizeLiters;

  final double? workingPressureBar;

  /// E.g. "Open Circuit", "CCR", "SCR".
  final String? supplyType;

  final Duration? duration;

  /// E.g. "AL80", "Steel 72".
  final String? tankName;

  const MacDiveXmlGas({
    this.pressureStartBar,
    this.pressureEndBar,
    this.oxygenPercent,
    this.heliumPercent,
    this.doubleTank,
    this.tankSizeLiters,
    this.workingPressureBar,
    this.supplyType,
    this.duration,
    this.tankName,
  });
}

/// A single profile sample (`<samples><sample>`). MacDive samples are
/// typically 10-second intervals.
class MacDiveXmlSample {
  final Duration time;
  final double? depthMeters;
  final double? pressureBar;
  final double? temperatureCelsius;
  final double? ppO2;

  /// No-deco limit in seconds after unit conversion. MacDive stores as
  /// minutes; reader converts.
  final int? ndtSeconds;

  const MacDiveXmlSample({
    required this.time,
    this.depthMeters,
    this.pressureBar,
    this.temperatureCelsius,
    this.ppO2,
    this.ndtSeconds,
  });
}
