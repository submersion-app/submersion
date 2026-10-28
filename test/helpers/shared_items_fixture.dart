import 'dart:async';

import 'package:drift/drift.dart';

import 'package:submersion/core/data/visibility/item_sharing.dart';
import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/divers/data/repositories/item_shares_repository.dart';
import 'package:submersion/features/divers/data/repositories/profile_hides_repository.dart';

/// Rows for the shared trip and site tests (issue #2594): profiles, trips
/// and sites with an owner and a share flag, dives linked to them, and the
/// sync bookkeeping the tests read back.
const kSharedTs = 1700000000000;

Future<void> seedDivers(AppDatabase db, List<String> ids) async {
  for (final id in ids) {
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: id,
            name: 'Diver $id',
            createdAt: kSharedTs,
            updatedAt: kSharedTs,
          ),
        );
  }
}

Future<void> seedTrip(
  AppDatabase db,
  String id, {
  String? owner,
  bool shared = false,
  String? name,
}) => db
    .into(db.trips)
    .insert(
      TripsCompanion.insert(
        id: id,
        name: name ?? 'Trip $id',
        startDate: kSharedTs,
        endDate: kSharedTs,
        createdAt: kSharedTs,
        updatedAt: kSharedTs,
        diverId: Value(owner),
        isShared: Value(shared),
      ),
    );

Future<void> seedSite(
  AppDatabase db,
  String id, {
  String? owner,
  bool shared = false,
  String? name,
}) => db
    .into(db.diveSites)
    .insert(
      DiveSitesCompanion.insert(
        id: id,
        name: name ?? 'Site $id',
        createdAt: kSharedTs,
        updatedAt: kSharedTs,
        diverId: Value(owner),
        isShared: Value(shared),
      ),
    );

Future<void> seedDive(
  AppDatabase db,
  String id, {
  required String diver,
  String? tripId,
  String? siteId,
}) => db
    .into(db.dives)
    .insert(
      DivesCompanion.insert(
        id: id,
        diverId: Value(diver),
        diveDateTime: kSharedTs,
        tripId: Value(tripId),
        siteId: Value(siteId),
        createdAt: kSharedTs,
        updatedAt: kSharedTs,
      ),
    );

Future<void> clearPendingMarks(AppDatabase db) =>
    db.customStatement('DELETE FROM sync_records');

Future<int> pendingCount(
  AppDatabase db,
  String entityType,
  String recordId,
) async =>
    (await db
            .customSelect(
              'SELECT COUNT(*) AS n FROM sync_records WHERE entity_type = ? '
              "AND record_id = ? AND sync_status = 'pending'",
              variables: [
                Variable<String>(entityType),
                Variable<String>(recordId),
              ],
            )
            .getSingle())
        .read<int>('n');

Future<int> tombstoneCount(AppDatabase db, String entityType) async =>
    (await db
            .customSelect(
              'SELECT COUNT(*) AS n FROM deletion_log WHERE entity_type = ?',
              variables: [Variable<String>(entityType)],
            )
            .getSingle())
        .read<int>('n');

/// The real hides repository, whose hide or unhide can be made to throw as
/// a database error does (issue #2677).
class FailingProfileHides extends ProfileHidesRepository {
  bool failHide = false;
  bool failUnhide = false;

  /// The hide is written, then the call throws, as it does when the list
  /// refresh after a committed hide fails.
  bool failAfterHide = false;

  /// Holds a hide open until the test completes it.
  Completer<void>? hideGate;

  // [hide] writes through [hideAll], so failing here fails both.
  @override
  Future<int> hideAll(
    SharedItemKind kind,
    List<String> ids,
    String diverId,
  ) async {
    await hideGate?.future;
    if (failHide) throw StateError('database unavailable');
    final hidden = await super.hideAll(kind, ids, diverId);
    if (failAfterHide) throw StateError('database unavailable');
    return hidden;
  }

  @override
  Future<void> unhide(SharedItemKind kind, String id, String diverId) async {
    if (failUnhide) throw StateError('database unavailable');
    return super.unhide(kind, id, diverId);
  }
}

/// The active profile, read through gates a test completes one at a time,
/// so it can hold `validatedCurrentDiverIdProvider` mid-reload: a profile
/// switch keeps the previous profile in `.value` until the new read lands.
/// Override with `overrideWith((_) => active.read())`.
class GatedActiveProfile {
  GatedActiveProfile();

  /// The first read lands at once with [first], so a page can load before
  /// the test holds a later read open.
  GatedActiveProfile.settled(String? first)
    : _first = first,
      _settleFirst = true;

  String? _first;
  bool _settleFirst = false;
  final reads = <Completer<String?>>[];

  Future<String?> read() {
    final read = Completer<String?>();
    if (reads.isEmpty && _settleFirst) read.complete(_first);
    reads.add(read);
    return read.future;
  }

  /// Completes the latest read with [diverId].
  void settle(String? diverId) => reads.last.complete(diverId);
}

/// Who items are shared with, without a database (issue #2151): [sharing]
/// by item id, everything else not shared. Records [setSharing] and
/// [addSharing] calls.
class FakeItemShares extends ItemSharesRepository {
  FakeItemShares([Map<String, ItemSharing>? sharing]) : sharing = {...?sharing};

  /// Every item in [ids] shared with everyone.
  FakeItemShares.everyone(Iterable<String> ids)
    : sharing = {for (final id in ids) id: ItemSharing.all};

  final Map<String, ItemSharing> sharing;
  final setCalls = <(String, ItemSharing)>[];

  /// The acting profile each [setSharing] call named, in order.
  final setActingDivers = <String?>[];
  final addCalls = <(List<String>, ItemSharing)>[];

  @override
  Stream<void> watchChanges() => const Stream.empty();

  @override
  Future<ItemSharing> sharingOf(SharedItemKind kind, String id) async =>
      sharing[id] ?? ItemSharing.none;

  @override
  Future<Map<String, ItemSharing>> sharingOfAll(
    SharedItemKind kind,
    List<String> ids,
  ) async => {for (final id in ids) id: sharing[id] ?? ItemSharing.none};

  /// Share rows left beside the everyone flag by a sync race, by item id.
  final staleRows = <String, Set<String>>{};

  @override
  Future<Set<String>> storedProfileIds(SharedItemKind kind, String id) async =>
      staleRows[id] ?? sharing[id]?.profileIds ?? const {};

  @override
  Future<Set<String>> itemIdsWithShares(SharedItemKind kind) async => {
    for (final e in sharing.entries)
      if (e.value.profileIds.isNotEmpty) e.key,
  };

  @override
  Future<bool> setSharing(
    SharedItemKind kind,
    String id,
    ItemSharing sharing, {
    required String? actingDiverId,
  }) async {
    setCalls.add((id, sharing));
    setActingDivers.add(actingDiverId);
    if (refuseSet) return false;
    this.sharing[id] = sharing;
    return true;
  }

  /// [setSharing] answers false, as the repository does for a profile that
  /// is not the owner (an item that changed hands meanwhile).
  bool refuseSet = false;

  @override
  Future<ItemShareResult> addSharing(
    SharedItemKind kind,
    List<String> ids,
    ItemSharing add, {
    required String actingDiverId,
  }) async {
    addCalls.add((ids, add));
    return ItemShareResult(itemsShared: ids.length);
  }
}
