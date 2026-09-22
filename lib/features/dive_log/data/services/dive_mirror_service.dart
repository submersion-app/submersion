import 'package:uuid/uuid.dart';

import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_profile_link_repository.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/dive_mirror_fields.dart';
import 'package:submersion/features/dive_roles/data/repositories/dive_role_repository.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_types/data/repositories/dive_type_repository.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';

/// A linked buddy on a dive whose profile has no sibling of it yet.
typedef MirrorCandidate = ({Buddy buddy, Diver diver});

/// What one mirror action wrote, enough to undo it.
class MirrorOutcome {
  final String sourceDiveId;
  final String outingId;

  /// True when this action stamped the outing id on the source, so undo
  /// clears it again.
  final bool mintedOutingId;
  final List<String> createdDiveIds;

  /// The site this action flipped to shared so the siblings could reference
  /// it, or null when the site was already shared (or there is no site).
  /// Undo makes it private again.
  final String? sharedSiteId;

  const MirrorOutcome({
    required this.sourceDiveId,
    required this.outingId,
    required this.mintedOutingId,
    required this.createdDiveIds,
    this.sharedSiteId,
  });
}

/// Logs a dive into the profiles of its linked buddies as planned sibling
/// dives sharing one outing id (issue #2002).
class DiveMirrorService {
  final DiveRepository _dives;
  final BuddyRepository _buddies;
  final BuddyProfileLinkRepository _links;
  final DiverRepository _divers;
  final SiteRepository _sites;
  final TripRepository _trips;
  final DiveCenterRepository _centers;
  final DiveTypeRepository _types;
  final TagRepository _tags;
  final DiveRoleRepository _roles;
  final _uuid = const Uuid();

  DiveMirrorService({
    DiveRepository? dives,
    BuddyRepository? buddies,
    BuddyProfileLinkRepository? links,
    DiverRepository? divers,
    SiteRepository? sites,
    TripRepository? trips,
    DiveCenterRepository? centers,
    DiveTypeRepository? types,
    TagRepository? tags,
    DiveRoleRepository? roles,
  }) : _dives = dives ?? DiveRepository(),
       _buddies = buddies ?? BuddyRepository(),
       _divers = divers ?? DiverRepository(),
       _sites = sites ?? SiteRepository(),
       _trips = trips ?? TripRepository(),
       _centers = centers ?? DiveCenterRepository(),
       _types = types ?? DiveTypeRepository(),
       _tags = tags ?? TagRepository(),
       _roles = roles ?? DiveRoleRepository(),
       _links =
           links ??
           BuddyProfileLinkRepository(
             buddies: buddies ?? BuddyRepository(),
             divers: divers ?? DiverRepository(),
           );

  /// Linked buddies on [diveId] whose profile owns no dive in its outing.
  Future<List<MirrorCandidate>> candidates(String diveId) async {
    final dive = await _dives.getDiveById(diveId);
    if (dive == null) return const [];
    final siblingOwners = <String>{};
    final outingId = dive.outingId;
    if (outingId != null) {
      for (final d in await _dives.getDivesByOutingId(outingId)) {
        final owner = d.diverId;
        if (owner != null) siblingOwners.add(owner);
      }
    }
    final result = <MirrorCandidate>[];
    for (final bwr in await _buddies.getBuddiesForDive(diveId)) {
      final linked = bwr.buddy.linkedDiverId;
      if (linked == null || linked == dive.diverId) continue;
      if (siblingOwners.contains(linked)) continue;
      final diver = await _divers.getDiverById(linked);
      if (diver == null) continue;
      result.add((buddy: bwr.buddy, diver: diver));
    }
    return result;
  }

