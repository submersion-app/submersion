import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/trips/data/repositories/side_trip_repository.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The delete confirmation lines about side trips for deleting [tripIds]
/// (issue #3658): how many side trips, every profile's, become trips of
/// their own, and where a deleted side trip's dives go. A trip deleted with
/// its larger trip is neither. A larger trip [diverId] cannot see is not
/// named.
///
/// The lines only inform the confirmation, so a failed read leaves them out
/// rather than blocking the delete.
Future<List<String>> sideTripDeleteLines(
  AppLocalizations l10n,
  SideTripRepository repository,
  List<String> tripIds, {
  String? diverId,
}) async {
  try {
    return await _lines(l10n, repository, tripIds, diverId: diverId);
  } catch (e, stackTrace) {
    _log.warning(
      'Could not read the side trips of trips $tripIds',
      error: e,
      stackTrace: stackTrace,
    );
    return const [];
  }
}

const _log = LoggerService('SideTripDeleteLines');

Future<List<String>> _lines(
  AppLocalizations l10n,
  SideTripRepository repository,
  List<String> tripIds, {
  String? diverId,
}) async {
  final deleting = tripIds.toSet();
  var freed = 0;
  final parentNames = <String?>[];
  for (final id in deleting) {
    final sideTrips = await repository.getSideTrips(id);
    freed += sideTrips.where((t) => !deleting.contains(t.id)).length;
    final parent = await repository.getParentTrip(id);
    if (parent == null || deleting.contains(parent.id)) continue;
    final visible = await repository.getParentTrip(id, diverId: diverId);
    parentNames.add(visible?.name);
  }
  final single = deleting.length == 1;
  final singleParent = parentNames.length == 1 ? parentNames.single : null;
  return [
    if (freed > 0)
      single
          ? l10n.trips_delete_sideTripsStandalone(freed)
          : l10n.trips_bulkDelete_sideTripsStandalone(freed),
    if (parentNames.isNotEmpty)
      single && singleParent != null
          ? l10n.trips_delete_divesReturnToParent(singleParent)
          : l10n.trips_bulkDelete_divesReturnToParents,
  ];
}
