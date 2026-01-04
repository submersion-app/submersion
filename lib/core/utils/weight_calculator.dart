import '../constants/enums.dart';

/// Weight calculator utility for diving
/// Calculates recommended weight based on exposure suit, tank type, and water type
class WeightCalculator {
  /// Base weight recommendations by exposure suit type
  static const Map<String, double> _suitBaseWeights = {
    'none': 0, // No exposure suit
    'rashguard': 0, // Minimal or no weight
    'shorty_3mm': 2, // 3mm shorty
    'wetsuit_3mm': 3, // 3mm full wetsuit
    'wetsuit_5mm': 5, // 5mm wetsuit
    'wetsuit_7mm': 7, // 7mm wetsuit
    'semidry': 8, // Semi-dry suit
    'drysuit': 10, // Drysuit
  };

  /// Tank buoyancy adjustments (positive = needs more weight)
  static const Map<TankMaterial, double> _tankAdjustments = {
    TankMaterial.aluminum: 2.0, // Aluminum tanks are more buoyant when empty
    TankMaterial.steel: -2.0, // Steel tanks are negatively buoyant
    TankMaterial.carbonFiber: 3.0, // Carbon fiber is very buoyant
  };

  /// Water type adjustments (salt water needs more weight)
  static const Map<WaterType, double> _waterAdjustments = {
    WaterType.fresh: -2.0, // Less buoyant in fresh water
    WaterType.salt: 0, // Baseline
    WaterType.brackish: -1.0, // Between fresh and salt
  };

  /// Calculate recommended weight based on parameters
  ///
  /// Parameters:
  /// - [suitType]: Type of exposure suit (see _suitBaseWeights keys)
  /// - [tankMaterial]: Material of the tank being used
  /// - [waterType]: Type of water (fresh, salt, brackish)
  /// - [bodyWeightKg]: Diver's body weight in kg (optional, for fine-tuning)
  ///
  /// Returns recommended weight in kg
  static double calculateRecommendedWeight({
    required String suitType,
    TankMaterial? tankMaterial,
    WaterType? waterType,
    double? bodyWeightKg,
  }) {
    // Start with base weight for suit
    double weight = _suitBaseWeights[suitType] ?? 0;

    // Adjust for tank material
    if (tankMaterial != null) {
      weight += _tankAdjustments[tankMaterial] ?? 0;
    }

    // Adjust for water type
    if (waterType != null) {
      weight += _waterAdjustments[waterType] ?? 0;
    }

    // Optional body weight adjustment (roughly 1kg per 10kg body weight over 70kg)
    if (bodyWeightKg != null && bodyWeightKg > 70) {
      weight += (bodyWeightKg - 70) / 10;
    }

    // Ensure non-negative
    return weight < 0 ? 0 : weight;
  }

  /// Get a human-readable description of the weight calculation
  static String getCalculationBreakdown({
    required String suitType,
    TankMaterial? tankMaterial,
    WaterType? waterType,
    double? bodyWeightKg,
  }) {
    final buffer = StringBuffer();
    final baseWeight = _suitBaseWeights[suitType] ?? 0;

    buffer.writeln('Weight Calculation:');
    buffer.writeln(
      '  Base (${suitType.replaceAll('_', ' ')}): ${baseWeight.toStringAsFixed(1)} kg',
    );

    if (tankMaterial != null) {
      final adj = _tankAdjustments[tankMaterial] ?? 0;
      buffer.writeln(
        '  Tank (${tankMaterial.displayName}): ${adj >= 0 ? '+' : ''}${adj.toStringAsFixed(1)} kg',
      );
    }

    if (waterType != null) {
      final adj = _waterAdjustments[waterType] ?? 0;
      buffer.writeln(
        '  Water (${waterType.displayName}): ${adj >= 0 ? '+' : ''}${adj.toStringAsFixed(1)} kg',
      );
    }

    if (bodyWeightKg != null && bodyWeightKg > 70) {
      final adj = (bodyWeightKg - 70) / 10;
      buffer.writeln('  Body weight adjustment: +${adj.toStringAsFixed(1)} kg');
    }

    final total = calculateRecommendedWeight(
      suitType: suitType,
      tankMaterial: tankMaterial,
      waterType: waterType,
      bodyWeightKg: bodyWeightKg,
    );
    buffer.writeln('  ---');
    buffer.writeln('  Total: ${total.toStringAsFixed(1)} kg');

    return buffer.toString();
  }

  /// Available suit types with display names
  static Map<String, String> get suitTypes => {
    'none': 'No Suit',
    'rashguard': 'Rashguard Only',
    'shorty_3mm': '3mm Shorty',
    'wetsuit_3mm': '3mm Full Wetsuit',
    'wetsuit_5mm': '5mm Wetsuit',
    'wetsuit_7mm': '7mm Wetsuit',
    'semidry': 'Semi-dry Suit',
    'drysuit': 'Drysuit',
  };
}
