import 'package:submersion/features/safety/presentation/formatters/no_fly_format.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// How long ago the last dive ended, for the CNS/OTU readout.
///
/// Within a day it reads like the no-fly countdown ("25min", "5h 12m", and
/// "<1min" right after surfacing). From a day on it switches to days and
/// hours ("3d 4h"): the readout stays up for as long as the dive is inside
/// the 7-day OTU window, and "121h 14m" is hard to read at a glance.
String formatTimeSinceLastDive(Duration elapsed, AppLocalizations l10n) {
  if (elapsed.inHours < Duration.hoursPerDay) {
    return formatNoFlyRemaining(elapsed);
  }
  return l10n.safetyHub_cnsOtu_elapsedDaysHours(
    elapsed.inDays,
    elapsed.inHours % Duration.hoursPerDay,
  );
}
