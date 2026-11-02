import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// The agent-facing view of a diver profile.
///
/// Deliberately a whitelist: [Diver] carries contact details, medical notes
/// and a photo, none of which an agent needs to act as that profile.
Map<String, Object?> diverDocument(
  Diver diver, {
  required bool isActive,
  required int diveCount,
  required AppSettings settings,
}) {
  return {
    'id': diver.id,
    'name': diver.name,
    'is_active': isActive,
    'is_default': diver.isDefault,
    'dive_count': diveCount,
    'units': unitsDocument(settings),
    'date_format': settings.dateFormat.pattern,
    'time_format': switch (settings.timeFormat) {
      TimeFormat.twelveHour => '12h',
      TimeFormat.twentyFourHour => '24h',
    },
  };
}

/// The display units a profile prefers, as short agent-facing codes.
Map<String, String> unitsDocument(AppSettings settings) {
  return {
    'depth': switch (settings.depthUnit) {
      DepthUnit.meters => 'm',
      DepthUnit.feet => 'ft',
    },
    'temperature': switch (settings.temperatureUnit) {
      TemperatureUnit.celsius => 'c',
      TemperatureUnit.fahrenheit => 'f',
    },
    'pressure': switch (settings.pressureUnit) {
      PressureUnit.bar => 'bar',
      PressureUnit.psi => 'psi',
    },
    'volume': switch (settings.volumeUnit) {
      VolumeUnit.liters => 'l',
      VolumeUnit.cubicFeet => 'cuft',
    },
    'weight': switch (settings.weightUnit) {
      WeightUnit.kilograms => 'kg',
      WeightUnit.pounds => 'lb',
    },
  };
}
