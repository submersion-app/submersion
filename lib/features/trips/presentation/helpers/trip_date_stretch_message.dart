import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/trips/domain/services/trip_date_stretch.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// What to tell the diver about [stretches] (issue #3351): the dive's own
/// trip and its new dates, or null when that trip did not move. A larger trip
/// that moved along with its side trip goes unnamed.
String? tripDateStretchMessage(
  AppLocalizations l10n,
  UnitFormatter units,
  Iterable<TripDateStretch> stretches,
) {
  final stretch = ownStretch(stretches);
  if (stretch == null) return null;
  return l10n.trips_dateStretch_message(
    stretch.tripName,
    units.formatDateRange(stretch.start, stretch.end, l10n: l10n),
  );
}
