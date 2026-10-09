/// Named, association-researched standard gas mixes (issue #3117).
///
/// Pure data: no dependency on the Best Mix calculator's inputs or any
/// ambient-pressure model. The catalog is read-only reference material,
/// filtered and sorted by whoever consumes it (`best_mix.dart`) against
/// the caller's own depth, ppO2 and narcosis settings.
library;

/// What a standard mix is typically used for.
enum StandardGasCategory {
  /// A nitrox (or air) breathed as the only gas of a dive.
  nitrox,

  /// A trimix breathed at depth.
  bottomGas,

  /// A richer gas breathed only during the ascent/stops.
  decoGas,
}

/// One named standard gas mix, with the diving organizations that
/// document it as a defined standard (empty when the research found none;
/// see `docs/design/findings/` for the sources behind each entry).
///
/// Not shown in the UI (issue #3117 decision): the attribution exists for
/// traceability back to the research, not as an in-app citation.
class StandardGasMix {
  final String name;
  final double o2Percent;
  final double hePercent;
  final StandardGasCategory category;
  final List<String> associations;

  const StandardGasMix({
    required this.name,
    required this.o2Percent,
    this.hePercent = 0,
    required this.category,
    this.associations = const [],
  });

  bool get isTrimix => hePercent > 0;
}

/// The standard gas mixes researched for issue #3117, richest O2 first
/// within each category. See `docs/design/findings/` for the sources.
const List<StandardGasMix> standardGasMixes = [
  // Nitrox
  StandardGasMix(
    name: 'Air',
    o2Percent: 21,
    category: StandardGasCategory.nitrox,
  ),
  StandardGasMix(
    name: 'EAN32',
    o2Percent: 32,
    category: StandardGasCategory.nitrox,
    associations: ['NOAA'],
  ),
  StandardGasMix(
    name: 'EAN36',
    o2Percent: 36,
    category: StandardGasCategory.nitrox,
    associations: ['NOAA'],
  ),
  StandardGasMix(
    name: 'EAN40',
    o2Percent: 40,
    category: StandardGasCategory.nitrox,
  ),

  // Deco gases
  StandardGasMix(
    name: 'EAN50',
    o2Percent: 50,
    category: StandardGasCategory.decoGas,
    associations: ['GUE'],
  ),
  StandardGasMix(
    name: 'O2',
    o2Percent: 100,
    category: StandardGasCategory.decoGas,
    associations: ['GUE'],
  ),

  // Bottom gases (trimix), GUE's standard ladder
  StandardGasMix(
    name: 'Trimix 21/35',
    o2Percent: 21,
    hePercent: 35,
    category: StandardGasCategory.bottomGas,
    associations: ['GUE'],
  ),
  StandardGasMix(
    name: 'Trimix 18/45',
    o2Percent: 18,
    hePercent: 45,
    category: StandardGasCategory.bottomGas,
    associations: ['GUE', 'IANTD'],
  ),
  StandardGasMix(
    name: 'Trimix 15/55',
    o2Percent: 15,
    hePercent: 55,
    category: StandardGasCategory.bottomGas,
    associations: ['GUE'],
  ),
  StandardGasMix(
    name: 'Trimix 12/65',
    o2Percent: 12,
    hePercent: 65,
    category: StandardGasCategory.bottomGas,
    associations: ['GUE'],
  ),
  StandardGasMix(
    name: 'Trimix 10/70',
    o2Percent: 10,
    hePercent: 70,
    category: StandardGasCategory.bottomGas,
    associations: ['GUE'],
  ),

  // Bottom gases (trimix), IANTD's own ladder
  StandardGasMix(
    name: 'Trimix 28/25',
    o2Percent: 28,
    hePercent: 25,
    category: StandardGasCategory.bottomGas,
    associations: ['IANTD'],
  ),
  StandardGasMix(
    name: 'Trimix 32/15',
    o2Percent: 32,
    hePercent: 15,
    category: StandardGasCategory.bottomGas,
    associations: ['IANTD'],
  ),
  StandardGasMix(
    name: 'Trimix 19/40',
    o2Percent: 19,
    hePercent: 40,
    category: StandardGasCategory.bottomGas,
    associations: ['IANTD'],
  ),
  StandardGasMix(
    name: 'Trimix 14/50',
    o2Percent: 14,
    hePercent: 50,
    category: StandardGasCategory.bottomGas,
    associations: ['IANTD'],
  ),
  StandardGasMix(
    name: 'Trimix 12/60',
    o2Percent: 12,
    hePercent: 60,
    category: StandardGasCategory.bottomGas,
    associations: ['IANTD'],
  ),

  // Bottom gases (trimix), app-internal (no association source found)
  StandardGasMix(
    name: 'Trimix 18/35',
    o2Percent: 18,
    hePercent: 35,
    category: StandardGasCategory.bottomGas,
  ),
  StandardGasMix(
    name: 'Trimix 25/50',
    o2Percent: 25,
    hePercent: 50,
    category: StandardGasCategory.bottomGas,
  ),
  StandardGasMix(
    name: 'Heliox/Trimix 50/20',
    o2Percent: 50,
    hePercent: 20,
    category: StandardGasCategory.bottomGas,
  ),
];
