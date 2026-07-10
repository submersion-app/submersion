import 'dart:ui';

import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Countries using imperial-style units for everyday measurement.
const _imperialCountries = {'US', 'LR', 'MM'};

/// Maps a device locale to the unit preset the wizard preselects.
UnitPreset presetForLocale(Locale locale) {
  final country = locale.countryCode?.toUpperCase();
  if (country != null && _imperialCountries.contains(country)) {
    return UnitPreset.imperial;
  }
  return UnitPreset.metric;
}
