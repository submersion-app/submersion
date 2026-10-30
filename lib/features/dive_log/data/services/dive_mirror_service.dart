import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/visibility/item_sharing.dart';
import 'package:submersion/core/data/visibility/shared_item_policy.dart';
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
import 'package:submersion/features/dive_roles/domain/services/dive_role_set.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_types/data/repositories/dive_type_repository.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/data/repositories/item_shares_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

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

  /// The share rows this action added so the targets could see the site
  /// (issue #2151): one per target profile the site did not reach yet.
  /// Undo deletes each, unless that profile still logs a dive there.
  final List<({String shareId, String diverId})> addedSiteShares;

  /// The site [addedSiteShares] belong to.
  final String? siteId;

  const MirrorOutcome({
    required this.sourceDiveId,
    required this.outingId,
    required this.mintedOutingId,
    required this.createdDiveIds,
    this.addedSiteShares = const [],
    this.siteId,
  });

  List<String> get addedSiteShareIds => [
    for (final s in addedSiteShares) s.shareId,
  ];
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
  final ItemSharesRepository _shares;
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
    ItemSharesRepository? shares,
  }) : _dives = dives ?? DiveRepository(),
       _buddies = buddies ?? BuddyRepository(),
       _divers = divers ?? DiverRepository(),
       _sites = sites ?? SiteRepository(),
       _trips = trips ?? TripRepository(),
       _centers = centers ?? DiveCenterRepository(),
       _types = types ?? DiveTypeRepository(),
       _tags = tags ?? TagRepository(),
       _roles = roles ?? DiveRoleRepository(),
       _shares = shares ?? ItemSharesRepository(),
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
      final existingOwners = <String>{
        for (final d in await _dives.getDivesByOutingId(outingId))
          if (d.diverId != null) d.diverId!,
      };
      final sourceBuddies = await _buddies.getBuddiesForDive(sourceDiveId);
      // The source's site and trip with their sharing, read once for every
      // target: adding one target's share leaves the others' answers alone.
      final items = await _readItems(source);
      final created = <String>[];
      final addedShares = <({String shareId, String diverId})>[];
      for (final target in targetDiverIds) {
        if (existingOwners.contains(target)) continue;
        final id = await _createSibling(
          source: source,
          sourceBuddies: sourceBuddies,
          targetDiverId: target,
          outingId: outingId,
          items: items,
          addedShares: addedShares,
        );
        existingOwners.add(target);
        created.add(id);
      }
      return MirrorOutcome(
        sourceDiveId: sourceDiveId,
        outingId: outingId,
        mintedOutingId: minted,
        createdDiveIds: created,
        addedSiteShares: addedShares,
        siteId: source.site?.id,
      );
    });
  }

  /// Deletes the siblings this outcome created, clears the outing id from
  /// the source when this action minted it, and takes back the site shares
  /// this action added. Buddy records stay.
  Future<void> undo(MirrorOutcome outcome) async {
    final db = DatabaseService.instance.database;
    await db.transaction(() async {
      if (outcome.createdDiveIds.isNotEmpty) {
        await _dives.bulkDeleteDives(outcome.createdDiveIds);
      }
      await _takeBackSiteShares(outcome);
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
    required _SourceItems items,
    required List<({String shareId, String diverId})> addedShares,
  }) async {
    final sourceOwner = source.diverId;
    // The source owner's roles, which become their roles as the target's
    // reciprocal buddy; an owner with none is a plain buddy (issue #1221).
    final sourceRoleIds = source.diverRoleIds.isEmpty
        ? const [DiveRole.buddyId]
        : source.diverRoleIds;

    // The target's own roles: what its buddy held on the source.
    var targetRoleIds = const <String>[];
    for (final bwr in sourceBuddies) {
      if (bwr.buddy.linkedDiverId == targetDiverId) {
        targetRoleIds = bwr.roleIds;
      }
    }

    final dive = mirroredDiveFrom(
      source,
      targetDiverId: targetDiverId,
      outingId: outingId,
      includeSite: await _shareSite(
        items,
        actingDiverId: source.diverId,
        targetDiverId: targetDiverId,
        addedShares: addedShares,
      ),
      tripId: _tripReaching(items, targetDiverId),
      includeDiveCenter: await _centerIsVisible(source.diveCenter?.id),
      diveTypeIds: await _resolveTypeIds(source.diveTypeIds, targetDiverId),
      tags: await _resolveTags(source.tags, targetDiverId),
      diverRoleIds: [
        for (final role in await _rolesFor(targetRoleIds, targetDiverId))
          role.id,
      ],
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
          roles: await _rolesFor(sourceRoleIds, targetDiverId),
        ),
      );
    }
    for (final bwr in sourceBuddies) {
      if (bwr.buddy.linkedDiverId == targetDiverId) continue;
      final buddy = await _buddyInList(bwr.buddy, targetDiverId);
      members.add(
        BuddyWithRole(
          buddy: buddy,
          roles: await _rolesFor(bwr.roleIds, targetDiverId),
        ),
      );
    }
    await _buddies.setBuddiesForDive(created.id, members);
    return created.id;
  }

  /// Deletes the site shares this mirror added, except one whose profile
  /// still logs a dive at the site: those dives are the reason it exists,
  /// and the siblings this undo deleted are already gone.
  Future<void> _takeBackSiteShares(MirrorOutcome outcome) async {
    final siteId = outcome.siteId;
    if (siteId == null || outcome.addedSiteShares.isEmpty) return;
    final stillThere = {
      for (final dive in await _dives.getDivesForSite(siteId)) ?dive.diverId,
    };
    await _shares.dropShareRows(SharedItemKind.site, [
      for (final s in outcome.addedSiteShares)
        if (!stillThere.contains(s.diverId)) s.shareId,
    ]);
  }

  /// Whether the sibling should reference the site. A site that reaches
  /// [targetDiverId] already (shared with everyone or by name, or its own)
  /// is referenced as it is, as is a shared site library site, which its
  /// membership governs. Otherwise the site's owner, [actingDiverId] here,
  /// shares it with [targetDiverId] alone (issue #2151), recorded in
  /// [addedShares] for undo; a site private to another profile, whose
  /// sharing only its owner changes (#2594), is left off.
  Future<bool> _shareSite(
    _SourceItems items, {
    required String? actingDiverId,
    required String targetDiverId,
    required List<({String shareId, String diverId})> addedShares,
  }) async {
    final site = items.site;
    if (site == null) return false;
    if (site.isLibrarySite || site.diverId == targetDiverId) return true;
    if (items.siteSharing.reaches(targetDiverId)) return true;
    final shareId = await _shares.shareWith(
      SharedItemKind.site,
      site.id,
      targetDiverId,
      actingDiverId: actingDiverId,
    );
    if (shareId == null) return false;
    addedShares.add((shareId: shareId, diverId: targetDiverId));
    return true;
  }

  /// The trip for the sibling: only one that reaches [targetDiverId] (its
  /// own, or shared with everyone or with it by name, issue #2151). The
  /// mirror never changes a trip's sharing.
  String? _tripReaching(_SourceItems items, String targetDiverId) {
    final trip = items.trip;
    if (trip == null) return null;
    return trip.diverId == targetDiverId ||
            items.tripSharing.reaches(targetDiverId)
        ? trip.id
        : null;
  }

  /// [source]'s site and trip, with who each is shared with.
  Future<_SourceItems> _readItems(Dive source) async {
    final siteId = source.site?.id;
    final site = siteId == null ? null : await _sites.getSiteById(siteId);
    final tripId = source.tripId ?? source.trip?.id;
    final trip = tripId == null ? null : await _trips.getTripById(tripId);
    return (
      site: site,
      siteSharing: site == null
          ? ItemSharing.none
          : await _shares.sharingOf(SharedItemKind.site, site.id),
      trip: trip,
      tripSharing: trip == null
          ? ItemSharing.none
          : await _shares.sharingOf(SharedItemKind.trip, trip.id),
    );
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

  /// [roleIds] mapped one by one through [_roleFor], deduped (two custom
  /// roles can both fall back to Buddy) and in DiveRoleSet order (#1221).
  Future<List<DiveRole>> _rolesFor(
    List<String> roleIds,
    String targetDiverId,
  ) async {
    final byId = <String, DiveRole>{};
    for (final id in roleIds) {
      final role = await _roleFor(id, targetDiverId);
      byId[role.id] = role;
    }
    return [for (final id in DiveRoleSet.normalize(byId.keys)) byId[id]!];
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

/// A mirrored dive's site and trip and who each is shared with, read once
/// per mirror action.
typedef _SourceItems = ({
  DiveSite? site,
  ItemSharing siteSharing,
  Trip? trip,
  ItemSharing tripSharing,
});
