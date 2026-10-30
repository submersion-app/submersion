import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Header text for one matched-dive group in the Files tab review pane.
///
/// The title names the dive the way the rest of the app does (its number and
/// site), and the subtitle gives its date and time window so the user can
/// check it against the capture times on the photo rows below. The dive id the
/// header used to print appears nowhere else in the app (issue #3423).
///
/// [dive] is null when the dive list has not loaded yet or the dive was
/// deleted mid-review; the header then falls back to a bare "Dive" and the file
/// count, never the raw id.
({String title, String subtitle}) diveGroupHeaderText({
  required Dive? dive,
  required int fileCount,
  required AppLocalizations l10n,
  required UnitFormatter units,
}) {
  final files = l10n.media_photoPicker_files_groupCount(fileCount);
  if (dive == null) {
    return (
      title: l10n.media_photoPicker_files_diveGroupUnnamed,
      subtitle: files,
    );
  }

  final number = dive.diveNumber;
  final site = dive.site?.name.trim();
  final hasSite = site != null && site.isNotEmpty;
  final title = switch ((number, hasSite)) {
    (final int n, true) => l10n.media_photoPicker_files_diveGroupNumberSite(
      n,
      site!,
    ),
    (final int n, false) => l10n.media_photoPicker_files_diveGroupNumber(n),
    (null, true) => l10n.media_photoPicker_files_diveGroupSite(site!),
    (null, false) => l10n.media_photoPicker_files_diveGroupUnnamed,
  };

  return (
    title: title,
    subtitle: l10n.media_photoPicker_files_diveGroupSubtitle(
      _when(dive, l10n, units),
      files,
    ),
  );
}

/// The dive's date and its start-to-end window.
///
/// The end is the recorded exit, else start plus the recorded runtime. With
/// neither, only the start is shown: the matcher's one-hour fallback window is
/// a guess made to stay generous, and printing it would state an end the log
/// never had. For the same reason this reads [Dive.runtime] rather than
/// [Dive.effectiveRuntime], whose last resort is bottom time, which is not
/// runtime. An exit recorded before the entry is ignored rather than printed
/// as a backwards window, and an end on a later day is printed with its date.
String _when(Dive dive, AppLocalizations l10n, UnitFormatter units) {
  // Dive times are wall-clock UTC by codebase convention, like the photo
  // capture times listed under the header, so format their UTC components.
  final start = dive.effectiveEntryTime.toUtc();
  final runtime = dive.runtime;
  final candidate =
      dive.exitTime?.toUtc() ?? (runtime == null ? null : start.add(runtime));
  final end = candidate != null && candidate.isAfter(start) ? candidate : null;
  final date = units.formatDate(start);
  if (end == null) {
    return l10n.media_photoPicker_files_diveGroupStart(
      date,
      units.formatTime(start),
    );
  }
  // An end on a later day carries its own date: a bare time would hide that
  // the dive ran past midnight, and photos from after it would look misplaced.
  final endDate = units.formatDate(end);
  return l10n.media_photoPicker_files_diveGroupWindow(
    date,
    units.formatTime(start),
    endDate == date
        ? units.formatTime(end)
        : '$endDate ${units.formatTime(end)}',
  );
}
