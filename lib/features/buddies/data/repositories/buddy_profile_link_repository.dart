import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

/// Why a buddy-to-profile link was refused.
enum BuddyLinkRefusal {
  /// The buddy would link to the profile that owns it.
  self,

  /// Another buddy in the same owner's list already links to that profile.
  taken,
}

/// Thrown by [BuddyProfileLinkRepository.assertLinkAllowed].
class BuddyLinkRefused implements Exception {
  final BuddyLinkRefusal reason;

  /// The buddy holding the link when [reason] is [BuddyLinkRefusal.taken].
  final Buddy? existingBuddy;

  const BuddyLinkRefused(this.reason, {this.existingBuddy});

  @override
  String toString() => 'BuddyLinkRefused($reason)';
}

/// Links between buddy records and the local diver profiles they are
/// (issue #2002). The rules live here, not in the schema: at most one buddy
/// per (owner, linked profile), and never a link to the buddy's own owner.
class BuddyProfileLinkRepository {
  final BuddyRepository _buddies;
  final DiverRepository _divers;

  BuddyProfileLinkRepository({
    required BuddyRepository buddies,
    required DiverRepository divers,
  }) : _buddies = buddies,
       _divers = divers;

  /// Throws [BuddyLinkRefused] when [linkedDiverId] may not be set on a buddy
  /// owned by [ownerDiverId]. Pass [buddyId] when re-saving an existing
  /// buddy so its own current link does not count as taken.
  Future<void> assertLinkAllowed({
    required String? ownerDiverId,
    required String linkedDiverId,
    String? buddyId,
  }) async {
    if (ownerDiverId != null && ownerDiverId == linkedDiverId) {
      throw const BuddyLinkRefused(BuddyLinkRefusal.self);
    }
    final holder = await _holderOf(
      ownerDiverId: ownerDiverId,
      linkedDiverId: linkedDiverId,
    );
    if (holder != null && holder.id != buddyId) {
      throw BuddyLinkRefused(BuddyLinkRefusal.taken, existingBuddy: holder);
    }
  }

  /// The buddy in [ownerDiverId]'s list that links to [linkedDiverId], or
  /// null when there is none.
  Future<Buddy?> linkedBuddyFor({
    required String ownerDiverId,
    required String linkedDiverId,
  }) => _holderOf(ownerDiverId: ownerDiverId, linkedDiverId: linkedDiverId);

  /// The one other local profile whose trimmed, case-folded name equals
  /// [name] or whose email equals [email]. Null when none or several match,
  /// when the match is the owner, or when the owner's list already links it.
  Future<Diver?> suggestProfileFor({
    required String? ownerDiverId,
    required String name,
    String? email,
  }) async {
    final wantedName = _fold(name);
    final wantedEmail = _fold(email ?? '');
    if (wantedName.isEmpty && wantedEmail.isEmpty) return null;
    final candidates = <Diver>[];
    for (final diver in await _divers.getAllDivers()) {
      if (diver.id == ownerDiverId) continue;
      final nameHit = wantedName.isNotEmpty && _fold(diver.name) == wantedName;
      final emailHit =
          wantedEmail.isNotEmpty && _fold(diver.email ?? '') == wantedEmail;
      if (nameHit || emailHit) candidates.add(diver);
    }
    if (candidates.length != 1) return null;
    final match = candidates.single;
    final holder = await _holderOf(
      ownerDiverId: ownerDiverId,
      linkedDiverId: match.id,
    );
    return holder == null ? match : null;
  }

  /// The buddy in [ownerDiverId]'s list that is [linkedDiverId]. An unlinked
  /// buddy of the same trimmed name is adopted and linked, since the owner
  /// has been logging dives with that person by hand; otherwise one is
  /// created from the profile's name, email, phone and photo.
  Future<Buddy> ensureReciprocalBuddy({
    required String ownerDiverId,
    required String linkedDiverId,
  }) async {
    final existing = await _holderOf(
      ownerDiverId: ownerDiverId,
      linkedDiverId: linkedDiverId,
    );
    if (existing != null) return existing;
    final profile = await _divers.getDiverById(linkedDiverId);
    if (profile == null) {
      throw StateError('Diver $linkedDiverId does not exist');
    }
    final wanted = profile.name.trim();
    for (final candidate in await _buddies.getAllBuddies(
      diverId: ownerDiverId,
    )) {
      // Only a buddy free to be linked: one that already names another
      // profile is a different person with the same name.
      if (candidate.linkedDiverId != null) continue;
      if (candidate.name.trim() != wanted) continue;
      final adopted = candidate.copyWith(
        linkedDiverId: linkedDiverId,
        updatedAt: DateTime.now(),
      );
      await _buddies.updateBuddy(adopted);
      return adopted;
    }
    final now = DateTime.now();
    return _buddies.createBuddy(
      Buddy(
        id: '',
        diverId: ownerDiverId,
        linkedDiverId: linkedDiverId,
        name: profile.name,
        email: profile.email,
        phone: profile.phone,
        photo: profile.photo,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  /// [BuddyRepository.getAllBuddies] with a null owner returns every buddy,
  /// so the owner-less (legacy) list is filtered here to owner-less rows.
  Future<Buddy?> _holderOf({
    required String? ownerDiverId,
    required String linkedDiverId,
  }) async {
    final list = await _buddies.getAllBuddies(diverId: ownerDiverId);
    for (final buddy in list) {
      if (buddy.linkedDiverId != linkedDiverId) continue;
      if (ownerDiverId == null && buddy.diverId != null) continue;
      return buddy;
    }
    return null;
  }

  static String _fold(String value) => value.trim().toLowerCase();
}
