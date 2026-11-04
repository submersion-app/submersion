import 'package:drift/drift.dart' show Variable;

import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart'
    show GeoPoint;
import 'package:submersion/features/gps_log/data/repositories/track_geometry_cache_repository.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/nav_track_corrector.dart';

/// Surface GPS tracks, through the repository the GPS log uses: a track is
/// trimmed (its fixes kept, only hidden), split in two at a moment, or
/// deleted. Its drawn geometry is dropped once the change is saved, as the
/// map's own trim does.
class GpsTrackWrites extends WritableEntry {
  GpsTrackWrites(this._r);

  final RecordRepositories _r;
  final _cache = TrackGeometryCacheRepository();

  static const _split = 'split_at';

  @override
  String get name => 'gps_tracks';

  @override
  String get table => 'gps_tracks';

  @override
  String get note =>
      'trim_start_time and trim_end_time hide the fixes outside them, null '
      'to show all. $_split replaces the track with two, cut at that moment, '
      'each keeping the trim.';

  @override
  late final Map<String, FieldCodec> fields = {
    'trim_start_time': const FieldCodec.wallClock(nullable: true),
    'trim_end_time': const FieldCodec.wallClock(nullable: true),
    _split: const FieldCodec.wallClock(nullable: true),
  };

  @override
  Set<String> get requiredOnCreate => const {};

  @override
  Set<String> get effectFields => const {_split};

  @override
  Future<PlanBlock?> refuse(WriteCheck check) async {
    if (check.kind == ChangeKind.create) {
      return const PlanBlock(
        BlockReason.notPermitted,
        'A GPS track is recorded or imported, not made here.',
      );
    }
    if (check.kind == ChangeKind.delete) return null;
    final track = await _track(check.id!, points: check.values[_split] != null);
    final end = track.endTime ?? track.startTime;
    final v = check.values;
    if (v[_split] case final DateTime at) {
      if (v.containsKey('trim_start_time') || v.containsKey('trim_end_time')) {
        return const PlanBlock(
          BlockReason.notPermitted,
          'Split a track in a change of its own.',
        );
      }
      final seconds = at.millisecondsSinceEpoch ~/ 1000;
      final before = track.points.any((p) => p.timestamp <= seconds);
      final after = track.points.any((p) => p.timestamp > seconds);
      return before && after
          ? null
          : const PlanBlock(
              BlockReason.invalidValue,
              'split_at: a moment with fixes on both sides of it.',
            );
    }
    int? ms(String key, int? held) => v.containsKey(key)
        ? (v[key] as DateTime?)?.millisecondsSinceEpoch
        : held;
    final from = ms('trim_start_time', track.trimStartTime);
    final to = ms('trim_end_time', track.trimEndTime);
    for (final bound in [from, to]) {
      if (bound != null && (bound < track.startTime || bound > end)) {
        return const PlanBlock(
          BlockReason.invalidValue,
          'A trim falls inside the track, between its start and end times.',
        );
      }
    }
    if (from != null && to != null && from >= to) {
      return const PlanBlock(
        BlockReason.invalidValue,
        'trim_start_time comes before trim_end_time.',
      );
    }
    return null;
  }

  @override
  Future<SideEffects> sideEffects(
    String id,
    String? ownerId,
    RecordUpdate update,
    Map<String, Object?> document,
  ) async => update.values[_split] == null
      ? const SideEffects()
      : const SideEffects(created: {'gps_tracks': 2}, parts: {'gps_tracks': 1});

  @override
  Future<String> create(String diverId, Map<String, Object?> values) =>
      throw UnsupportedError('A GPS track is recorded or imported.');

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    final v = update.values;
    if (v[_split] case final DateTime at) {
      await _r.gpsTracks.splitTrack(id, at.millisecondsSinceEpoch);
      return;
    }
    final track = await _track(id, points: false);
    int? ms(String key, int? held) => v.containsKey(key)
        ? (v[key] as DateTime?)?.millisecondsSinceEpoch
        : held;
    await _r.gpsTracks.setTrimBounds(
      id,
      startMs: ms('trim_start_time', track.trimStartTime),
      endMs: ms('trim_end_time', track.trimEndTime),
    );
  }

  @override
  Future<void> delete(String id, String? ownerId) =>
      _r.gpsTracks.deleteTrack(id);

  @override
  Future<void> afterApply(List<AppliedChange> changes, ApplyRun run) async {
    for (final change in changes) {
      if (change.kind != ChangeKind.create) await _cache.invalidate(change.id);
    }
  }

  Future<GpsTrack> _track(String id, {required bool points}) async =>
      await _r.gpsTracks.getTrack(id, includePoints: points) ??
      (throw AgentToolException(
        AgentToolErrorCode.writeRefused,
        'GPS track $id no longer exists.',
        details: {'id': id},
      ));
}

