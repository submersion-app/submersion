import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_series.dart'
    as series;
import 'package:submersion/features/dive_log/domain/entities/tank_shared_computers.dart';

/// Which rows of a dive belong to one of its data sources: what Split moves
/// to a new dive and what Remove source deletes (issue #4393).
///
/// Series move by computer attribution. A computer-less source cannot be
/// attributed at the row level by computer, so only non-primary
/// null-computer profile series follow it (never user-edited isPrimary
/// series) and no events move. This follows the retired unlinkComputer's
/// convention. Pressure series are the exception: one that names the source
/// moves with it whatever its computer (issue #2440). So are a computer-less
/// source's tanks: one with no computer that names the source is its (issue
/// #2716). A source with a computer owns its tanks by the computer rule.
class SourceOwnership {
  const SourceOwnership(this.source);

  final DiveDataSourcesData source;

  bool ownedByComputer(String? computerId) =>
      source.computerId != null && computerId == source.computerId;

  /// The legacy row rule, applied to whole series: not owned by another
  /// source by FK, then the computer convention for the source's primacy.
  ///
  /// The FK gate is issue #1149: the computerId rules cannot separate two
  /// file-imported sources (both sides are null), so a series whose sourceId
  /// names another source is never this source's.
  bool ownsProfile(series.ProfileSeries s) {
    final notOwnedByAnotherSource =
        s.sourceId == null || s.sourceId == source.id;
    final byLegacyRule = source.computerId == null
        ? s.computerId == null && !s.isPrimary
        : source.isPrimary
        ? ownedByComputer(s.computerId) || s.computerId == null
        : ownedByComputer(s.computerId);
    return notOwnedByAnotherSource && byLegacyRule;
  }

  /// A series that names its source goes with exactly that source, computer
  /// or not (issue #2440); an unattributed one falls back to the computer
  /// rule.
  bool ownsPressure(series.TankPressureSeries s) => s.sourceId == null
      ? ownedByComputer(s.computerId)
      : s.sourceId == source.id;

  /// A source with a computer keeps the computer rule exactly; only a
  /// computer-less one, which that rule can never match, claims the
  /// computer-less tanks that name it.
  bool ownsTank(DiveTank t) => source.computerId != null
      ? ownedByComputer(t.computerId)
      : t.computerId == null && t.sourceId == source.id;

  /// Whether [tank], though this source's, must stay on the dive: another
  /// computer's (or unattributed) pressure rows, events or gas switches still
  /// point at it, or another computer shares the cylinder.
  bool tankStillNeeded(
    DiveTank tank, {
    required Iterable<series.TankPressureSeries> pressures,
    required Iterable<DiveProfileEvent> events,
    required Iterable<GasSwitche> switches,
  }) =>
      pressures.any(
        (r) => r.tankId == tank.id && !ownedByComputer(r.computerId),
      ) ||
      events.any(
        (r) => r.tankId == tank.id && !ownedByComputer(r.computerId),
      ) ||
      // Another computer's switch (or an unattributed one, which belongs to
      // the dive's gas plan) still needs the tank here.
      switches.any(
        (r) => r.tankId == tank.id && !ownedByComputer(r.computerId),
      ) ||
      // Another computer breathed this cylinder too (a consolidated tank both
      // logged), so it cannot leave the dive.
      (decodeSharedComputerIds(tank.sharedComputerIds)?.isNotEmpty ?? false);

  /// Hands a tank that stays on the dive to a computer that shares it
  /// (#2560): left unattributed it would become every remaining computer's,
  /// and a third computer on its own gas would start the dive on it.
  ///
  /// A link to this source goes with this clock rather than the FK's silent
  /// SET NULL (v251). Only that one: the computer rule also selects tanks of
  /// another source of the same computer (a combined dive's other half),
  /// which stays.
  Future<void> handTankToHeir(
    AppDatabase db,
    SyncRepository sync, {
    required DiveTank tank,
    required List<DiveDataSourcesData> sources,
    required int now,
    String? fallbackHeir,
  }) async {
    final sharers = [
      for (final c
          in decodeSharedComputerIds(tank.sharedComputerIds) ??
              const <String>[])
        if (c != source.computerId) c,
    ];
    // [fallbackHeir] is for a tank no computer shares but another still
    // uses (Remove source passes the computer of a row that kept it).
    final heir = sharers.firstOrNull ?? fallbackHeir;
    final heirSourceId = heir == null
        ? null
        : sources.where((s) => s.computerId == heir).firstOrNull?.id;
    await (db.update(db.diveTanks)..where((t) => t.id.equals(tank.id))).write(
      DiveTanksCompanion(
        computerId: Value(heir),
        sourceId: tank.sourceId == source.id
            ? Value(heirSourceId)
            : const Value.absent(),
        sharedComputerIds: heir == null
            ? const Value.absent()
            : Value(encodeSharedComputerIds(sharers.skip(1))),
      ),
    );
    await sync.markRecordPending(
      entityType: 'diveTanks',
      recordId: tank.id,
      localUpdatedAt: now,
    );
  }

  /// Whether [tank] lists this source's computer among the computers that
  /// breathed it besides its owner.
  bool sharesTank(DiveTank tank) =>
      source.computerId != null &&
      (decodeSharedComputerIds(tank.sharedComputerIds) ?? const <String>[])
          .contains(source.computerId);

  /// Takes this source's computer off [tank]'s sharers.
  Future<void> stopSharingTank(
    AppDatabase db,
    SyncRepository sync, {
    required DiveTank tank,
    required int now,
  }) async {
    final sharers =
        decodeSharedComputerIds(tank.sharedComputerIds) ?? const <String>[];
    await (db.update(db.diveTanks)..where((t) => t.id.equals(tank.id))).write(
      DiveTanksCompanion(
        sharedComputerIds: Value(
          encodeSharedComputerIds(sharers.where((c) => c != source.computerId)),
        ),
      ),
    );
    await sync.markRecordPending(
      entityType: 'diveTanks',
      recordId: tank.id,
      localUpdatedAt: now,
    );
  }
}
