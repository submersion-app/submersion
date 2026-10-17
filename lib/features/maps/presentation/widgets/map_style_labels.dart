import 'package:flutter/material.dart';

import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// User-facing name and icon for each [MapStyle].
///
/// Shared by the Settings > Appearance dropdown and the on-map
/// [MapStyleButton] so both always describe a style in the same words.
extension MapStyleLabels on MapStyle {
  String label(AppLocalizations l10n) {
    return switch (this) {
      MapStyle.openStreetMap => l10n.settings_appearance_mapStyle_openStreetMap,
      MapStyle.openTopoMap => l10n.settings_appearance_mapStyle_openTopoMap,
      MapStyle.esriSatellite => l10n.settings_appearance_mapStyle_esriSatellite,
    };
  }

  IconData get icon {
    return switch (this) {
      MapStyle.openStreetMap => Icons.map_outlined,
      MapStyle.openTopoMap => Icons.terrain_outlined,
      MapStyle.esriSatellite => Icons.satellite_alt_outlined,
    };
  }
}