  /// Creates one planned sibling per target profile. Targets that already
  /// own a dive in the outing are skipped, so the call is idempotent.
  Future<MirrorOutcome> mirror({
    required String sourceDiveId,
    required List<String> targetDiverIds,
  }) async {
    final db = DatabaseService.instance.database;
    return db.transaction(() async {
      final source = await _dives.getDiveById(sourceDiveId);
      if (source == null) {
        throw StateError('Source dive $sourceDiveId does not exist');
      }
      final minted = source.outingId == null;
      final outingId = source.outingId ?? _uuid.v4();
      if (minted) {
        await _dives.updateDive(source.copyWith(outingId: outingId));
      }
      // Whether this action is the one that shares the site, decided before
      // the first sibling flips the flag so undo can tell it apart from a
      // site the diver had already shared.
      final siteId = source.site?.id;
      final site = siteId == null ? null : await _sites.getSiteById(siteId);
      final flippedSiteId = site != null && !site.isShared ? site.id : null;

      final existingOwners = <String>{
        for (final d in await _dives.getDivesByOutingId(outingId))
          if (d.diverId != null) d.diverId!,
      };
      final sourceBuddies = await _buddies.getBuddiesForDive(sourceDiveId);
      final created = <String>[];
      for (final target in targetDiverIds) {
        if (existingOwners.contains(target)) continue;
        final id = await _createSibling(
          source: source,
          sourceBuddies: sourceBuddies,
          targetDiverId: target,
          outingId: outingId,
        );
        existingOwners.add(target);
        created.add(id);
      }
      return MirrorOutcome(
        sourceDiveId: sourceDiveId,
        outingId: outingId,
        mintedOutingId: minted,
        createdDiveIds: created,
        sharedSiteId: created.isEmpty ? null : flippedSiteId,
      );
    });
  }

  /// Deletes the siblings this outcome created, clears the outing id from
  /// the source when this action minted it, and makes the site private
  /// again when this action shared it. Buddy records stay.
  Future<void> undo(MirrorOutcome outcome) async {
    final db = DatabaseService.instance.database;
    await db.transaction(() async {
      if (outcome.createdDiveIds.isNotEmpty) {
        await _dives.bulkDeleteDives(outcome.createdDiveIds);
      }
      await _unshareSite(outcome.sharedSiteId);
      if (outcome.mintedOutingId) {
        final source = await _dives.getDiveById(outcome.sourceDiveId);
        if (source != null) {
          await _dives.updateDive(source.copyWith(clearOutingId: true));
        }
      }
    });
  }

  Future<String> _createSibling({
    required Dive source,
    required List<BuddyWithRole> sourceBuddies,
    required String targetDiverId,
    required String outingId,
  }) async {
    final sourceOwner = source.diverId;
    final sourceRoleId = source.diverRoleId ?? DiveRole.buddyId;

    // The target's own role: what its buddy held on the source.
    String? targetRoleId;
    for (final bwr in sourceBuddies) {
      if (bwr.buddy.linkedDiverId == targetDiverId) {
        targetRoleId = bwr.role.id;
      }
    }

    final dive = mirroredDiveFrom(
      source,
      targetDiverId: targetDiverId,
      outingId: outingId,
      includeSite: await _shareSite(source.site?.id),
      tripId: await _sharedTripId(source.tripId ?? source.trip?.id),
      includeDiveCenter: await _centerIsVisible(source.diveCenter?.id),
      diveTypeIds: await _resolveTypeIds(source.diveTypeIds, targetDiverId),
      tags: await _resolveTags(source.tags, targetDiverId),
      diverRoleId: targetRoleId == null
          ? null
          : (await _roleFor(targetRoleId, targetDiverId)).id,
    );
    final created = await _dives.createDive(dive);

    final members = <BuddyWithRole>[];
    if (sourceOwner != null) {
      final me = await _links.ensureReciprocalBuddy(
        ownerDiverId: targetDiverId,
        linkedDiverId: sourceOwner,
      );
      members.add(
        BuddyWithRole(
          buddy: me,
          role: await _roleFor(sourceRoleId, targetDiverId),
        ),
      );
    }
    for (final bwr in sourceBuddies) {
      if (bwr.buddy.linkedDiverId == targetDiverId) continue;
      final buddy = await _buddyInList(bwr.buddy, targetDiverId);
      members.add(
        BuddyWithRole(
          buddy: buddy,
          role: await _roleFor(bwr.role.id, targetDiverId),
        ),
      );
    }
    await _buddies.setBuddiesForDive(created.id, members);
    return created.id;
  }