/// Recorded underwater routes, through the repository the route pages use.
/// A route is linked to a dive by hand, the dive's first becoming its
/// primary; it takes the dive's site and anchor when it has none. A route
/// leaving a dive, or deleted, hands the primary on to a sibling.
class NavTrackWrites extends WritableEntry {
  NavTrackWrites(this._r);

  final RecordRepositories _r;

  @override
  String get name => 'nav_tracks';

  @override
  String get table => 'nav_tracks';

  @override
  String get note =>
      'dive_id links the route to a dive by hand, or null unlinks it. '
      'is_primary takes true only, on a linked route. scale_factor is 0.25 '
      'to 4, heading_offset_deg -180 to 180, trust_fraction 0 to 1.';

  @override
  late final Map<String, FieldCodec> fields = {
    'name': const FieldCodec.text(maxLength: 100, nullable: true, trim: true),
    'dive_id': const FieldCodec.reference('dives', nullable: true),
    'site_id': const FieldCodec.reference('sites', nullable: true),
    'equipment_id': const FieldCodec.reference('equipment', nullable: true),
    'is_primary': const FieldCodec.flag(),
    'anchor_latitude': const FieldCodec.number(
      min: -90,
      max: 90,
      nullable: true,
    ),
    'anchor_longitude': const FieldCodec.number(
      min: -180,
      max: 180,
      nullable: true,
    ),
    'end_mode': FieldCodec.enumName(NavTrackEndMode.values),
    'end_latitude': const FieldCodec.number(min: -90, max: 90, nullable: true),
    'end_longitude': const FieldCodec.number(
      min: -180,
      max: 180,
      nullable: true,
    ),
    'trust_fraction': const FieldCodec.number(min: 0, max: 1),
    'heading_offset_deg': const FieldCodec.number(min: -180, max: 180),
    'scale_factor': const FieldCodec.number(
      min: NavTrackCorrection.minScaleFactor,
      max: NavTrackCorrection.maxScaleFactor,
    ),
  };

  static const _correction = {
    'anchor_latitude',
    'anchor_longitude',
    'end_mode',
    'end_latitude',
    'end_longitude',
    'trust_fraction',
    'heading_offset_deg',
    'scale_factor',
  };

  @override
  Set<String> get requiredOnCreate => const {};

  @override
  Future<PlanBlock?> refuse(WriteCheck check) async {
    if (check.kind == ChangeKind.create) {
      return const PlanBlock(
        BlockReason.notPermitted,
        'A route is imported from a device, not made here.',
      );
    }
    if (check.kind == ChangeKind.delete) return null;
    final v = check.values;
    final dive = v.containsKey('dive_id')
        ? v['dive_id']
        : check.document?['dive_id'];
    if (v['is_primary'] == false) {
      return const PlanBlock(
        BlockReason.invalidValue,
        'is_primary: make another of the dive\'s routes the primary instead.',
      );
    }
    if (v['is_primary'] == true && dive == null) {
      return const PlanBlock(
        BlockReason.invalidValue,
        'is_primary: a route is primary only for the dive it is linked to.',
      );
    }
    final point = {...?check.document, ...v};
    for (final (lat, lon) in const [
      ('anchor_latitude', 'anchor_longitude'),
      ('end_latitude', 'end_longitude'),
    ]) {
      if ((point[lat] == null) != (point[lon] == null)) {
        return PlanBlock(
          BlockReason.invalidValue,
          '$lat and $lon are set or cleared together.',
        );
      }
    }
    return null;
  }

  @override
  Future<SideEffects> sideEffects(
    String id,
    String? ownerId,
    RecordUpdate update,
    Map<String, Object?> document,
  ) async {
    final v = update.values;
    final fields = <String, Object?>{};
    var touched = 0;
    final wasOn = document['dive_id'] as String?;
    final wasPrimary = document['is_primary'] == true;
    if (v.containsKey('dive_id')) {
      final next = v['dive_id'] as String?;
      if (wasOn != null && wasPrimary && next != wasOn) {
        touched += await _siblings(wasOn, id);
      }
      if (next != null) {
        final hasPrimary = await _hasPrimary(next, id);
        if ((!hasPrimary) != wasPrimary) fields['is_primary'] = !hasPrimary;
        if (document['site_id'] == null &&
            document['anchor_latitude'] == null &&
            !v.containsKey('site_id')) {
          final site = await _diveSite(next);
          if (site != null) fields['site_id'] = site;
        }
      }
    }
    if (v['is_primary'] == true && !wasPrimary && wasOn != null) {
      touched += await _primaries(wasOn, id);
    }
    if (v['equipment_id'] case final String itemId) {
      final item = await _r.equipment.getEquipmentById(itemId);
      if (item != null && document['device_name'] != item.name) {
        fields['device_name'] = item.name;
      }
    }
    return SideEffects(
      fields: fields,
      touched: {if (touched > 0) 'nav_tracks': touched},
    );
  }

