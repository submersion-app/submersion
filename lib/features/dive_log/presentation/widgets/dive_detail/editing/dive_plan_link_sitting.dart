import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/equipment/presentation/helpers/gear_expansion.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
import 'package:submersion/features/planner/presentation/providers/plan_repository_providers.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

const _log = LoggerService('DivePlanLinkSitting');

/// The held change of the Compare card: the plan linked to the dive.
const String planLinkKey = 'planLink';

/// The plan link the sitting changed, for a closed card to say what Save
/// will do: null while it holds no change.
({String? planId})? heldPlanLinkChange(EditSession<Dive> session) =>
    session.isDisposed || !session.isHeld(planLinkKey)
    ? null
    : sittingPlanLink(session);

/// The links the save changed, as (plan, dive or null), for the planner to
/// adopt once the write is committed (issue #4527, plan 6).
const String planLinkAdoptKey = 'planLink.adopt';

const String _storedKey = 'planLink.stored';
const String _currentKey = 'planLink.current';
const String _repoKey = 'planLink.repo';
const String _failedKey = 'planLink.failed';

/// The plan the sitting has linked to the dive (null for none), or null
/// before the link loads.
({String? planId})? sittingPlanLink(EditSession<Dive> session) {
  if (session.isDisposed) return null;
  final stored = session.recall<({String? planId})>(_storedKey);
  if (stored == null) return null;
  return session.recall<({String? planId})>(_currentKey) ?? stored;
}

/// Reads the plan linked to the dive, once per sitting. Tracked.
void loadDivePlanLink(EditSession<Dive> session, ProviderRead read) {
  if (!session.firstTime(_storedKey)) return;
  session.remember(_repoKey, read(divePlanRepositoryProvider));
  _read(session);
}

/// Reads the linked plan again after a read that failed. Tracked.
Future<void> reloadDivePlanLink(EditSession<Dive> session) =>
    _read(session) ?? Future<void>.value();

/// Whether the last read of the linked plan failed, so the editor can say
/// so and offer to read again.
bool planLinkLoadFailed(EditSession<Dive> session) =>
    !session.isDisposed && session.recall<bool>(_failedKey) == true;

Future<void>? _read(EditSession<Dive> session) {
  final repository = session.recall<DivePlanRepository>(_repoKey);
  if (repository == null || session.isDisposed || session.isFrozen) {
    return null;
  }
  session.remember(_failedKey, null);
  final diveId = session.stored.id;
  final work = () async {
    try {
      final plan = await repository.getPlanByLinkedDiveId(diveId);
      if (session.isDisposed || session.isFrozen) return;
      session.remember(_storedKey, (planId: plan?.id));
    } catch (error, stackTrace) {
      _log.warning(
        'Reading the linked plan for a sitting failed',
        error: error,
        stackTrace: stackTrace,
      );
      if (!session.isDisposed) session.remember(_failedKey, true);
    }
  }();
  session.track(work);
  return work;
}

/// Links [planId] to the dive in the sitting, or none. The stored link
/// releases the held change.
void setPlanLink(EditSession<Dive> session, String? planId) {
  if (session.isDisposed || session.isFrozen) return;
  final stored = session.recall<({String? planId})>(_storedKey);
  final repository = session.recall<DivePlanRepository>(_repoKey);
  if (stored == null || repository == null) return;
  session.remember(_currentKey, (planId: planId));
  if (planId == stored.planId) {
    session.releaseWrite(planLinkKey);
    return;
  }
  session.holdChange(
    planLinkKey,
    cardId: DiveDetailSectionId.diveLab.name,
    write: () => _write(session, repository, from: stored.planId),
  );
}

Future<void> _write(
  EditSession<Dive> session,
  DivePlanRepository repository, {
  required String? from,
}) async {
  final to = sittingPlanLink(session)?.planId;
  final diveId = session.stored.id;
  final adopted = <(String, String?)>[];
  if (to != null) {
    final result = await repository.linkPlanToDive(to, diveId);
    adopted
      ..add((to, diveId))
      ..addAll([for (final id in result.displacedPlanIds) (id, null)]);
  } else if (from != null &&
      (await repository.getPlan(from))?.linkedDiveId == diveId) {
    // Only while the plan is still this dive's: unlinking clears every plan
    // on the plan's dive as it is now, and one a sync moved to another dive
    // is that dive's (issue #4527).
    for (final id in await repository.unlinkPlan(from)) {
      adopted.add((id, null));
    }
  }
  session.remember(planLinkAdoptKey, adopted);
}
