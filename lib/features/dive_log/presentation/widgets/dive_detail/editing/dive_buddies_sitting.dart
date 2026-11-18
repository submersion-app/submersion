import 'package:flutter/foundation.dart';

import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/domain/entities/legacy_buddy_conversion.dart';
import 'package:submersion/features/buddies/presentation/providers/legacy_buddy_conversion_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_roles/presentation/providers/dive_role_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/presentation/helpers/gear_expansion.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/sitting_list.dart';

const _log = LoggerService('DiveBuddiesSitting');

final String _buddiesCardId = DiveDetailSectionId.buddies.name;

/// Who is on a dive with which roles, for comparing two buddy lists: the
/// order carries no meaning, and a buddy's own details changing elsewhere
/// is not a change of the dive.
Set<String> _identities(List<BuddyWithRole> buddies) => {
  for (final b in buddies) '${b.buddy.id}|${b.roleIds.join(',')}',
};

/// The dive's buddies with their roles, edited on the Buddies card.
///
/// Written at Save over the buddies as stored then, not as loaded: a buddy
/// the sitting removed goes, one it added or changed is written, and one
/// linked meanwhile (a sync) that the sitting never saw is kept.
final diveBuddiesList = SittingList<Dive, BuddyWithRole>(
  key: 'buddies',
  cardId: _buddiesCardId,
  read: (dive) => BuddyRepository().getBuddiesForDive(dive.id),
  write: (dive, loaded, current) async {
    final repository = BuddyRepository();
    final now = await repository.getBuddiesForDive(dive.id);
    final loadedIds = {for (final b in loaded) b.buddy.id};
    final currentById = {for (final b in current) b.buddy.id: b};
    final nowIds = {for (final b in now) b.buddy.id};
    await repository.setBuddiesForDive(dive.id, [
      for (final b in now)
        // Kept unless the sitting removed it; the sitting's roles when it
        // has the buddy.
        if (!loadedIds.contains(b.buddy.id) ||
            currentById.containsKey(b.buddy.id))
          currentById[b.buddy.id] ?? b,
      for (final b in current)
        if (!nowIds.contains(b.buddy.id)) b,
    ]);
    // Whether it changed anything is not asked of a dive's rows.
    return null;
  },
  same: (a, b) => setEquals(_identities(a), _identities(b)),
);

/// The held write that claims the unowned buddies a legacy link named: a
/// write of the dive's own buddies, reaching no site.
const String buddyClaimsKey = 'buddies.claims';

/// Holds the claim of [ids], unowned buddies the legacy link named, for
/// Save: there each one the dive still links becomes the diver's, so
/// Cancel leaves it as it was, visible to every profile.
void _holdClaims(EditSession<Dive> session, Set<String> ids, String diverId) {
  if (ids.isEmpty || session.isDisposed || session.isFrozen) return;
  final held = {...?session.recall<Set<String>>(buddyClaimsKey), ...ids};
  session
    ..remember(buddyClaimsKey, held)
    ..holdWrite(buddyClaimsKey, () async {
      final linked = {
        for (final b in diveBuddiesList.current(session) ?? const [])
          b.buddy.id,
      };
      await BuddyRepository().claimUnownedBuddies(
        held.where(linked.contains),
        diverId: diverId,
      );
    });
}

/// The diver's own roles on the dive, edited on the Buddies card.
final diveDiverRoleIdsField = EditField<Dive, List<String>>(
  id: 'diverRoleIds',
  cardId: _buddiesCardId,
  read: (dive) => dive.diverRoleIds,
  write: (dive, roleIds) => dive.copyWith(diverRoleIds: roleIds),
  equals: listEquals,
);

/// Links the dive's legacy free-text buddies in the sitting.
///
/// [plan] asks the diver which names become which buddies (the review
/// sheet), for the dive's diver. New buddies it names are created at
/// once, as records of their own, as a buddy made from the picker is;
/// claiming an unowned one, and joining them all to the dive, are held
/// until Save, so Cancel leaves the new ones in the diver's list with no
/// link to this dive and an unowned one unowned. The dive's legacy text is left as the immediate path leaves it.
/// Tracked.
Future<void> linkLegacyBuddiesInSitting(
  EditSession<Dive> session, {
  required ProviderRead read,
  required String newBuddyNote,
  required Future<ConversionPlan?> Function(String diverId) plan,
}) {
  final work = _linkLegacy(
    session,
    read: read,
    newBuddyNote: newBuddyNote,
    plan: plan,
  );
  session.track(work);
  return work;
}

Future<void> _linkLegacy(
  EditSession<Dive> session, {
  required ProviderRead read,
  required String newBuddyNote,
  required Future<ConversionPlan?> Function(String diverId) plan,
}) async {
  bool gone() => session.isDisposed || session.isFrozen;
  final service = read(legacyBuddyConversionServiceProvider);
  final diverId =
      session.stored.diverId ??
      await read(validatedCurrentDiverIdProvider.future);
  if (diverId == null || gone()) return;
  final reviewed = await plan(diverId);
  if (reviewed == null || reviewed.isEmpty || gone()) return;
  try {
    final (:links, :toClaim) = await service.resolveForSitting(
      reviewed,
      diverId: diverId,
      newBuddyNote: newBuddyNote,
    );
    final roles = await read(diveRoleMapProvider.future);
    final repository = BuddyRepository();
    final added = <BuddyWithRole>[];
    for (final link in links) {
      final buddy = await repository.getBuddyById(link.buddyId);
      if (buddy == null) continue;
      added.add(
        BuddyWithRole(
          buddy: buddy,
          roles: [roles[link.roleId] ?? DiveRole.synthetic(link.roleId)],
        ),
      );
    }
    if (gone()) return;
    _holdClaims(session, toClaim, diverId);
    final current = diveBuddiesList.current(session) ?? const [];
    final have = {for (final b in current) b.buddy.id};
    diveBuddiesList.set(session, [
      ...current,
      for (final b in added)
        if (!have.contains(b.buddy.id)) b,
    ]);
  } catch (error, stackTrace) {
    _log.error(
      'Linking legacy buddies in a sitting failed',
      error: error,
      stackTrace: stackTrace,
    );
    rethrow;
  }
}
