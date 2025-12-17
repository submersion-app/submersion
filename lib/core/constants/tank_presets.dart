import 'enums.dart';

/// Predefined tank configurations for common tanks
class TankPreset {
  final String name;
  final String displayName;
  final double volumeLiters;
  final int workingPressureBar;
  final TankMaterial material;
  final String? description;

  const TankPreset({
    required this.name,
    required this.displayName,
    required this.volumeLiters,
    required this.workingPressureBar,
    required this.material,
    this.description,
  });

  /// Calculate the gas capacity in cubic feet at surface pressure.
  /// Formula: (water_volume_liters * working_pressure_bar) / 28.3168
  /// This is the imperial "tank size" rating (e.g., AL80 = 80 cuft)
  double get volumeCuft => (volumeLiters * workingPressureBar) / 28.3168;
}

/// Built-in tank presets (common configurations)
class TankPresets {
  TankPresets._();

  // Aluminum tanks (common in US)
  static const al40 = TankPreset(
    name: 'al40',
    displayName: 'AL40',
    volumeLiters: 5.7,
    workingPressureBar: 207,
    material: TankMaterial.aluminum,
    description: 'Aluminum 40 cu ft (pony)',
  );

  static const al63 = TankPreset(
    name: 'al63',
    displayName: 'AL63',
    volumeLiters: 9.0,
    workingPressureBar: 207,
    material: TankMaterial.aluminum,
    description: 'Aluminum 63 cu ft',
  );

  static const al80 = TankPreset(
    name: 'al80',
    displayName: 'AL80',
    volumeLiters: 11.1,
    workingPressureBar: 207,
    material: TankMaterial.aluminum,
    description: 'Aluminum 80 cu ft (most common)',
  );

  // High pressure steel tanks
  static const hp80 = TankPreset(
    name: 'hp80',
    displayName: 'HP80',
    volumeLiters: 10.2,
    workingPressureBar: 234,
    material: TankMaterial.steel,
    description: 'High Pressure Steel 80 cu ft',
  );

  static const hp100 = TankPreset(
    name: 'hp100',
    displayName: 'HP100',
    volumeLiters: 12.9,
    workingPressureBar: 234,
    material: TankMaterial.steel,
    description: 'High Pressure Steel 100 cu ft',
  );

  static const hp120 = TankPreset(
    name: 'hp120',
    displayName: 'HP120',
    volumeLiters: 15.1,
    workingPressureBar: 234,
    material: TankMaterial.steel,
    description: 'High Pressure Steel 120 cu ft',
  );

  // Low pressure steel tanks
  static const lp85 = TankPreset(
    name: 'lp85',
    displayName: 'LP85',
    volumeLiters: 12.0,
    workingPressureBar: 193,
    material: TankMaterial.steel,
    description: 'Low Pressure Steel 85 cu ft',
  );

  // Metric tanks (common in Europe)
  static const steel10 = TankPreset(
    name: 'steel10',
    displayName: 'Steel 10L',
    volumeLiters: 10.0,
    workingPressureBar: 200,
    material: TankMaterial.steel,
    description: 'Steel 10 liter (Europe)',
  );

  static const steel12 = TankPreset(
    name: 'steel12',
    displayName: 'Steel 12L',
    volumeLiters: 12.0,
    workingPressureBar: 200,
    material: TankMaterial.steel,
    description: 'Steel 12 liter (Europe)',
  );

  static const steel15 = TankPreset(
    name: 'steel15',
    displayName: 'Steel 15L',
    volumeLiters: 15.0,
    workingPressureBar: 200,
    material: TankMaterial.steel,
    description: 'Steel 15 liter (Europe)',
  );

  // Stage/deco tanks
  static const al30Stage = TankPreset(
    name: 'al30stage',
    displayName: 'AL30 Stage',
    volumeLiters: 4.3,
    workingPressureBar: 207,
    material: TankMaterial.aluminum,
    description: 'Aluminum 30 cu ft stage tank',
  );

  static const al40Stage = TankPreset(
    name: 'al40stage',
    displayName: 'AL40 Stage',
    volumeLiters: 5.7,
    workingPressureBar: 207,
    material: TankMaterial.aluminum,
    description: 'Aluminum 40 cu ft stage tank',
  );

  /// All available presets grouped by category
  static const List<TankPreset> aluminum = [al80, al63, al40];
  static const List<TankPreset> hpSteel = [hp120, hp100, hp80];
  static const List<TankPreset> lpSteel = [lp85];
  static const List<TankPreset> metric = [steel15, steel12, steel10];
  static const List<TankPreset> stage = [al40Stage, al30Stage];

  /// All available presets
  static const List<TankPreset> all = [
    al80,
    al63,
    al40,
    hp120,
    hp100,
    hp80,
    lp85,
    steel15,
    steel12,
    steel10,
    al40Stage,
    al30Stage,
  ];

  /// Get preset by name
  static TankPreset? byName(String name) {
    try {
      return all.firstWhere((p) => p.name == name);
    } catch (_) {
      return null;
    }
  }
}