  @override
  Future<DeleteReach> deleteReach(
    String id, {
    Map<String, Set<String>> alongside = const {},
  }) async {
    final route = await _route(id);
    final dive = route.diveId;
    final n = dive != null && route.isPrimary ? await _siblings(dive, id) : 0;
    return DeleteReach(touched: {if (n > 0) 'nav_tracks': n});
  }

  @override
  Future<String> create(String diverId, Map<String, Object?> values) =>
      throw UnsupportedError('A route is imported from a device.');

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    final v = update.values;
    final repo = _r.navTracks;
    final route = await _route(id);
    if (v.containsKey('name')) await repo.rename(id, v['name'] as String?);
    if (v.containsKey('dive_id')) {
      final next = v['dive_id'] as String?;
      if (next == null) {
        await repo.unlink(id);
      } else if (route.diveId == null) {
        await repo.link(id, next, linkMode: NavTrackLinkMode.manual);
      } else if (route.diveId != next) {
        await repo.relink(
          id,
          fromDiveId: route.diveId!,
          toDiveId: next,
          linkMode: NavTrackLinkMode.manual,
        );
      }
    }
    if (v.containsKey('site_id')) {
      await repo.setSite(id, v['site_id'] as String?);
    }
    if (v.containsKey('equipment_id')) {
      final itemId = v['equipment_id'] as String?;
      final item = itemId == null
          ? null
          : await _r.equipment.getEquipmentById(itemId);
      await repo.setEquipment(
        id,
        equipmentId: itemId,
        deviceName: item?.name ?? route.deviceName,
      );
    }
    if (v.keys.any(_correction.contains)) {
      final c = route.correction;
      double? number(String key, double? held) =>
          v.containsKey(key) ? (v[key] as num?)?.toDouble() : held;
      GeoPoint? point(String lat, String lon, GeoPoint? held) {
        final la = number(lat, held?.latitude);
        final lo = number(lon, held?.longitude);
        return la == null || lo == null ? null : GeoPoint(la, lo);
      }

      await repo.updateCorrection(
        id,
        NavTrackCorrection(
          anchor: point('anchor_latitude', 'anchor_longitude', c.anchor),
          endMode: switch (v['end_mode']) {
            final String m => NavTrackEndMode.values.byName(m),
            _ => c.endMode,
          },
          endPoint: point('end_latitude', 'end_longitude', c.endPoint),
          trustFraction: number('trust_fraction', c.trustFraction)!,
          headingOffsetDeg: number('heading_offset_deg', c.headingOffsetDeg)!,
          scaleFactor: number('scale_factor', c.scaleFactor)!,
        ),
      );
    }
    if (v['is_primary'] == true) await repo.setPrimary(id);
  }

  @override
  Future<void> delete(String id, String? ownerId) => _r.navTracks.delete(id);

  Future<NavTrack> _route(String id) async =>
      await _r.navTracks.getById(id, includePoints: false) ??
      (throw AgentToolException(
        AgentToolErrorCode.writeRefused,
        'Route $id no longer exists.',
        details: {'id': id},
      ));

  Future<int> _count(String sql, List<String> args) async =>
      (await _r.db
              .customSelect(
                sql,
                variables: [for (final a in args) Variable.withString(a)],
              )
              .getSingle())
          .read<int>('n');

  /// Whether dive [diveId] has a primary route other than [id].
  Future<bool> _hasPrimary(String diveId, String id) async =>
      await _primaries(diveId, id) > 0;

  Future<int> _primaries(String diveId, String id) => _count(
    'SELECT COUNT(*) AS n FROM nav_tracks WHERE dive_id = ? AND id != ? '
    'AND is_primary = 1',
    [diveId, id],
  );

  /// The other routes on [diveId], one of which takes over as primary.
  Future<int> _siblings(String diveId, String id) async =>
      await _count(
            'SELECT COUNT(*) AS n FROM nav_tracks WHERE dive_id = ? AND id != ?',
            [diveId, id],
          ) >
          0
      ? 1
      : 0;

  Future<String?> _diveSite(String diveId) async =>
      (await _r.db
              .customSelect(
                'SELECT site_id FROM dives WHERE id = ?',
                variables: [Variable.withString(diveId)],
              )
              .getSingleOrNull())
          ?.readNullable<String>('site_id');
}