  /// Reverses the share this mirror performed, unless another profile's
  /// dive still references the site: those dives are the reason the flag
  /// exists, and the siblings this undo deleted are already gone.
  Future<void> _unshareSite(String? siteId) async {
    if (siteId == null) return;
    final site = await _sites.getSiteById(siteId);
    if (site == null || !site.isShared) return;
    for (final dive in await _dives.getDivesForSite(siteId)) {
      if (dive.diverId != null && dive.diverId != site.diverId) return;
    }
    await _sites.setShared(siteId, false);
  }

  /// A site two profiles hold dives at is shared; flip the flag if needed.
  /// Returns whether the sibling should reference the site at all.
  Future<bool> _shareSite(String? siteId) async {
    if (siteId == null) return false;
    final site = await _sites.getSiteById(siteId);
    if (site == null) return false;
    if (!site.isShared) await _sites.setShared(siteId, true);
    return true;
  }

  Future<String?> _sharedTripId(String? tripId) async {
    if (tripId == null) return null;
    final trip = await _trips.getTripById(tripId);
    return (trip?.isShared ?? false) ? tripId : null;
  }

  Future<bool> _centerIsVisible(String? centerId) async {
    if (centerId == null) return false;
    final center = await _centers.getDiveCenterById(centerId);
    return center != null && center.diverId == null;
  }

  Future<List<String>> _resolveTypeIds(
    List<String> sourceIds,
    String targetDiverId,
  ) async {
    if (sourceIds.isEmpty) return const [];
    final all = await _types.getAllDiveTypes();
    final visible = await _types.getAllDiveTypes(diverId: targetDiverId);
    final byName = {for (final t in visible) _fold(t.name): t};
    final result = <String>[];
    for (final id in sourceIds) {
      final type = all.where((t) => t.id == id).firstOrNull;
      if (type == null) continue;
      if (type.isBuiltIn) {
        result.add(id);
        continue;
      }
      final match = byName[_fold(type.name)];
      if (match != null) result.add(match.id);
    }
    return result;
  }

  Future<List<Tag>> _resolveTags(
    List<Tag> sourceTags,
    String targetDiverId,
  ) async {
    if (sourceTags.isEmpty) return const [];
    final visible = await _tags.getAllTags(diverId: targetDiverId);
    final byName = {for (final t in visible) _fold(t.name): t};
    return [for (final tag in sourceTags) ?byName[_fold(tag.name)]];
  }

  /// Built-in roles are shared by id; a custom role is matched by name in
  /// the target's list and falls back to the built-in buddy role.
  Future<DiveRole> _roleFor(String roleId, String targetDiverId) async {
    final visible = await _roles.getAllDiveRoles(diverId: targetDiverId);
    final direct = visible.where((r) => r.id == roleId).firstOrNull;
    if (direct != null && direct.isBuiltIn) return direct;
    final fallback = visible.where((r) => r.id == DiveRole.buddyId).firstOrNull;
    final all = await _roles.getAllDiveRoles();
    final source = all.where((r) => r.id == roleId).firstOrNull;
    if (source == null) return fallback ?? DiveRole.builtInBuddy();
    final byName = visible
        .where((r) => _fold(r.name) == _fold(source.name))
        .firstOrNull;
    return byName ?? fallback ?? DiveRole.builtInBuddy();
  }

  /// The buddy in the target's list that is [sourceBuddy]: matched by link,
  /// then by exact trimmed name, else created with the same details.
  Future<Buddy> _buddyInList(Buddy sourceBuddy, String targetDiverId) async {
    final linked = sourceBuddy.linkedDiverId;
    if (linked != null) {
      return _links.ensureReciprocalBuddy(
        ownerDiverId: targetDiverId,
        linkedDiverId: linked,
      );
    }
    final list = await _buddies.getAllBuddies(diverId: targetDiverId);
    final wanted = sourceBuddy.name.trim();
    for (final b in list) {
      if (b.name.trim() == wanted) return b;
    }
    final now = DateTime.now();
    return _buddies.createBuddy(
      Buddy(
        id: '',
        diverId: targetDiverId,
        name: sourceBuddy.name,
        email: sourceBuddy.email,
        phone: sourceBuddy.phone,
        photo: sourceBuddy.photo,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  static String _fold(String value) => value.trim().toLowerCase();
}
