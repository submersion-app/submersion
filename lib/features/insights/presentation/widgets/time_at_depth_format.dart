import 'package:submersion/l10n/arb/app_localizations.dart';

/// The largest bar, in minutes, from which the Time at depth chart reads in
/// hours (issue #4600): ten hours. Below it a log is small enough that
/// minutes stay easy to read and the chart looks as it always has.
const int timeAtDepthHoursThresholdMinutes = 600;

/// From this many minutes a value drops its minutes and reads in whole
/// hours: 100 hours.
const int _wholeHoursFromMinutes = 6000;

const int _minutesPerHour = 60;

/// Whether a Time at depth chart whose largest bar is [maxMinutes] reads in
/// hours.
bool timeAtDepthUsesHours(int maxMinutes) =>
    maxMinutes >= timeAtDepthHoursThresholdMinutes;

/// One bar's time, as its tooltip and its semantics read it.
///
/// With [hours] false this is the minute string the chart has always shown.
/// With it true the value reads as "18h 20m", or in whole rounded hours
/// ("1,104 h") from 100 hours, where the minutes are noise. A bar under an
/// hour still reads in minutes ("5 min") rather than as "0h 5m".
String formatTimeAtDepth(
  AppLocalizations l10n,
  int minutes, {
  required bool hours,
}) {
  if (!hours || minutes < _minutesPerHour) {
    return l10n.insights_profile_timeAtDepth_valueFormat(minutes);
  }
  if (minutes >= _wholeHoursFromMinutes) {
    return l10n.insights_profile_timeAtDepth_hoursFormat(
      (minutes / _minutesPerHour).round(),
    );
  }
  return l10n.common_elapsed_hoursMinutes(
    minutes ~/ _minutesPerHour,
    minutes % _minutesPerHour,
  );
}
