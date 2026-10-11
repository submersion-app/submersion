/// The `Logbook` columns only DiveMate writes (#3110), kept apart from the
/// Diving Log fields so a Diving Log file never carries them.
///
/// Values are the source's: codes and free text exactly as stored.
/// `DiveMateValues` reads them.
class DiveMateDiveExtras {
  /// 1 salt, 2 fresh, 0 unset.
  final int? water;

  /// 1 to 5 stars, 0 unrated.
  final int? rating;

  /// Free text: a level word or a distance.
  final String? visibility;

  /// Free text, such as `leichte Strömung`.
  final String? current;
  final String? waves;
  final String? weather;

  /// 1 shore, 2 boat, 0 unset.
  final int? entry;
  final String? boat;

  /// `H:MM`, or `0:0-1` when unknown.
  final String? surfaceInterval;

  const DiveMateDiveExtras({
    this.water,
    this.rating,
    this.visibility,
    this.current,
    this.waves,
    this.weather,
    this.entry,
    this.boat,
    this.surfaceInterval,
  });
}

/// The `Tank` columns only DiveMate writes.
class DiveMateTankExtras {
  /// The cylinder's gear name, such as `80cuft Alu`.
  final String? name;

  /// 1 aluminium, 2 steel.
  final int? material;

  /// 4 sidemount, 1 open circuit, 0 unset.
  final int? supplyType;

  /// 3 deco, 4 stage, 0 or null bottom gas.
  final int? divePhase;

  /// Seconds the cylinder was breathed.
  final int? breathingSeconds;

  const DiveMateTankExtras({
    this.name,
    this.material,
    this.supplyType,
    this.divePhase,
    this.breathingSeconds,
  });
}
