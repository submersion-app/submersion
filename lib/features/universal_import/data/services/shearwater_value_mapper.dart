import 'package:submersion/core/constants/enums.dart';

/// Converts Shearwater Cloud field values to Submersion's metric system
/// and maps condition strings to Submersion enums.
class ShearwaterValueMapper {
  // ---------------------------------------------------------------------------
  // Unit conversions
  // ---------------------------------------------------------------------------

  static double psiToBar(num psi) => psi / 14.5038;

  static double fahrenheitToCelsius(num f) => (f - 32) * 5 / 9;

  static double lbsToKg(num lbs) => lbs * 0.453592;

  static double feetToMeters(num feet) => feet * 0.3048;

  static double mbarToBar(num mbar) => mbar / 1000;

  // ---------------------------------------------------------------------------
  // Conditions mapping
  // ---------------------------------------------------------------------------

  static WaterType? mapWaterType(String? environment) {
    if (environment == null || environment.isEmpty) return null;
    return switch (environment) {
      'Ocean/Sea' => WaterType.salt,
      'Pool' || 'Lake' || 'Quarry' || 'River' => WaterType.fresh,
      'Brackish' => WaterType.brackish,
      _ => null,
    };
  }

  static CloudCover? mapCloudCover(String? weather) {
    if (weather == null || weather.isEmpty) return null;
    return switch (weather) {
      'Sunny' || 'Clear' => CloudCover.clear,
      'Partly Cloudy' => CloudCover.partlyCloudy,
      'Cloudy' || 'Overcast' => CloudCover.mostlyCloudy,
      _ => null,
    };
  }

  static CurrentStrength? mapCurrentStrength(String? conditions) {
    if (conditions == null || conditions.isEmpty) return null;
    return switch (conditions) {
      'Current' => CurrentStrength.moderate,
      'Strong Current' => CurrentStrength.strong,
      'Light Current' => CurrentStrength.light,
      _ => null,
    };
  }

  /// Maps a visibility string value to a [Visibility] enum.
  ///
  /// [value] is the raw string (e.g. '100').
  /// [isImperial] indicates whether [value] is in feet (true) or meters (false).
  static Visibility? mapVisibility(String? value, {bool isImperial = true}) {
    if (value == null || value.isEmpty) return null;
    final numValue = double.tryParse(value);
    if (numValue == null) return null;
    final meters = isImperial ? feetToMeters(numValue) : numValue;
    if (meters >= 30) return Visibility.excellent;
    if (meters >= 15) return Visibility.good;
    if (meters >= 5) return Visibility.moderate;
    return Visibility.poor;
  }

  // ---------------------------------------------------------------------------
  // Extra notes builder
  // ---------------------------------------------------------------------------

  /// Collects unmapped Shearwater Cloud fields into a structured notes string.
  ///
  /// Weather and conditions values are only included when they cannot be mapped
  /// to a structured enum (i.e. they fall through to null). Returns null when
  /// there are no extra fields to record.
  static String? buildExtraNotes({
    String? weather,
    String? conditions,
    String? dress,
    String? thermalComfort,
    String? workload,
    String? problems,
    String? malfunctions,
    String? symptoms,
    String? gasNotes,
    String? gearNotes,
    String? issueNotes,
  }) {
    final entries = <String>[];
    if (weather != null && mapCloudCover(weather) == null) {
      entries.add('Weather: $weather');
    }
    if (conditions != null && mapCurrentStrength(conditions) == null) {
      entries.add('Conditions: $conditions');
    }
    if (dress != null) entries.add('Dress: $dress');
    if (thermalComfort != null) entries.add('Thermal Comfort: $thermalComfort');
    if (workload != null) entries.add('Workload: $workload');
    if (problems != null) entries.add('Problems: $problems');
    if (malfunctions != null) entries.add('Malfunctions: $malfunctions');
    if (symptoms != null) entries.add('Symptoms: $symptoms');
    if (gasNotes != null) entries.add('Gas Notes: $gasNotes');
    if (gearNotes != null) entries.add('Gear Notes: $gearNotes');
    if (issueNotes != null) entries.add('Issue Notes: $issueNotes');
    if (entries.isEmpty) return null;
    return '[Shearwater Cloud]\n${entries.join('\n')}';
  }
}
