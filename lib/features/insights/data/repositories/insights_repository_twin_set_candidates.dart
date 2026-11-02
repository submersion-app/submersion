part of 'insights_repository.dart';

/// The cylinders and dives the re-role offer on the Gas page names
/// (issue #3374). Both lists are distinct; [diveIds] are in dive date order.
typedef TwinSetCandidates = ({List<String> tankIds, List<String> diveIds});

/// The finder behind the Gas page's "Mark as twin sets" note (issue #3374),
/// kept beside the repository as a part so the main file does not grow.
extension InsightsRepositoryTwinSetCandidates on InsightsRepository {
  /// Every Back Gas cylinder of [diverId]'s logbook (every diver's when null)
  /// that the retired name-and-size guess counted as a twin set, with the
  /// dives they belong to.
  ///
  /// The whole logbook, not the Insights filter: this is a migration aid,
  /// and a diver who re-roles the cylinders a chart counted wants the ones
  /// the filter hides done too.
  Future<TwinSetCandidates> getTwinSetCandidates({String? diverId}) async {
    try {
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final rows = await _db
          .customSelect(
            '''
        SELECT t.id AS tank_id, d.id AS dive_id
        FROM dive_tanks t JOIN dives d ON d.id = t.dive_id
        WHERE $kTwinSetCandidateFunction(
          t.tank_role, t.tank_name, t.preset_name, t.volume) = 1
        $diverFilter
        ORDER BY d.dive_date_time, t.tank_order, t.rowid
        ''',
            variables: [if (diverId != null) Variable(diverId)],
          )
          .get();
      final tankIds = <String>{};
      final diveIds = <String>{};
      for (final r in rows) {
        tankIds.add(r.read<String>('tank_id'));
        diveIds.add(r.read<String>('dive_id'));
      }
      return (tankIds: tankIds.toList(), diveIds: diveIds.toList());
    } catch (e, stackTrace) {
      _log.error(
        'Failed to find twin set candidates',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
