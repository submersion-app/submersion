import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// The query engine's view of the diver's unit settings (#2365).
UnitPrefs unitPrefsFromSettings(AppSettings settings) => UnitPrefs(
  depth: settings.depthUnit,
  temperature: settings.temperatureUnit,
  pressure: settings.pressureUnit,
  weight: settings.weightUnit,
  volume: settings.volumeUnit,
);

/// The parser grounds bare numbers and the printer renders them in these
/// units; the value editor shows their suffix. Rebuilds with the settings.
final queryUnitPrefsProvider = Provider<UnitPrefs>(
  (ref) => unitPrefsFromSettings(ref.watch(settingsProvider)),
);
