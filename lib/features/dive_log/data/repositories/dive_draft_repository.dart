import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// Draft dives (issue #637): a dive marked at the site with its entry and
/// exit times and positions, waiting for its dive computer readings.
///
/// A draft really happened, so it counts for no-fly and surface interval;
/// it stays out of totals and numbering until a download or Apple Health
/// workout fills it, or the diver marks it complete. Kept apart from
/// [DiveRepository] so that file does not grow; every write goes through
/// it, so sync and change ticks behave as for any dive.
class DiveDraftRepository {
  DiveDraftRepository({DiveRepository? dives})
    : _dives = dives ?? DiveRepository();

  final DiveRepository _dives;

  /// How far a plan's start may sit from the "Entered water" tap and still
  /// become the draft.
  static const planAdoptionWindow = Duration(hours: 2);

  /// Marks [diverId] in the water at [entryTime], wall clock flagged UTC.
  ///
  /// A plan of the same diver starting within [planAdoptionWindow] of the
  /// tap on the same day becomes the draft, keeping its site, tanks and
  /// buddies, so one real dive never shows twice and a download has a
  /// single candidate to fill. Otherwise a new dive is created.
  Future<Dive> createDraft({
    required String diverId,
    required DateTime entryTime,
    GeoPoint? entryLocation,
  }) async {
    final planId = await findPlanToAdopt(
      diverId: diverId,
      entryTime: entryTime,
    );
    if (planId != null) {
      final plan = await _dives.getDiveById(planId);
      if (plan != null) {
        // The plan's planned end is a guess; the draft is open until the
        // diver surfaces.
        final draft = plan.copyWith(
          isPlanned: false,
          isDraft: true,
          dateTime: entryTime,
          entryTime: entryTime,
          clearExitTime: true,
          clearRuntime: true,
        );
        await _dives.updateDive(draft);
        // updateDive leaves the position pair alone; this fills it only
        // where the plan has none.
        if (entryLocation != null) {
          await _dives.setDiveGps(
            planId,
            entryLatitude: entryLocation.latitude,
            entryLongitude: entryLocation.longitude,
          );
        }
        return (await _dives.getDiveById(planId)) ?? draft;
      }
    }
    return _dives.createDive(
      Dive(
        id: '',
        diverId: diverId,
        dateTime: entryTime,
        entryTime: entryTime,
        entryLocation: entryLocation,
        isDraft: true,
      ),
    );
  }

  /// The plan a tap at [entryTime] would adopt, or null: an unfilled plan of
  /// [diverId] whose start is on the tap's own wall-clock day and within
  /// [planAdoptionWindow] of it. The nearest wins; a tie goes to the earlier
  /// plan. A dive mirrored from a buddy's logged dive is planned but already
  /// happened (see diveUndivedSql), so it is never taken over.
  Future<String?> findPlanToAdopt({
    required String diverId,
    required DateTime entryTime,
  }) async {
    final plans = await _dives.getPlannedDives(diverId: diverId);
    String? best;
    Duration? bestGap;
    DateTime? bestStart;
    for (final plan in plans) {
      final start = plan.entryTime ?? plan.dateTime;
      if (!_sameDay(start, entryTime)) continue;
      final gap = start.difference(entryTime).abs();
      if (gap > planAdoptionWindow) continue;
      final times = await _dives.getDiveTimes(plan.id);
      if (times == null || !times.isUndivedPlan) continue;
      final better =
          bestGap == null ||
          gap < bestGap ||
          (gap == bestGap && start.isBefore(bestStart!));
      if (better) {
        best = plan.id;
        bestGap = gap;
        bestStart = start;
      }
    }
    return best;
  }

  /// Marks the draft [diveId] surfaced at [exitTime], wall clock flagged UTC.
  /// It stays a draft until it is filled or marked complete.
  Future<void> closeDraft(
    String diveId, {
    required DateTime exitTime,
    GeoPoint? exitLocation,
  }) async {
    final draft = await _requireDraft(diveId);
    await _dives.updateDive(draft.copyWith(exitTime: exitTime));
    // updateDive leaves the position pair alone; this fills it only where
    // the draft has none.
    if (exitLocation != null) {
      await _dives.setDiveGps(
        diveId,
        exitLatitude: exitLocation.latitude,
        exitLongitude: exitLocation.longitude,
      );
    }
  }

  /// The draft [diverId] is in the water on: no exit yet, newest entry
  /// first. Null when there is none. With no diver, the newest open draft
  /// on this device, whoever's it is: the dive the marks act on.
  Future<Dive?> openDraftFor(String? diverId) async {
    final drafts = await getDrafts(diverId: diverId);
    for (final draft in drafts) {
      if (draft.exitTime == null) return draft;
    }
    return null;
  }

  /// Every draft of [diverId] (all divers when null), newest entry first.
  Future<List<Dive>> getDrafts({String? diverId}) =>
      _dives.getDraftDives(diverId: diverId);

  /// Makes the plan or draft [diveId] an ordinary logged dive with the next
  /// free number. See [DiveRepository.promoteToLoggedDive].
  Future<String> promoteToLoggedDive(
    String diveId, {
    DateTime? actualDateTime,
  }) => _dives.promoteToLoggedDive(diveId, actualDateTime: actualDateTime);

  /// Turns the draft [diveId] into a hand-added dive that will never be
  /// downloaded (a lost computer, say): its times and everything the diver
  /// typed stay, and it takes the next free number.
  Future<void> markDraftComplete(String diveId) async {
    await _requireDraft(diveId);
    await _dives.promoteToLoggedDive(diveId);
  }

  Future<Dive> _requireDraft(String diveId) async {
    final dive = await _dives.getDiveById(diveId);
    if (dive == null || !dive.isDraft) {
      throw StateError('Dive $diveId is not a draft');
    }
    return dive;
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
