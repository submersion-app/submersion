import 'package:flutter/widgets.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Localized display name for an itinerary [DayType].
///
/// [DayType.displayName] is a hard-coded English label baked into the enum;
/// this maps it through the app's localized strings so itinerary/story
/// subtitles are translated like the rest of the UI.
extension DayTypeL10n on DayType {
  String localizedName(BuildContext context) {
    final l10n = context.l10n;
    switch (this) {
      case DayType.diveDay:
        return l10n.trips_dayType_diveDay;
      case DayType.seaDay:
        return l10n.trips_dayType_seaDay;
      case DayType.portDay:
        return l10n.trips_dayType_portDay;
      case DayType.embark:
        return l10n.trips_dayType_embark;
      case DayType.disembark:
        return l10n.trips_dayType_disembark;
    }
  }
}
