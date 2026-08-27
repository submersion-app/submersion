import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Localized relative "last download" label for a dive computer (#152).
///
/// Replaces the domain entity's `lastDownloadFormatted` getter, which had
/// no [BuildContext] and therefore structurally could not localize -- it
/// leaked hardcoded English (and a fixed M/D/Y date) into the Transfer,
/// device list, and device detail screens on every locale.
String formatLastDownload(BuildContext context, DateTime? lastDownload) {
  final l10n = context.l10n;
  if (lastDownload == null) return l10n.transfer_computers_lastDownloadNever;

  // Clamp a future timestamp (dive-computer or host clock skew) to zero:
  // a negative Duration would render as "-1 hours ago".
  final now = DateTime.now();
  final diff = lastDownload.isAfter(now)
      ? Duration.zero
      : now.difference(lastDownload);
  if (diff.inDays == 0) {
    if (diff.inHours == 0) {
      return l10n.transfer_computers_lastDownloadMinutesAgo(diff.inMinutes);
    }
    return l10n.transfer_computers_lastDownloadHoursAgo(diff.inHours);
  }
  if (diff.inDays == 1) return l10n.transfer_computers_lastDownloadYesterday;
  if (diff.inDays < 7) {
    return l10n.transfer_computers_lastDownloadDaysAgo(diff.inDays);
  }

  // Older downloads: a locale-appropriate numeric date instead of the old
  // hardcoded month/day/year.
  final locale = Localizations.localeOf(context).toString();
  return DateFormat.yMd(locale).format(lastDownload);
}
