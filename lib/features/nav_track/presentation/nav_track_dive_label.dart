import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// How a route names the dive it is linked to: `Dive #<n>` once [dive] has
/// loaded with a number, otherwise `Dive <id>` (still resolving, missing, or
/// never numbered). The routes list chip and the detail page's link card
/// both name the dive here, so they cannot disagree about the same dive.
String navTrackDiveLabel(AppLocalizations l10n, String diveId, Dive? dive) {
  final number = dive?.diveNumber;
  return number != null
      ? l10n.navTrack_common_diveNumber(number.toString())
      : l10n.navTrack_common_diveById(diveId);
}
