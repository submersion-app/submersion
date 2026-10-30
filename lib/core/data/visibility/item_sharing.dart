import 'package:flutter/foundation.dart';

/// Who a trip or dive site is shared with (issue #2151): nobody, every
/// profile ([everyone], the item's `is_shared` flag, which also reaches
/// profiles added later), or the chosen [profileIds] (its share rows). The
/// owner is never one of [profileIds].
///
/// [everyone] wins: a value built with both reads as Everyone, as the
/// stored item does when a sync race leaves it with both.
@immutable
class ItemSharing {
  const ItemSharing({this.everyone = false, Set<String> profileIds = const {}})
    : profileIds = everyone ? const {} : profileIds;

  static const none = ItemSharing();
  static const all = ItemSharing(everyone: true);

  final bool everyone;
  final Set<String> profileIds;

  /// Shared with anyone at all.
  bool get isShared => everyone || profileIds.isNotEmpty;

  /// [diverId] sees the item through this sharing (its owner aside).
  bool reaches(String diverId) => everyone || profileIds.contains(diverId);

  /// Moving to [next] takes the item away from one of [profileIds] (the
  /// profiles other than the owner that exist now) that sees it, which the
  /// owner confirms first. Everyone to every current profile by name takes
  /// it from nobody today, so it is not a narrowing.
  bool narrowsAmong(ItemSharing next, Iterable<String> profileIds) =>
      profileIds.any((id) => reaches(id) && !next.reaches(id));

  /// This sharing without [diverId], the item's owner.
  ItemSharing without(String? diverId) => everyone || diverId == null
      ? this
      : ItemSharing(profileIds: profileIds.difference({diverId}));

  /// This sharing with [other]'s profiles added; nothing is taken away.
  ItemSharing plus(ItemSharing other) => everyone || other.everyone
      ? all
      : ItemSharing(profileIds: {...profileIds, ...other.profileIds});

  @override
  bool operator ==(Object other) =>
      other is ItemSharing &&
      other.everyone == everyone &&
      setEquals(other.profileIds, profileIds);

  @override
  int get hashCode =>
      Object.hash(everyone, Object.hashAllUnordered(profileIds));

  @override
  String toString() =>
      everyone ? 'ItemSharing.all' : 'ItemSharing($profileIds)';
}

/// Whether item [id] is shared with anyone: with everyone (its
/// `is_shared` flag, [everyone]) or with some profile by name
/// ([namedShares], the ids of items that have share rows). The one rule the
/// lists' shared badge and the delete warnings use (issue #2151).
bool isSharedWithAnyone({
  required String id,
  required bool everyone,
  required Set<String> namedShares,
}) => everyone || namedShares.contains(id);
