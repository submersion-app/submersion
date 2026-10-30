part of 'shared_library_service.dart';

/// What a sync makes of the owners' member removals (issue #3481).
extension _RemovalSync on SharedLibraryService {
  /// The removal records an owner in [roles] signed, cached for the pages.
  Future<List<MemberRemoval>> _readRemovals(
    SharedLibraryTransport t,
    String libraryId,
    SharedLibraryRoles roles,
  ) async {
    final removals = await validRemovals(
      await t.listRemovals(),
      libraryId,
      roles,
    );
    // Written only on a change: the write reloads every library page.
    if (!const ListEquality<MemberRemoval>().equals(
      removals,
      await _store.removals(libraryId),
    )) {
      await _store.setRemovals(libraryId, removals);
    }
    return removals;
  }

  /// [roles] as their removals leave them, for judging edits: a removal
  /// outweighs an approval the roles may still hold (an older owner app, a
  /// restore race), so a removed member's key counts only until their
  /// removal.
  SharedLibraryRoles _judgedRoles(
    SharedLibraryRoles roles,
    List<MemberRemoval> removals,
  ) => removals.fold(
    roles,
    (acc, r) => acc.removing(r.memberId, at: r.removedAt),
  );

  /// Editors and owners with a genuine card whose key no owner approved
  /// yet: their edits are held, neither applied nor overwritten. Someone
  /// removed is never waiting (a removal wins over a role or a card).
  Map<String, String> _pendingKeysOf(
    List<SharedLibraryMember> members,
    SharedLibraryRoles roles,
    List<MemberRemoval> removals,
  ) {
    final removed = {for (final r in removals) r.memberId};
    return {
      for (final m in members)
        if (m.cardVerified &&
            m.publicKey != null &&
            !removed.contains(m.memberId) &&
            roles.roleOf(m.memberId) != SharedLibraryRole.reader &&
            roles.approvedKeys[m.memberId] != m.publicKey)
          m.memberId: m.publicKey!,
    };
  }
}

/// Whether [json] was signed by [author] with the key they had when an
/// owner removed them, and dated no later than that. The date is the
/// author's own; an owner still reviews the suggestion before it changes
/// anything.
Future<bool> _madeBeforeRemoval(
  Map<String, dynamic> json,
  String author,
  List<MemberRemoval> removals,
  String libraryId,
) async {
  final created = DateTime.tryParse((json['createdAt'] as String?) ?? '');
  if (created == null) return false;
  for (final r in removals) {
    if (r.memberId != author || created.isAfter(r.removedAt)) continue;
    if (await verifySuggestion(json, r.publicKey, libraryId: libraryId)) {
      return true;
    }
  }
  return false;
}
