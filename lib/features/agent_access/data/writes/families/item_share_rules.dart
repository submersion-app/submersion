import 'package:drift/drift.dart' show Variable;

import 'package:submersion/core/data/visibility/item_sharing.dart';
import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';

/// Who a trip or a site is shared with by name, and which profiles hide it
/// from themselves, as the share field and the hide action keep them.
const shareRelations = {
  'shared_with': RelationSpec(refEntity: 'divers'),
  'hidden_for': RelationSpec(refEntity: 'divers'),
};

/// What the tool description says about [shareRelations].
const shareNote =
    'shared_with names the profiles it is shared with, beside is_shared for '
    'everyone; hidden_for names the profiles it is shared with that hide it '
    'from themselves.';

({String table, String column}) _hides(SharedItemKind kind) => switch (kind) {
  SharedItemKind.trip => (table: 'trip_hides', column: 'trip_id'),
  SharedItemKind.site => (table: 'site_hides', column: 'site_id'),
};

/// The ids [relation] of item [id] holds now.
Future<Set<String>> shareRelation(
  RecordRepositories r,
  SharedItemKind kind,
  String id,
  String relation,
) async {
  if (relation == 'shared_with') {
    return r.itemShares.storedProfileIds(kind, id);
  }
  final (:table, :column) = _hides(kind);
  final rows = await r.db
      .customSelect(
        'SELECT diver_id FROM $table WHERE $column = ?',
        variables: [Variable.withString(id)],
      )
      .get();
  return {for (final row in rows) row.read<String>('diver_id')};
}

/// Why [check]'s share or hide changes cannot happen, or null. Only the
/// owner shares an item, never with itself, and not one a shared site
/// library holds or one shared with everyone; a profile hides only an item
/// shared with it.
Future<PlanBlock?> shareProblem(
  RecordRepositories r,
  SharedItemKind kind,
  WriteCheck check, {
  required bool everyone,
  bool library = false,
}) async {
  final shares = check.relations['shared_with'];
  final hides = check.relations['hidden_for'];
  if ((shares == null || shares.isEmpty) && (hides == null || hides.isEmpty)) {
    return null;
  }
  final owner = check.ownerId;
  if (library) {
    return const PlanBlock(
      BlockReason.notPermitted,
      'A shared site library site follows its library; it is not shared or '
      'hidden one by one.',
    );
  }
  if (owner == null) {
    return const PlanBlock(
      BlockReason.notPermitted,
      'shared_with: an item with no owner has no one to share it.',
    );
  }
  if (shares != null && !shares.isEmpty) {
    if (shares.add.contains(owner)) {
      return const PlanBlock(
        BlockReason.invalidValue,
        'shared_with: an item is its owner\'s already.',
      );
    }
    if (everyone) {
      return const PlanBlock(
        BlockReason.invalidValue,
        'shared_with: it is shared with everyone; clear is_shared to name '
        'profiles.',
      );
    }
  }
  final sharedWith = {
    ...(await shareRelation(
      r,
      kind,
      check.id!,
      'shared_with',
    )).difference(shares?.remove ?? const {}),
    ...?shares?.add,
  };
  for (final diverId in hides?.add ?? const <String>{}) {
    if (!canHideSharedItem(
      ownerId: owner,
      isShared: everyone || sharedWith.contains(diverId),
      activeDiverId: diverId,
    )) {
      return PlanBlock(
        BlockReason.invalidValue,
        'hidden_for: $diverId hides only an item shared with it, never its '
        'own.',
      );
    }
  }
  return null;
}

/// Writes [update]'s share and hide changes to item [id] for its owner
/// [ownerId]; [everyone] is the item's flag as the update leaves it.
Future<void> applyShares(
  RecordRepositories r,
  SharedItemKind kind,
  String id,
  String? ownerId,
  RecordUpdate update, {
  required bool everyone,
}) async {
  if (update.relations['shared_with'] case final shares? when !shares.isEmpty) {
    final now = await shareRelation(r, kind, id, 'shared_with');
    final shared = await r.itemShares.setSharing(
      kind,
      id,
      ItemSharing(
        everyone: everyone,
        profileIds: {...now.difference(shares.remove), ...shares.add},
      ),
      actingDiverId: ownerId,
    );
    if (!shared &&
        (now.length - shares.remove.length + shares.add.length) > 0) {
      throw AgentToolException(
        AgentToolErrorCode.writeRefused,
        'The sharing of $id could not be changed.',
        details: {'id': id},
      );
    }
  }
  final hides = update.relations['hidden_for'];
  for (final diverId in hides?.add ?? const <String>{}) {
    if (!await r.profileHides.hide(kind, id, diverId)) {
      throw AgentToolException(
        AgentToolErrorCode.writeRefused,
        '$id could not be hidden for $diverId.',
        details: {'id': id, 'diver_id': diverId},
      );
    }
  }
  for (final diverId in hides?.remove ?? const <String>{}) {
    await r.profileHides.unhide(kind, id, diverId);
  }
}
